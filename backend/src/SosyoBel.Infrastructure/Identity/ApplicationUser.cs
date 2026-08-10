using Microsoft.AspNetCore.Identity;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Personel hesabıdır. Parola yönetimi bu sınıfta değil ASP.NET Core Identity'de
/// yapılır; burada yalnız Sosyo-Bel'e ait profil ve hesap durumu tutulur.
/// </summary>
public sealed class ApplicationUser : IdentityUser
{
    public string FirstName { get; private set; } = string.Empty;

    public string LastName { get; private set; } = string.Empty;

    public bool IsActive { get; private set; } = true;

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? UpdatedAtUtc { get; private set; }

    public string? CreatedByUserId { get; private set; }

    public string? DeactivatedByUserId { get; private set; }

    public DateTime? DeactivatedAtUtc { get; private set; }

    public string? DeactivationReason { get; private set; }

    public byte[] RowVersion { get; private set; } = [];

    public string DisplayName => $"{FirstName} {LastName}".Trim();

    public static ApplicationUser Create(
        string email,
        string firstName,
        string lastName,
        DateTime createdAtUtc,
        string? createdByUserId = null)
    {
        var normalizedEmail = NormalizeRequired(email, nameof(email), 256);

        return new ApplicationUser
        {
            Email = normalizedEmail,
            UserName = normalizedEmail,
            EmailConfirmed = true,
            FirstName = NormalizeRequired(firstName, nameof(firstName), 100),
            LastName = NormalizeRequired(lastName, nameof(lastName), 100),
            IsActive = true,
            LockoutEnabled = true,
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
            CreatedByUserId = NormalizeOptional(createdByUserId, 128),
        };
    }

    public void UpdateProfile(string firstName, string lastName, DateTime updatedAtUtc)
    {
        FirstName = NormalizeRequired(firstName, nameof(firstName), 100);
        LastName = NormalizeRequired(lastName, nameof(lastName), 100);
        UpdatedAtUtc = DateTime.SpecifyKind(updatedAtUtc, DateTimeKind.Utc);
    }

    public void Deactivate(
        string deactivatedByUserId,
        string reason,
        DateTime updatedAtUtc)
    {
        if (!IsActive)
        {
            return;
        }

        var normalizedReason = NormalizeRequired(reason, nameof(reason), 1000);
        if (normalizedReason.Length < 10)
        {
            throw new ArgumentOutOfRangeException(
                nameof(reason),
                "Hesap kapatma gerekçesi en az 10 karakter olmalıdır.");
        }

        IsActive = false;
        DeactivatedByUserId = NormalizeRequired(
            deactivatedByUserId,
            nameof(deactivatedByUserId),
            128);
        DeactivatedAtUtc = DateTime.SpecifyKind(updatedAtUtc, DateTimeKind.Utc);
        DeactivationReason = normalizedReason;
        UpdatedAtUtc = DeactivatedAtUtc;
    }

    private static string NormalizeRequired(string value, string parameterName, int maxLength)
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
