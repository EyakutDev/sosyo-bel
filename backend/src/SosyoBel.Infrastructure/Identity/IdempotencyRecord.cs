using System.Text.Json;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Mobil istemcinin aynı yönetim isteğini ağ sorunu nedeniyle tekrar göndermesi
/// halinde işlemin ikinci kez uygulanmasını engeller.
/// </summary>
internal sealed class IdempotencyRecord
{
    private IdempotencyRecord()
    {
    }

    public long Id { get; private set; }

    public string ActorUserId { get; private set; } = string.Empty;

    public string EndpointCode { get; private set; } = string.Empty;

    public string IdempotencyKey { get; private set; } = string.Empty;

    public byte[] RequestHash { get; private set; } = [];

    public int? HttpStatusCode { get; private set; }

    public string? ResultJson { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime ExpiresAtUtc { get; private set; }

    public bool IsCompleted => HttpStatusCode is not null && ResultJson is not null;

    public static IdempotencyRecord Create(
        string actorUserId,
        string endpointCode,
        string idempotencyKey,
        byte[] requestHash,
        DateTime createdAtUtc,
        DateTime expiresAtUtc)
    {
        ArgumentNullException.ThrowIfNull(requestHash);
        if (requestHash.Length != 32)
        {
            throw new ArgumentException("İstek özeti 32 byte olmalıdır.", nameof(requestHash));
        }

        if (expiresAtUtc <= createdAtUtc)
        {
            throw new ArgumentOutOfRangeException(nameof(expiresAtUtc));
        }

        return new IdempotencyRecord
        {
            ActorUserId = NormalizeRequired(actorUserId, nameof(actorUserId), 128),
            EndpointCode = NormalizeRequired(endpointCode, nameof(endpointCode), 150),
            IdempotencyKey = NormalizeIdempotencyKey(idempotencyKey),
            RequestHash = requestHash.ToArray(),
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
            ExpiresAtUtc = DateTime.SpecifyKind(expiresAtUtc, DateTimeKind.Utc),
        };
    }

    public void Complete(int httpStatusCode, string resultJson)
    {
        if (httpStatusCode is < 200 or > 599)
        {
            throw new ArgumentOutOfRangeException(nameof(httpStatusCode));
        }

        ArgumentException.ThrowIfNullOrWhiteSpace(resultJson);
        using var _ = JsonDocument.Parse(resultJson);
        HttpStatusCode = httpStatusCode;
        ResultJson = resultJson;
    }

    private static string NormalizeIdempotencyKey(string value)
    {
        var normalized = NormalizeRequired(value, nameof(value), 100);
        if (normalized.Length < 8)
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        return normalized;
    }

    private static string NormalizeRequired(
        string value,
        string parameterName,
        int maxLength)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value, parameterName);
        var normalized = value.Trim();
        if (normalized.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(parameterName);
        }

        return normalized;
    }
}
