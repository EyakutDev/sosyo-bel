namespace SosyoBel.Application.Authorization;

public interface IActiveSystemAdministratorChecker
{
    Task<bool> IsActiveAsync(
        string userId,
        CancellationToken cancellationToken);
}
