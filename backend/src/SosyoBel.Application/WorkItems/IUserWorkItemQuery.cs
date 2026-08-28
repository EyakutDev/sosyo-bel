namespace SosyoBel.Application.WorkItems;

public interface IUserWorkItemQuery
{
    Task<IReadOnlyCollection<UserWorkItemSummary>> GetMineAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken);
}
