using System.Text.Json;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Yönetim işlemlerinin değiştirilemeyen denetim kaydıdır. Parola, token veya
/// bağlantı sırrı bu modele hiçbir zaman eklenmemelidir.
/// </summary>
internal sealed class AdministrationAuditRecord
{
    private AdministrationAuditRecord()
    {
    }

    public long Id { get; private set; }

    public int MunicipalityId { get; private set; }

    public string EntityType { get; private set; } = string.Empty;

    public Guid? EntityPublicId { get; private set; }

    public string OperationCode { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public string? ChangeSummaryJson { get; private set; }

    public string ActorUserId { get; private set; } = string.Empty;

    public DateTime CreatedAtUtc { get; private set; }

    public string? Reason { get; private set; }

    public string? ActorIp { get; private set; }

    public string? DeviceId { get; private set; }

    public Guid CorrelationId { get; private set; }

    public string? TargetUserId { get; private set; }

    public static AdministrationAuditRecord Create(
        int municipalityId,
        string entityType,
        Guid? entityPublicId,
        string operationCode,
        string actorUserId,
        DateTime createdAtUtc,
        Guid correlationId,
        string? targetUserId = null,
        string? description = null,
        string? changeSummaryJson = null,
        string? reason = null,
        string? actorIp = null,
        string? deviceId = null)
    {
        if (municipalityId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        }

        var normalizedJson = NormalizeOptional(changeSummaryJson, 0);
        if (normalizedJson is not null)
        {
            using var _ = JsonDocument.Parse(normalizedJson);
        }

        return new AdministrationAuditRecord
        {
            MunicipalityId = municipalityId,
            EntityType = NormalizeRequired(entityType, nameof(entityType), 100),
            EntityPublicId = entityPublicId,
            OperationCode = NormalizeRequired(operationCode, nameof(operationCode), 100),
            ActorUserId = NormalizeRequired(actorUserId, nameof(actorUserId), 450),
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
            CorrelationId = correlationId != Guid.Empty
                ? correlationId
                : throw new ArgumentOutOfRangeException(nameof(correlationId)),
            TargetUserId = NormalizeOptional(targetUserId, 450),
            Description = NormalizeOptional(description, 1000),
            ChangeSummaryJson = normalizedJson,
            Reason = NormalizeOptional(reason, 1000),
            ActorIp = NormalizeOptional(actorIp, 45),
            DeviceId = NormalizeOptional(deviceId, 200),
        };
    }

    private static string NormalizeRequired(
        string value,
        string parameterName,
        int maxLength)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value, parameterName);
        return NormalizeOptional(value, maxLength)!;
    }

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        if (maxLength > 0 && normalized.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        return normalized;
    }
}
