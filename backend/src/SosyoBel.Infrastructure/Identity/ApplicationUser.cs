using Microsoft.AspNetCore.Identity;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Şirketin mevcut dbo.AspNetUsers kaydıdır. Parola yönetimi ASP.NET Core Identity
/// tarafından yapılır; şirkette bulunmayan hesap yaşam döngüsü alanları ayrı
/// KullaniciUygulamaBilgileri kaydında tutulur.
/// </summary>
public sealed class ApplicationUser : IdentityUser
{
    public string FirstName { get; private set; } = string.Empty;

    public string LastName { get; private set; } = string.Empty;

    public UserApplicationInfo? ApplicationInfo { get; private set; }

    // Uzantı kaydı bulunmayan eski hesaplar, kurum onaylı geçiş yapılana kadar
    // güvenlik gereği aktif kabul edilmez.
    public bool IsActive => ApplicationInfo?.IsActive == true;

    public DateTime CreatedAtUtc => ApplicationInfo?.CreatedAtUtc ?? default;

    public DateTime? UpdatedAtUtc => ApplicationInfo?.UpdatedAtUtc;

    public string? CreatedByUserId => ApplicationInfo?.CreatedByUserId;

    public string? DeactivatedByUserId => ApplicationInfo?.DeactivatedByUserId;

    public DateTime? DeactivatedAtUtc => ApplicationInfo?.DeactivatedAtUtc;

    public string? DeactivationReason => ApplicationInfo?.DeactivationReason;

    public byte[] RowVersion => ApplicationInfo?.RowVersion ?? [];

    public string DisplayName => $"{FirstName} {LastName}".Trim();

    public static ApplicationUser Create(
        string email,
        string firstName,
        string lastName,
        DateTime createdAtUtc,
        string? createdByUserId = null)
    {
        var normalizedEmail = NormalizeRequired(email, nameof(email), 256);

        var user = new ApplicationUser
        {
            Email = normalizedEmail,
            UserName = normalizedEmail,
            EmailConfirmed = true,
            FirstName = NormalizeRequired(firstName, nameof(firstName), 100),
            LastName = NormalizeRequired(lastName, nameof(lastName), 100),
            LockoutEnabled = true,
        };

        user.ApplicationInfo = UserApplicationInfo.Create(
            user.Id,
            createdAtUtc,
            NormalizeOptional(createdByUserId, 450));
        return user;
    }

    public void UpdateProfile(
        string firstName,
        string lastName,
        string updatedByUserId,
        DateTime updatedAtUtc)
    {
        FirstName = NormalizeRequired(firstName, nameof(firstName), 100);
        LastName = NormalizeRequired(lastName, nameof(lastName), 100);
        RequireApplicationInfo().MarkUpdated(updatedByUserId, updatedAtUtc);
    }

    public void Deactivate(
        string deactivatedByUserId,
        string reason,
        DateTime updatedAtUtc)
    {
        RequireApplicationInfo().Deactivate(deactivatedByUserId, reason, updatedAtUtc);
    }

    private UserApplicationInfo RequireApplicationInfo() =>
        ApplicationInfo ?? throw new InvalidOperationException(
            "Kullanıcının uygulama profil kaydı bulunamadı.");

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
