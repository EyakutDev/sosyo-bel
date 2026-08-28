namespace SosyoBel.Application.FieldTasks;

public interface IAssignedFieldTaskQuery
{
    Task<IReadOnlyCollection<AssignedFieldTaskSummary>> GetAssignedAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken);
}
