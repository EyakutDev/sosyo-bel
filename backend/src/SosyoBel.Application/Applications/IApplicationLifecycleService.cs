namespace SosyoBel.Application.Applications;

public interface IApplicationLifecycleService
{
    Task<ApplicationLifecycleResult<ApplicationDetails>> CreateDraftAsync(
        CreateApplicationDraftCommand command,
        CancellationToken cancellationToken);

    Task<ApplicationLifecycleResult<ApplicationDetails>> GetAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        CancellationToken cancellationToken);

    Task<ApplicationLifecycleResult<ApplicationDraftSnapshot>> GetDraftSnapshotAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        CancellationToken cancellationToken);

    Task<ApplicationLifecycleResult<ApplicationDetails>> UpdateDraftAsync(
        UpdateApplicationDraftCommand command,
        CancellationToken cancellationToken);

    Task<ApplicationLifecycleResult<ApplicationDetails>> SaveFieldDataAsync(
        SaveApplicationFieldDataCommand command,
        CancellationToken cancellationToken);

    Task<ApplicationLifecycleResult<ApplicationDetails>> SubmitToBoardAsync(
        SubmitApplicationToBoardCommand command,
        CancellationToken cancellationToken);
}
