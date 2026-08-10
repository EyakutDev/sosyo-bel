namespace SosyoBel.Application.Auditing;

public sealed record AuditEventSummary(
    long AuditId,
    string MunicipalityCode,
    string EntityType,
    Guid? EntityPublicId,
    string OperationCode,
    string? Description,
    string? Reason,
    string? ActorUserId,
    string? ActorDisplayName,
    string? TargetUserId,
    string? TargetDisplayName,
    DateTime OccurredAtUtc,
    Guid? CorrelationId);
