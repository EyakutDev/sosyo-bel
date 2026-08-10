namespace SosyoBel.Application.WorkItems;

public interface IUserWorkItemQuery
{
    Task<IReadOnlyCollection<UserWorkItemSummary>> GetMineAsync(
        string userId,
        int municipalityId,
        long municipalityMembershipId,
        int limit,
        CancellationToken cancellationToken);
}
