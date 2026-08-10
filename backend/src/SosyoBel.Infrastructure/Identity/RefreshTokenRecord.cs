namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Mobil cihaza verilen refresh token'ın yalnız SHA-256 özeti saklanır. Veritabanı
/// ele geçirilse bile açık token değeri bu kayıttan geri üretilemez.
/// </summary>
internal sealed class RefreshTokenRecord
{
    private RefreshTokenRecord()
    {
    }

    public long Id { get; private set; }

    public string UserId { get; private set; } = string.Empty;

    public byte[] TokenHash { get; private set; } = [];

    public string? DeviceId { get; private set; }

    public string? CreatedByIp { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime ExpiresAtUtc { get; private set; }

    public DateTime? RevokedAtUtc { get; private set; }

    public string? RevokedByIp { get; private set; }

    public bool IsRevoked => RevokedAtUtc is not null;

    public bool IsExpired(DateTime utcNow) => ExpiresAtUtc <= utcNow;

    public static RefreshTokenRecord Create(
        string userId,
        byte[] tokenHash,
        string? deviceId,
        string? createdByIp,
        DateTime createdAtUtc,
        DateTime expiresAtUtc)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        ArgumentNullException.ThrowIfNull(tokenHash);

        if (tokenHash.Length != 32)
        {
            throw new ArgumentException("Refresh token özeti 32 byte olmalıdır.", nameof(tokenHash));
        }

        if (expiresAtUtc <= createdAtUtc)
        {
            throw new ArgumentOutOfRangeException(nameof(expiresAtUtc));
        }

        return new RefreshTokenRecord
        {
            UserId = userId,
            TokenHash = tokenHash.ToArray(),
            DeviceId = NormalizeOptional(deviceId, 200),
            CreatedByIp = NormalizeOptional(createdByIp, 45),
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
            ExpiresAtUtc = DateTime.SpecifyKind(expiresAtUtc, DateTimeKind.Utc),
        };
    }

    public void Revoke(DateTime revokedAtUtc, string? revokedByIp)
    {
        if (IsRevoked)
        {
            return;
        }

        RevokedAtUtc = DateTime.SpecifyKind(revokedAtUtc, DateTimeKind.Utc);
        RevokedByIp = NormalizeOptional(revokedByIp, 45);
    }

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        var normalized = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        if (normalized?.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        return normalized;
    }
}
