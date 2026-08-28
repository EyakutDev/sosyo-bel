using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.UnitTests;

public sealed class IdentityModelTests
{
    [Fact]
    public void RefreshTokenUsesExistingIdentityTokenTableAndStoresOnlyHash()
    {
        using var context = CreateContext();
        var store = new IdentityRefreshTokenStore(context);

        var issued = store.Issue(
            "user-1",
            "device-1",
            "127.0.0.1",
            DateTime.UnixEpoch,
            DateTime.UnixEpoch.AddDays(30));
        var entity = Assert.Single(context.UserTokens.Local);

        Assert.Equal(IdentityRefreshTokenStore.LoginProvider, entity.LoginProvider);
        Assert.StartsWith(IdentityRefreshTokenStore.TokenNamePrefix, entity.Name);
        Assert.DoesNotContain(issued.Value, entity.Value, StringComparison.Ordinal);
        using var json = JsonDocument.Parse(entity.Value!);
        var storedHash = Convert.FromBase64String(
            json.RootElement.GetProperty("tokenHashBase64").GetString()!);
        Assert.Equal(
            SHA256.HashData(Encoding.UTF8.GetBytes(issued.Value)),
            storedHash);
        Assert.True(IdentityRefreshTokenStore.TryReadLocator(
            issued.Value,
            out var userId,
            out var tokenName));
        Assert.Equal("user-1", userId);
        Assert.Equal(entity.Name, tokenName);
    }

    [Fact]
    public void ExistingIdentityUserLookupDoesNotJoinExtensionTables()
    {
        using var context = CreateContext();
        var sql = context.Users
            .Where(user => user.NormalizedUserName == "PERSONEL")
            .ToQueryString();

        Assert.Contains("[dbo].[AspNetUsers]", sql);
        Assert.DoesNotContain("[sosyobel]", sql);
        Assert.DoesNotContain("KullaniciUygulamaBilgileri", sql);
        Assert.DoesNotContain("KullaniciBelediyeleri", sql);
    }

    private static AuthenticationDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AuthenticationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;User Id=unused;Password=unused;TrustServerCertificate=True")
            .Options;
        return new AuthenticationDbContext(options);
    }
}
