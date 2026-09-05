using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Kps;
using SosyoBel.Infrastructure.Logging;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Telefonda tamamlanan başvuruyu şirketin mevcut dbo tablolarına tek transaction
/// içinde yazar. dbo dışında tablo/kolon üretmez ve ara taslak saklamaz.
/// </summary>
internal sealed class CompletedApplicationSubmissionService(
    IDbContextFactory<CompanyApplicationDbContext> contextFactory,
    IKpsProfileQuery kpsProfileQuery,
    CompanyApplicationPhotoPreparer photoPreparer,
    TimeProvider timeProvider,
    ILogger<CompletedApplicationSubmissionService> logger,
    RequestLogContext logContext)
    : ICompletedApplicationSubmissionService
{
    public async Task<ApplicationLifecycleResult<CompletedApplicationSubmission>>
        SubmitAsync(
            SubmitCompletedApplicationCommand command,
            CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);
        logContext.Stage = RequestLogStage.ValidateSubmission;
        var validation = ValidateAndNormalize(
            command,
            DateOnly.FromDateTime(timeProvider.GetUtcNow().UtcDateTime));
        if (validation.Result is not null) return validation.Result;

        var normalizedDraft = validation.Draft!;
        var normalizedFamily = validation.FamilyMembers!;
        var householdAnswers = validation.HouseholdAnswers!;
        var publicId = CreatePublicId(
            command.Actor.ActorUserId.Trim(),
            command.IdempotencyKey.Trim());
        var publicToken = publicId.ToString("N");

        logContext.Stage = RequestLogStage.CheckReplay;
        await using var preflightContext =
            await contextFactory.CreateDbContextAsync(cancellationToken);
        var replay = await FindReplayAsync(
            preflightContext,
            publicToken,
            command.Actor.ActorUserId,
            normalizedDraft.IdentityNumber,
            cancellationToken);
        if (replay is not null) return replay;

        logContext.Stage = RequestLogStage.ResolveCitizen;
        var citizenMatch = await CompanyCitizenResolver.ResolveAsync(
            preflightContext,
            normalizedDraft.IdentityNumber,
            cancellationToken);
        var citizenError = MapCitizenError(citizenMatch);
        if (citizenError is not null) return citizenError;

        // Kullanıcının ekranda gördüğü KPS verisine güvenilmez; kayıt öncesinde
        // kurum servisi aynı kimlik ve doğum tarihiyle sunucudan tekrar okunur.
        logContext.Stage = RequestLogStage.VerifyKps;
        var kpsResult = await kpsProfileQuery.GetProfileAsync(
            new KpsProfileActor(command.Actor.ActorUserId.Trim()),
            new KpsLookupCriteria(
                normalizedDraft.IdentityNumber,
                normalizedDraft.BirthDate),
            cancellationToken);
        if (kpsResult.Status != KpsProfileQueryStatus.Succeeded ||
            kpsResult.Value is null)
        {
            return MapKpsError(kpsResult);
        }

        logContext.Stage = RequestLogStage.StorePhotos;
        var photoPreparation = await photoPreparer.PrepareAsync(
            citizenMatch.CitizenId!.Value,
            publicId,
            command.Photos,
            cancellationToken);
        if (photoPreparation.Status !=
            CompanyApplicationPhotoPreparationStatus.Prepared)
        {
            return photoPreparation.Status switch
            {
                CompanyApplicationPhotoPreparationStatus.InvalidInput =>
                    Invalid(
                        photoPreparation.Code ?? "invalid_application_photos",
                        photoPreparation.Errors),
                _ => Conflict(
                    photoPreparation.Code ?? "photo_storage_error",
                    "Fotoğraflar kalıcı depoya hazırlanamadı."),
            };
        }

        var storedPhotos = photoPreparation.StoredPhotos ?? [];
        try
        {
            var strategy = preflightContext.Database.CreateExecutionStrategy();
            var outcome = await strategy.ExecuteAsync(async () =>
            {
                logContext.Stage = RequestLogStage.BeginTransaction;
                await using var context =
                    await contextFactory.CreateDbContextAsync(cancellationToken);
                await using var transaction =
                    await context.Database.BeginTransactionAsync(
                        IsolationLevel.Serializable,
                        cancellationToken);

                // Aynı istek iki sunucu düğümüne eşzamanlı ulaşırsa transaction
                // içinde tekrar kontrol edilir; ikinci dbo.Basvurular satırı açılmaz.
                logContext.Stage = RequestLogStage.CheckTransactionReplay;
                var transactionReplay = await FindReplayAsync(
                    context,
                    publicToken,
                    command.Actor.ActorUserId,
                    normalizedDraft.IdentityNumber,
                    cancellationToken);
                if (transactionReplay is not null)
                {
                    logContext.Stage = RequestLogStage.CommitTransaction;
                    await transaction.CommitAsync(cancellationToken);
                    return new SubmissionExecutionOutcome(
                        transactionReplay,
                        CreatedApplication: false);
                }

                var description = CompanyApplicationDescriptionComposer.Compose(
                    normalizedDraft.Description,
                    normalizedFamily,
                    householdAnswers,
                    normalizedDraft.FieldInspectionNote);
                var coreDraft = normalizedDraft with
                {
                    Description = description,
                    FieldInspectionNote = null,
                };
                var coreWriter = new CompanyApplicationCoreWriter(
                    context,
                    timeProvider);
                logContext.Stage = RequestLogStage.CreateApplication;
                var coreResult = await coreWriter.CreatePendingAsync(
                    command.Actor.ActorUserId,
                    new CompanyApplicationCoreInput(
                        coreDraft,
                        kpsResult.Value,
                        publicToken),
                    cancellationToken);
                if (coreResult.Status != CompanyApplicationCoreWriteStatus.Created ||
                    coreResult.ApplicationId is null ||
                    coreResult.CitizenId is null)
                {
                    return new SubmissionExecutionOutcome(
                        MapCoreError(coreResult),
                        CreatedApplication: false);
                }

                logContext.Stage = RequestLogStage.PrepareFamily;
                var familyResult =
                    await CompanyApplicationFamilyPreparer.PrepareAsync(
                        context,
                        coreResult.ApplicationId.Value,
                        normalizedFamily,
                        cancellationToken);
                if (familyResult.Status !=
                    CompanyApplicationFamilyPreparationStatus.Prepared)
                {
                    return new SubmissionExecutionOutcome(
                        MapFamilyError(familyResult),
                        CreatedApplication: false);
                }

                logContext.Stage = RequestLogStage.SaveFamilyAndPhotos;
                context.AddRange(familyResult.Records ?? []);
                var uploadedAt = timeProvider.GetLocalNow().DateTime;
                var photoRecords = photoPreparation.Records?
                    .Select(photo => CompanyHouseholdPhotoRecord.Create(
                        coreResult.CitizenId.Value,
                        photo.PhotoPath,
                        photo.Description,
                        uploadedAt))
                    .ToArray() ?? [];
                context.AddRange(photoRecords);
                await context.SaveChangesAsync(cancellationToken);
                logContext.Stage = RequestLogStage.CommitTransaction;
                await transaction.CommitAsync(cancellationToken);

                return new SubmissionExecutionOutcome(
                    Succeeded(
                        publicId,
                        coreResult.ApplicationId.Value,
                        ApplicationStatusCodes.PendingBoard),
                    CreatedApplication: true);
            });

            // Yarışan tekrar isteği dosya hazırladıysa fakat yeni başvuru açmadıysa
            // o isteğin oluşturduğu artık dosyalar güvenli biçimde temizlenir.
            if (!outcome.CreatedApplication)
                await photoPreparer.DiscardAsync(storedPhotos);
            return outcome.Result;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            await photoPreparer.DiscardAsync(storedPhotos);
            throw;
        }
        catch (DbUpdateException exception)
        {
            await photoPreparer.DiscardAsync(storedPhotos);
            logger.LogWarning(
                new EventId(1002),
                exception,
                "Company application transaction conflicted.");
            return Conflict(
                "company_application_database_conflict",
                "Başvuru mevcut bir şirket kaydıyla çakıştı.");
        }
        catch
        {
            await photoPreparer.DiscardAsync(storedPhotos);
            throw;
        }
    }

    internal static Guid CreatePublicId(string actorUserId, string idempotencyKey)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(actorUserId);
        ArgumentException.ThrowIfNullOrWhiteSpace(idempotencyKey);
        var material = Encoding.UTF8.GetBytes(
            $"{actorUserId.Trim().Length}:{actorUserId.Trim()}:{idempotencyKey.Trim()}");
        var hash = SHA256.HashData(material);
        return new Guid(hash.AsSpan(0, 16));
    }

    private static SubmissionValidation ValidateAndNormalize(
        SubmitCompletedApplicationCommand command,
        DateOnly today)
    {
        var errors = new Dictionary<string, string[]>();
        if (command.Actor is null ||
            string.IsNullOrWhiteSpace(command.Actor.ActorUserId))
        {
            errors["actor"] = ["Doğrulanmış kullanıcı kimliği bulunamadı."];
        }
        if (string.IsNullOrWhiteSpace(command.IdempotencyKey) ||
            command.IdempotencyKey.Trim().Length is < 8 or > 100)
        {
            errors["Idempotency-Key"] =
                ["8-100 karakterlik istek anahtarı zorunludur."];
        }

        ApplicationDraftData? normalizedDraft = null;
        if (!ApplicationDraftValidation.TryNormalize(
                command.Draft,
                today,
                out var draft,
                out var draftErrors))
        {
            AddErrors(errors, draftErrors);
        }
        else
        {
            normalizedDraft = draft;
        }

        IReadOnlyCollection<ApplicationFamilyMemberData>? normalizedFamily = null;
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? normalizedAnswers = null;
        if (!ApplicationFieldDataValidation.TryNormalize(
                command.FamilyMembers,
                command.HouseholdAnswers,
                saveToBeneficiaryDirectory: false,
                out var family,
                out var answers,
                out var fieldErrors))
        {
            AddErrors(errors, fieldErrors);
        }
        else
        {
            normalizedFamily = family;
            var household = CompanyApplicationHouseholdPreparer.Prepare(answers);
            if (household.Status !=
                CompanyApplicationHouseholdPreparationStatus.Prepared)
            {
                AddErrors(
                    errors,
                    household.Errors ??
                    new Dictionary<string, string[]>
                    {
                        ["householdAnswers"] =
                            ["Hane cevapları doğrulanamadı."],
                    });
            }
            else
            {
                normalizedAnswers = household.Answers;
            }
        }

        AddErrors(errors, ApplicationPhotoPolicy.Validate(command.Photos));
        if (errors.Count > 0)
        {
            return new SubmissionValidation(
                Result: Invalid("invalid_completed_application", errors));
        }

        return new SubmissionValidation(
            normalizedDraft,
            normalizedFamily,
            normalizedAnswers);
    }

    private static async Task<
        ApplicationLifecycleResult<CompletedApplicationSubmission>?>
        FindReplayAsync(
            CompanyApplicationDbContext context,
            string publicToken,
            string actorUserId,
            string identityNumber,
            CancellationToken cancellationToken)
    {
        var matches = await context.Set<CompanyApplicationRecord>()
            .AsNoTracking()
            .Where(application => application.PublicToken == publicToken)
            .Take(2)
            .ToArrayAsync(cancellationToken);
        if (matches.Length == 0) return null;
        if (matches.Length > 1)
        {
            return IdempotencyConflict(
                "company_application_token_conflict",
                "Aynı istek anahtarıyla birden fazla şirket kaydı bulundu.");
        }

        var existing = matches[0];
        if (!string.Equals(
                existing.CreatedByUserId,
                actorUserId.Trim(),
                StringComparison.Ordinal) ||
            !string.Equals(
                existing.ApplicantIdentityNumber,
                identityNumber,
                StringComparison.Ordinal))
        {
            return IdempotencyConflict(
                "application_idempotency_conflict",
                "İstek anahtarı farklı bir başvuru için daha önce kullanılmış.");
        }

        var statusCode = await CompanyApplicationStatusResolver.FindCodeAsync(
            context,
            existing.StatusId,
            cancellationToken);
        if (statusCode is null)
        {
            return Conflict(
                "company_application_status_unknown",
                "Şirket başvuru durumu mobil durumla eşleştirilemedi.");
        }

        return Succeeded(
            Guid.ParseExact(existing.PublicToken, "N"),
            existing.Id,
            statusCode);
    }

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>?
        MapCitizenError(CompanyCitizenMatch match) =>
        match.Status switch
        {
            CompanyCitizenMatchStatus.Found => null,
            CompanyCitizenMatchStatus.NotFound => new(
                ApplicationLifecycleStatus.NotFound,
                Code: "company_citizen_not_found",
                Detail: "Başvuru sahibi şirketin mevcut vatandaş kayıtlarında bulunamadı."),
            _ => Conflict(
                "company_citizen_identity_conflict",
                "T.C. kimlik numarasıyla birden fazla vatandaş kaydı bulundu."),
        };

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        MapKpsError(KpsProfileQueryResult result) =>
        result.Status switch
        {
            KpsProfileQueryStatus.InvalidInput or
            KpsProfileQueryStatus.InvalidIdentityNumber or
            KpsProfileQueryStatus.BirthDateMismatch =>
                Invalid(
                    result.Code ?? "invalid_kps_query",
                    result.Errors,
                    result.Detail),
            KpsProfileQueryStatus.AddressOutsideServiceArea =>
                Conflict(
                    result.Code ?? "kps_address_outside_service_area",
                    result.Detail ?? "Adres kurumun hizmet alanı dışında."),
            _ => Conflict(
                result.Code ?? "kps_unavailable",
                result.Detail ?? "KPS servisine ulaşılamıyor."),
        };

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        MapCoreError(CompanyApplicationCoreWriteResult result) =>
        result.Status switch
        {
            CompanyApplicationCoreWriteStatus.InvalidInput =>
                Invalid(
                    result.Code ?? "invalid_application",
                    result.Errors),
            CompanyApplicationCoreWriteStatus.CitizenNotFound => new(
                ApplicationLifecycleStatus.NotFound,
                Code: result.Code,
                Detail: "Başvuru sahibi şirketin mevcut vatandaş kayıtlarında bulunamadı."),
            _ => Conflict(
                result.Code ?? "company_application_conflict",
                "Başvuru şirket verileriyle eşleştirilemedi."),
        };

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        MapFamilyError(CompanyApplicationFamilyPreparationResult result) =>
        result.Status switch
        {
            CompanyApplicationFamilyPreparationStatus.InvalidInput =>
                Invalid(
                    result.Code ?? "invalid_application_family",
                    result.Errors),
            _ => Conflict(
                result.Code ?? "company_family_reference_not_found",
                "Aile bilgileri şirket referanslarıyla eşleştirilemedi."),
        };

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        Succeeded(Guid publicId, int applicationId, string statusCode) =>
        new(
            ApplicationLifecycleStatus.Succeeded,
            new CompletedApplicationSubmission(
                publicId,
                $"#{applicationId.ToString(CultureInfo.InvariantCulture)}",
                statusCode,
                ApplicationStatusRules.IsEditable(statusCode)));

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        Invalid(
            string code,
            IReadOnlyDictionary<string, string[]>? errors,
            string? detail = null) =>
        new(
            ApplicationLifecycleStatus.InvalidInput,
            Code: code,
            Detail: detail,
            Errors: errors);

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        Conflict(string code, string detail) =>
        new(ApplicationLifecycleStatus.Conflict, Code: code, Detail: detail);

    private static ApplicationLifecycleResult<CompletedApplicationSubmission>
        IdempotencyConflict(string code, string detail) =>
        new(
            ApplicationLifecycleStatus.IdempotencyConflict,
            Code: code,
            Detail: detail);

    private static void AddErrors(
        IDictionary<string, string[]> target,
        IReadOnlyDictionary<string, string[]> source)
    {
        foreach (var error in source)
            target[error.Key] = error.Value;
    }

    private sealed record SubmissionValidation(
        ApplicationDraftData? Draft = null,
        IReadOnlyCollection<ApplicationFamilyMemberData>? FamilyMembers = null,
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? HouseholdAnswers = null,
        ApplicationLifecycleResult<CompletedApplicationSubmission>? Result = null);

    private sealed record SubmissionExecutionOutcome(
        ApplicationLifecycleResult<CompletedApplicationSubmission> Result,
        bool CreatedApplication);
}
