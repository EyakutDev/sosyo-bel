namespace SosyoBel.Application.FieldTasks;

public interface IAssignedFieldTaskQuery
{
    Task<IReadOnlyCollection<AssignedFieldTaskSummary>> GetAssignedAsync(
        string userId,
        int municipalityId,
        long municipalityMembershipId,
        int limit,
        CancellationToken cancellationToken);
}
