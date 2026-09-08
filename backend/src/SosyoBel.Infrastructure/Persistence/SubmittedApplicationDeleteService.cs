using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SosyoBel.Application.Applications;
using SosyoBel.Infrastructure.Logging;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Yalnız sahibinin Beklemede durumundaki şirket başvurusunu ve mobil akışın
/// oluşturduğu bağlı dbo kayıtlarını tek transaction içinde fiziksel olarak siler.
/// </summary>
internal sealed class SubmittedApplicationDeleteService(
    IDbContextFactory<CompanyApplicationDbContext> contextFactory,
    CompanyApplicationPhotoPreparer photoPreparer,
    ILogger<SubmittedApplicationDeleteService> logger,
    RequestLogContext logContext) : IDeleteSubmittedApplicationService
{
    public async Task<ApplicationLifecycleResult<DeletedSubmittedApplication>>
        DeleteAsync(
            DeleteSubmittedApplicationCommand command,
            CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);
        logContext.Stage = RequestLogStage.ValidateApplicationDelete;
        if (command.Actor is null ||
            string.IsNullOrWhiteSpace(command.Actor.ActorUserId) ||
            command.ApplicationId <= 0)
        {
            var errors = new Dictionary<string, string[]>();
            if (command.Actor is null ||
                string.IsNullOrWhiteSpace(command.Actor.ActorUserId))
            {
                errors["actor"] =
                    ["Doğrulanmış kullanıcı kimliği bulunamadı."];
            }
            if (command.ApplicationId <= 0)
            {
                errors["applicationId"] =
                    ["Başvuru kimliği sıfırdan büyük olmalıdır."];
            }
            return Invalid(errors);
        }

        IReadOnlyCollection<string> deletedPhotoPaths = [];
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

                logContext.Stage = RequestLogStage.LoadApplicationForDelete;
                var application = await BuildDeleteTargetQuery(
                        context,
                        command.ApplicationId)
                    .SingleOrDefaultAsync(cancellationToken);
                if (application is null) return NotFound();

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
                        "application_not_deletable",
                        "Yalnız Beklemede durumundaki başvuru silinebilir.");
                }

                if (application.CitizenId is not > 0 ||
                    !Guid.TryParseExact(application.PublicToken, "N", out var publicId))
                {
                    return Conflict(
                        "application_delete_identity_missing",
                        "Başvurunun güvenli silme bağlantısı bulunamadı.");
                }

                var family = await context
                    .Set<CompanyApplicationFamilyMemberRecord>()
                    .Where(member => member.ApplicationId == application.Id)
                    .ToArrayAsync(cancellationToken);
                var household = await context
                    .Set<CompanyApplicationHouseholdAnswerRecord>()
                    .Where(answer => answer.ApplicationId == application.Id)
                    .ToArrayAsync(cancellationToken);
                var photoPathPrefix =
                    $"/uploads/hanefotograflari/{publicId:N}/";
                var photos = await context
                    .Set<CompanyHouseholdPhotoRecord>()
                    .Where(photo =>
                        photo.CitizenId == application.CitizenId.Value &&
                        photo.PhotoPath.StartsWith(photoPathPrefix))
                    .ToArrayAsync(cancellationToken);

                deletedPhotoPaths = photos
                    .Select(photo => photo.PhotoPath)
                    .ToArray();
                context.RemoveRange(family);
                context.RemoveRange(household);
                context.RemoveRange(photos);

                logContext.Stage = RequestLogStage.SaveApplicationDelete;
                await context.SaveChangesAsync(cancellationToken);
                context.Remove(application);
                await context.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);

                return new ApplicationLifecycleResult<DeletedSubmittedApplication>(
                    ApplicationLifecycleStatus.Succeeded,
                    new DeletedSubmittedApplication(application.Id));
            });

            if (result.Status == ApplicationLifecycleStatus.Succeeded)
            {
                await photoPreparer.DeleteCompanyPathsAsync(deletedPhotoPaths);
            }
            return result;
        }
        catch (DbUpdateException exception)
        {
            logger.LogWarning(
                new EventId(1005),
                exception,
                "Company application delete transaction conflicted.");
            return Conflict(
                "company_application_delete_conflict",
                "Başvuruya bağlı işlem kayıtları bulunduğu için silinemedi.");
        }
    }

    internal static IQueryable<CompanyApplicationRecord> BuildDeleteTargetQuery(
        CompanyApplicationDbContext context,
        int applicationId) =>
        context.Set<CompanyApplicationRecord>()
            .Where(application => application.Id == applicationId);

    internal static SubmittedApplicationUpdateAccess ClassifyAccess(
        string? ownerUserId,
        string actorUserId,
        string? statusCode) =>
        SubmittedApplicationUpdateService.ClassifyAccess(
            ownerUserId,
            actorUserId,
            statusCode);

    private static ApplicationLifecycleResult<DeletedSubmittedApplication>
        Invalid(IReadOnlyDictionary<string, string[]> errors) =>
        new(
            ApplicationLifecycleStatus.InvalidInput,
            Code: "invalid_application_delete",
            Errors: errors);

    private static ApplicationLifecycleResult<DeletedSubmittedApplication>
        NotFound() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "application_not_found",
            Detail: "Başvuru bulunamadı.");

    private static ApplicationLifecycleResult<DeletedSubmittedApplication>
        Forbidden() =>
        new(
            ApplicationLifecycleStatus.Forbidden,
            Code: "application_delete_forbidden",
            Detail: "Bu başvuruyu yalnız oluşturan kullanıcı silebilir.");

    private static ApplicationLifecycleResult<DeletedSubmittedApplication>
        Conflict(string code, string detail) =>
        new(
            ApplicationLifecycleStatus.Conflict,
            Code: code,
            Detail: detail);
}
