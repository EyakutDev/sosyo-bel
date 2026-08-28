using Microsoft.AspNetCore.Identity;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Şirketin mevcut dbo.AspNetUsers kaydının API tarafındaki karşılığıdır.
/// Kullanıcı oluşturma ve rol yönetimi mevcut web panelinin sorumluluğundadır.
/// </summary>
public sealed class ApplicationUser : IdentityUser
{
    public string FirstName { get; private set; } = null!;

    public string LastName { get; private set; } = null!;

    public string DisplayName => string.Concat(FirstName, ' ', LastName).Trim();
}
