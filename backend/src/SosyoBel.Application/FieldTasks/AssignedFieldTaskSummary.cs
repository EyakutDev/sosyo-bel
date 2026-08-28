namespace SosyoBel.Application.FieldTasks;

public sealed record AssignedFieldTaskSummary(
    int TaskId,
    int CitizenId,
    string ApplicantFullName,
    string? Address,
    string StatusCode,
    bool IsCompleted,
    string? Description,
    DateTime ActivityAtUtc);
