namespace SosyoBel.Application.Applications;

public sealed record DeleteSubmittedApplicationCommand(
    ApplicationActorContext Actor,
    int ApplicationId);

public sealed record DeletedSubmittedApplication(int ApplicationId);

public interface IDeleteSubmittedApplicationService
{
    Task<ApplicationLifecycleResult<DeletedSubmittedApplication>> DeleteAsync(
        DeleteSubmittedApplicationCommand command,
        CancellationToken cancellationToken);
}
