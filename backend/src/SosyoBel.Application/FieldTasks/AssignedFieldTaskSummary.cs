namespace SosyoBel.Application.FieldTasks;

public sealed record AssignedFieldTaskSummary(
    Guid TaskPublicId,
    Guid ApplicationPublicId,
    string ApplicationNumber,
    string ApplicantFullName,
    string? Address,
    string StatusCode,
    string? Description,
    DateTime AssignedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc);
