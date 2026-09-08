using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SosyoBel.Application.Applications;
using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Logging;

namespace SosyoBel.Infrastructure.Persistence;

internal enum SubmittedApplicationUpdateAccess
{
    Allowed,
    NotOwner,
    NotPending,
}

/// <summary>
/// Sahibinin Beklemede durumundaki dbo başvurusunun yalnız personel girişli
/// alanlarını, aile fertlerini ve hane cevaplarını tek transaction içinde günceller.
/// </summary>
internal sealed class SubmittedApplicationUpdateService(
    IDbContextFactory<CompanyApplicationDbContext> contextFactory,
    CompanyApplicationPhotoPreparer photoPreparer,
    ILogger<SubmittedApplicationUpdateService> logger,
    RequestLogContext logContext) : IUpdateSubmittedApplicationService
{
    public async Task<ApplicationLifecycleResult<UpdatedSubmittedApplication>>
        UpdateAsync(
            UpdateSubmittedApplicationCommand command,
            CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);
        logContext.Stage = RequestLogStage.ValidateApplicationUpdate;
        var validation = ValidateAndNormalize(command);
        if (validation.Result is not null) return validation.Result;

        var photoPreparation = await PreparePhotoUpdateAsync(
            command,
            validation.Photos,
            cancellationToken);
        if (photoPreparation.Result is not null)
            return photoPreparation.Result;
        var preparedPhotos = photoPreparation.Prepared;
        IReadOnlyCollection<string> removedPhotoPaths = [];

        try
        {
            await using var strategyContext =
                await contextFactory.CreateDbContextAsync(cancellationToken);
            var strategy = strategyContext.Database.CreateExecutionStrategy();
            var result = await strategy.ExecuteAsync(async () =>
            {
                await using var context =
                    await contextFactory.CreateDbContextAsync(cancellationToken);
                await using var transaction =
                    await context.Database.BeginTransactionAsync(
                        IsolationLevel.Serializable,
                        cancellationToken);

                logContext.Stage = RequestLogStage.LoadApplicationForUpdate;
                var application = await BuildUpdateTargetQuery(
                        context,
                        command.ApplicationId)
                    .SingleOrDefaultAsync(cancellationToken);
                if (application is null)
                    return NotFound();

                var statusCode =
                    await CompanyApplicationStatusResolver.FindCodeAsync(
                        context,
                        application.StatusId,
                        cancellationToken);
                var access = ClassifyAccess(
                    application.CreatedByUserId,
                    command.Actor.ActorUserId,
                    statusCode);
                if (access == SubmittedApplicationUpdateAccess.NotOwner)
                    return Forbidden();
                if (access == SubmittedApplicationUpdateAccess.NotPending)
                {
                    return Conflict(
                        "application_not_editable",
                        "Yalnız Beklemede durumundaki başvuru güncellenebilir.");
                }

                logContext.Stage =
                    RequestLogStage.ResolveApplicationUpdateReferences;
                var editable = validation.Application!;
                var helpTypeId =
                    await context.ResolveCompanyReferenceIdAsync<HelpTypeReference>(
                        ApplicationReferenceCodeQueries.HelpType,
                        editable.HelpTypeCode,
                        cancellationToken);
                int? disabilityTypeId = null;
                if (editable.HasDisability)
                {
                    disabilityTypeId =
                        await context
                            .ResolveActiveCompanyReferenceIdAsync<
                                DisabilityTypeReference>(
                                ApplicationReferenceCodeQueries.DisabilityType,
                                editable.DisabilityTypeCode,
                                cancellationToken);
                }
                if (helpTypeId is null ||
                    (editable.HasDisability && disabilityTypeId is null))
                {
                    return Conflict(
                        "company_reference_not_found",
                        "Yardım veya engel türü şirket referanslarıyla eşleştirilemedi.");
                }

                var familyResult =
                    await CompanyApplicationFamilyPreparer.PrepareAsync(
                        context,
                        application.Id,
                        validation.FamilyMembers!,
                        cancellationToken);
                if (familyResult.Status !=
                    CompanyApplicationFamilyPreparationStatus.Prepared)
                {
                    return MapFamilyError(familyResult);
                }

                var description = CompanyApplicationDescriptionComposer.Compose(
                    editable.Description,
                    validation.FamilyMembers!,
                    editable.FieldInspectionNote);
                application.UpdateEditableFields(
                    editable.PhoneNumber,
                    helpTypeId.Value,
                    editable.HasDisability,
                    disabilityTypeId,
                    editable.DisabilityRate,
                    description);

                var existingFamily = await context
                    .Set<CompanyApplicationFamilyMemberRecord>()
                    .Where(member => member.ApplicationId == application.Id)
                    .ToArrayAsync(cancellationToken);
                var existingHousehold = await context
                    .Set<CompanyApplicationHouseholdAnswerRecord>()
                    .Where(answer => answer.ApplicationId == application.Id)
                    .ToArrayAsync(cancellationToken);
                CompanyHouseholdPhotoRecord[] removedPhotos = [];
                if (preparedPhotos is not null)
                {
                    var pathPrefix =
                        $"/uploads/hanefotograflari/{preparedPhotos.PublicId:N}/";
                    var currentPhotos = await context
                        .Set<CompanyHouseholdPhotoRecord>()
                        .Where(photo =>
                            photo.CitizenId == preparedPhotos.CitizenId &&
                            photo.PhotoPath.StartsWith(pathPrefix))
                        .ToArrayAsync(cancellationToken);
                    if (preparedPhotos.RetainedPhotoIds.Any(
                            photoId => currentPhotos.All(
                                photo => photo.Id != photoId)))
                    {
                        return Conflict(
                            "application_photos_changed",
                            "Başvuru fotoğrafları başka bir işlem tarafından değiştirildi.");
                    }
                    removedPhotos = currentPhotos
                        .Where(photo => !preparedPhotos.RetainedPhotoIds.Contains(
                            photo.Id))
                        .ToArray();
                    removedPhotoPaths = removedPhotos
                        .Select(photo => photo.PhotoPath)
                        .ToArray();
                }
                context.RemoveRange(existingFamily);
                context.RemoveRange(existingHousehold);
                context.RemoveRange(removedPhotos);

                logContext.Stage = RequestLogStage.SaveApplicationUpdate;
                // Önce eski çocuk kayıtlar silinir. Aynı transaction içinde ikinci
                // SaveChanges yeni benzersiz hane cevaplarını güvenle ekler.
                await context.SaveChangesAsync(cancellationToken);
                context.AddRange(familyResult.Records ?? []);
                context.AddRange(validation.HouseholdAnswers!
                    .Select(answer =>
                        CompanyApplicationHouseholdAnswerRecord.Create(
                            application.Id,
                            answer)));
                if (preparedPhotos is not null)
                {
                    context.AddRange(preparedPhotos.NewRecords.Select(photo =>
                        CompanyHouseholdPhotoRecord.Create(
                            preparedPhotos.CitizenId,
                            photo.PhotoPath,
                            photo.Description,
                            photo.UploadedAt)));
                }
                await context.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);

                return new ApplicationLifecycleResult<
                    UpdatedSubmittedApplication>(
                    ApplicationLifecycleStatus.Succeeded,
                    UpdatedSubmittedApplication.Create(
                        application.Id,
                        application.PublicToken,
                        WorkItemStatusCodes.BoardPending));
            });

            if (preparedPhotos is not null)
            {
                if (result.Status == ApplicationLifecycleStatus.Succeeded)
                {
                    await photoPreparer.DeleteCompanyPathsAsync(
                        removedPhotoPaths,
                        preparedPhotos.NewRecords.Select(value => value.PhotoPath));
                }
                else
                {
                    await photoPreparer.DiscardAsync(preparedPhotos.StoredPhotos);
                }
            }
            return result;
        }
        catch (DbUpdateException exception)
        {
            if (preparedPhotos is not null)
                await photoPreparer.DiscardAsync(preparedPhotos.StoredPhotos);
            logger.LogWarning(
                new EventId(1004),
                exception,
                "Company application update transaction conflicted.");
            return Conflict(
                "company_application_update_conflict",
                "Başvuru güncellemesi mevcut şirket verileriyle çakıştı.");
        }
        catch
        {
            if (preparedPhotos is not null)
                await photoPreparer.DiscardAsync(preparedPhotos.StoredPhotos);
            throw;
        }
    }

    internal static IQueryable<CompanyApplicationRecord> BuildUpdateTargetQuery(
        CompanyApplicationDbContext context,
        int applicationId) =>
        context.Set<CompanyApplicationRecord>()
            .Where(application => application.Id == applicationId);

    internal static SubmittedApplicationUpdateAccess ClassifyAccess(
        string? ownerUserId,
        string actorUserId,
        string? statusCode)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(actorUserId);
        if (!string.Equals(
                ownerUserId?.Trim(),
                actorUserId.Trim(),
                StringComparison.Ordinal))
        {
            return SubmittedApplicationUpdateAccess.NotOwner;
        }

        return string.Equals(
            statusCode,
            WorkItemStatusCodes.BoardPending,
            StringComparison.Ordinal)
                ? SubmittedApplicationUpdateAccess.Allowed
                : SubmittedApplicationUpdateAccess.NotPending;
    }

    private async Task<PhotoPreparationOutcome> PreparePhotoUpdateAsync(
        UpdateSubmittedApplicationCommand command,
        SubmittedApplicationPhotoUpdateData? photos,
        CancellationToken cancellationToken)
    {
        if (photos is null) return new();

        await using var context =
            await contextFactory.CreateDbContextAsync(cancellationToken);
        var application = await BuildUpdateTargetQuery(
                context,
                command.ApplicationId)
            .AsNoTracking()
            .SingleOrDefaultAsync(cancellationToken);
        if (application is null) return new(Result: NotFound());

        var statusCode = await CompanyApplicationStatusResolver.FindCodeAsync(
            context,
            application.StatusId,
            cancellationToken);
        var access = ClassifyAccess(
            application.CreatedByUserId,
            command.Actor.ActorUserId,
            statusCode);
        if (access == SubmittedApplicationUpdateAccess.NotOwner)
            return new(Result: Forbidden());
        if (access == SubmittedApplicationUpdateAccess.NotPending)
        {
            return new(Result: Conflict(
                "application_not_editable",
                "Yalnız Beklemede durumundaki başvuru güncellenebilir."));
        }
        if (application.CitizenId is not > 0 ||
            !Guid.TryParseExact(application.PublicToken, "N", out var publicId))
        {
            return new(Result: Conflict(
                "application_photo_identity_missing",
                "Başvurunun fotoğraf bağlantısı bulunamadı."));
        }

        var pathPrefix = $"/uploads/hanefotograflari/{publicId:N}/";
        var currentPhotoIds = await context
            .Set<CompanyHouseholdPhotoRecord>()
            .AsNoTracking()
            .Where(photo =>
                photo.CitizenId == application.CitizenId.Value &&
                photo.PhotoPath.StartsWith(pathPrefix))
            .Select(photo => photo.Id)
            .ToArrayAsync(cancellationToken);
        if (photos.RetainedPhotoIds.Any(
                photoId => !currentPhotoIds.Contains(photoId)))
        {
            return new(Result: Invalid(
                "invalid_retained_application_photos",
                new Dictionary<string, string[]>
                {
                    ["retainedPhotoIds"] =
                        ["Korunacak fotoğraflardan biri bu başvuruya ait değil."],
                }));
        }

        logContext.Stage = RequestLogStage.StorePhotos;
        var preparation = await photoPreparer.PrepareAsync(
            application.CitizenId.Value,
            publicId,
            photos.NewPhotos,
            cancellationToken);
        if (preparation.Status !=
            CompanyApplicationPhotoPreparationStatus.Prepared)
        {
            return preparation.Status ==
                   CompanyApplicationPhotoPreparationStatus.InvalidInput
                ? new(Result: Invalid(
                    preparation.Code ?? "invalid_application_photos",
                    preparation.Errors ?? new Dictionary<string, string[]>()))
                : new(Result: Conflict(
                    preparation.Code ?? "photo_storage_error",
                    "Fotoğraflar kalıcı depoya hazırlanamadı."));
        }

        var records = (preparation.Records ?? [])
            .Select(value => new PreparedPhotoRecord(
                value.PhotoPath,
                value.Description,
                value.UploadedAt))
            .ToArray();
        return new(Prepared: new PreparedPhotoUpdate(
            publicId,
            application.CitizenId.Value,
            photos.RetainedPhotoIds.ToHashSet(),
            records,
            preparation.StoredPhotos ?? []));
    }

    private static UpdateValidation ValidateAndNormalize(
        UpdateSubmittedApplicationCommand command)
    {
        var errors = new Dictionary<string, string[]>();
        if (command.Actor is null ||
            string.IsNullOrWhiteSpace(command.Actor.ActorUserId))
        {
            errors["actor"] =
                ["Doğrulanmış kullanıcı kimliği bulunamadı."];
        }
        if (command.ApplicationId <= 0)
            errors["applicationId"] =
                ["Başvuru kimliği sıfırdan büyük olmalıdır."];

        SubmittedApplicationEditableData? normalizedApplication = null;
        if (!SubmittedApplicationUpdateValidation.TryNormalize(
                command.Application,
                out var editable,
                out var applicationErrors))
        {
            AddErrors(errors, applicationErrors);
        }
        else
        {
            normalizedApplication = editable;
        }

        IReadOnlyCollection<ApplicationFamilyMemberData>? normalizedFamily = null;
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? normalizedHousehold =
            null;
        SubmittedApplicationPhotoUpdateData? normalizedPhotos = null;
        if (!ApplicationFieldDataValidation.TryNormalize(
                command.FamilyMembers,
                command.HouseholdAnswers,
                saveToBeneficiaryDirectory: false,
                out var family,
                out var household,
                out var fieldErrors))
        {
            AddErrors(errors, fieldErrors);
        }
        else
        {
            normalizedFamily = family;
            var householdResult =
                CompanyApplicationHouseholdPreparer.Prepare(household);
            if (householdResult.Status !=
                CompanyApplicationHouseholdPreparationStatus.Prepared)
            {
                AddErrors(
                    errors,
                    householdResult.Errors ??
                    new Dictionary<string, string[]>
                    {
                        ["householdAnswers"] =
                            ["Hane cevapları doğrulanamadı."],
                    });
            }
            else
            {
                normalizedHousehold = householdResult.Answers;
            }
        }

        if (command.Photos is not null)
        {
            var retainedIds = command.Photos.RetainedPhotoIds?.ToArray() ?? [];
            if (retainedIds.Any(value => value <= 0) ||
                retainedIds.Distinct().Count() != retainedIds.Length)
            {
                errors["retainedPhotoIds"] =
                    ["Korunacak fotoğraf kimlikleri pozitif ve benzersiz olmalıdır."];
            }
            if (retainedIds.Length + command.Photos.NewPhotos.Count >
                ApplicationPhotoPolicy.MaximumPhotoCount)
            {
                errors["photos"] =
                    [$"Toplam en fazla {ApplicationPhotoPolicy.MaximumPhotoCount} fotoğraf bulunabilir."];
            }
            AddErrors(
                errors,
                ApplicationPhotoPolicy.Validate(command.Photos.NewPhotos));
            normalizedPhotos = new(retainedIds, command.Photos.NewPhotos);
        }

        return errors.Count > 0
            ? new UpdateValidation(
                Result: Invalid(
                    "invalid_application_update",
                    errors))
            : new(
                normalizedApplication,
                normalizedFamily,
                normalizedHousehold,
                normalizedPhotos);
    }

    private static void AddErrors(
        IDictionary<string, string[]> target,
        IReadOnlyDictionary<string, string[]> source)
    {
        foreach (var error in source)
            target[error.Key] = error.Value;
    }

    private static ApplicationLifecycleResult<UpdatedSubmittedApplication>
        MapFamilyError(CompanyApplicationFamilyPreparationResult result) =>
        result.Status switch
        {
            CompanyApplicationFamilyPreparationStatus.InvalidInput =>
                Invalid(
                    result.Code ?? "invalid_application_family",
                    result.Errors ??
                    new Dictionary<string, string[]>
                    {
                        ["familyMembers"] =
                            ["Aile bilgileri doğrulanamadı."],
                    }),
            _ => Conflict(
                result.Code ?? "company_family_reference_not_found",
                "Aile bilgileri şirket referanslarıyla eşleştirilemedi."),
        };

    private static ApplicationLifecycleResult<UpdatedSubmittedApplication>
        Invalid(
            string code,
            IReadOnlyDictionary<string, string[]> errors) =>
        new(
            ApplicationLifecycleStatus.InvalidInput,
            Code: code,
            Errors: errors);

    private static ApplicationLifecycleResult<UpdatedSubmittedApplication>
        NotFound() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "application_not_found",
            Detail: "Başvuru bulunamadı.");

    private static ApplicationLifecycleResult<UpdatedSubmittedApplication>
        Forbidden() =>
        new(
            ApplicationLifecycleStatus.Forbidden,
            Code: "application_update_forbidden",
            Detail: "Bu başvuruyu yalnız oluşturan kullanıcı güncelleyebilir.");

    private static ApplicationLifecycleResult<UpdatedSubmittedApplication>
        Conflict(string code, string detail) =>
        new(
            ApplicationLifecycleStatus.Conflict,
            Code: code,
            Detail: detail);

    private sealed record UpdateValidation(
        SubmittedApplicationEditableData? Application = null,
        IReadOnlyCollection<ApplicationFamilyMemberData>? FamilyMembers = null,
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? HouseholdAnswers =
            null,
        SubmittedApplicationPhotoUpdateData? Photos = null,
        ApplicationLifecycleResult<UpdatedSubmittedApplication>? Result = null);

    private sealed record PhotoPreparationOutcome(
        PreparedPhotoUpdate? Prepared = null,
        ApplicationLifecycleResult<UpdatedSubmittedApplication>? Result = null);

    private sealed record PreparedPhotoUpdate(
        Guid PublicId,
        int CitizenId,
        IReadOnlySet<int> RetainedPhotoIds,
        IReadOnlyCollection<PreparedPhotoRecord> NewRecords,
        IReadOnlyCollection<StoredApplicationPhoto> StoredPhotos);

    private sealed record PreparedPhotoRecord(
        string PhotoPath,
        string? Description,
        DateTime UploadedAt);
}
