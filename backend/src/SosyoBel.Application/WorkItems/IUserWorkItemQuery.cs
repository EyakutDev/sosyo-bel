namespace SosyoBel.Application.WorkItems;

public interface IUserWorkItemQuery
{
    Task<IReadOnlyCollection<UserWorkItemSummary>> GetVisibleAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<UserWorkItemSummary>> GetMineAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken);
}
