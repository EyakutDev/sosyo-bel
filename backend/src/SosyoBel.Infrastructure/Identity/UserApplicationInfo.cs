namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Şirketin dbo.AspNetUsers tablosunda bulunmayan Sosyo-Bel hesap durumunu ve
/// denetim bilgilerini taşır. Her kullanıcı için en fazla bir kayıt bulunur.
/// </summary>
public sealed class UserApplicationInfo
{
    public string UserId { get; private set; } = string.Empty;

    public bool IsActive { get; private set; }

    public string? CreatedByUserId { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public string? UpdatedByUserId { get; private set; }

    public DateTime? UpdatedAtUtc { get; private set; }

    public string? DeactivatedByUserId { get; private set; }

    public DateTime? DeactivatedAtUtc { get; private set; }

    public string? DeactivationReason { get; private set; }

    public byte[] RowVersion { get; private set; } = [];

    public static UserApplicationInfo Create(
        string userId,
        DateTime createdAtUtc,
        string? createdByUserId = null)
    {
        return new UserApplicationInfo
        {
            UserId = NormalizeRequired(userId, nameof(userId), 450),
            IsActive = true,
            CreatedByUserId = NormalizeOptional(createdByUserId, 450),
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
        };
    }

    public void MarkUpdated(string updatedByUserId, DateTime updatedAtUtc)
    {
        UpdatedByUserId = NormalizeRequired(updatedByUserId, nameof(updatedByUserId), 450);
        UpdatedAtUtc = DateTime.SpecifyKind(updatedAtUtc, DateTimeKind.Utc);
    }

    public void Deactivate(
        string deactivatedByUserId,
        string reason,
        DateTime deactivatedAtUtc)
    {
        if (!IsActive)
        {
            return;
        }

        var normalizedActor = NormalizeRequired(
            deactivatedByUserId,
            nameof(deactivatedByUserId),
            450);
        var normalizedReason = NormalizeRequired(reason, nameof(reason), 1000);
        if (normalizedReason.Length < 10)
        {
            throw new ArgumentOutOfRangeException(
                nameof(reason),
                "Hesap kapatma gerekçesi en az 10 karakter olmalıdır.");
        }

        IsActive = false;
        DeactivatedByUserId = normalizedActor;
        DeactivatedAtUtc = DateTime.SpecifyKind(deactivatedAtUtc, DateTimeKind.Utc);
        DeactivationReason = normalizedReason;
        UpdatedByUserId = normalizedActor;
        UpdatedAtUtc = DeactivatedAtUtc;
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

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        if (normalized.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        return normalized;
    }
}
