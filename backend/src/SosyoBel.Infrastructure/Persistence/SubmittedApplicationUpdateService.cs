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

        await using var strategyContext =
            await contextFactory.CreateDbContextAsync(cancellationToken);
        var strategy = strategyContext.Database.CreateExecutionStrategy();
        try
        {
            return await strategy.ExecuteAsync(async () =>
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
                context.RemoveRange(existingFamily);
                context.RemoveRange(existingHousehold);

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
        }
        catch (DbUpdateException exception)
        {
            logger.LogWarning(
                new EventId(1004),
                exception,
                "Company application update transaction conflicted.");
            return Conflict(
                "company_application_update_conflict",
                "Başvuru güncellemesi mevcut şirket verileriyle çakıştı.");
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

        return errors.Count > 0
            ? new UpdateValidation(
                Result: Invalid(
                    "invalid_application_update",
                    errors))
            : new(
                normalizedApplication,
                normalizedFamily,
                normalizedHousehold);
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
        ApplicationLifecycleResult<UpdatedSubmittedApplication>? Result = null);
}
