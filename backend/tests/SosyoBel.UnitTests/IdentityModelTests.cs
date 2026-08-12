using SosyoBel.Infrastructure.Identity;
using System.Security.Cryptography;
using System.Text;

namespace SosyoBel.UnitTests;

public sealed class IdentityModelTests
{
    [Fact]
    public void UserWithoutApplicationInfoIsNotTreatedAsActive()
    {
        // Eski Identity satırına kurum onayı olmadan otomatik yetki verilmez.
        var userWithoutApplicationInfo = new ApplicationUser();

        Assert.False(userWithoutApplicationInfo.IsActive);
    }

    [Fact]
    public void AdministratorCreatedUserUsesEmailAsUsername()
    {
        var user = ApplicationUser.Create(
            " personel@belediye.gov.tr ",
            " Ayşe ",
            " Yılmaz ",
            new DateTime(2026, 8, 6, 9, 0, 0, DateTimeKind.Utc));

        Assert.Equal("personel@belediye.gov.tr", user.Email);
        Assert.Equal(user.Email, user.UserName);
        Assert.Equal("Ayşe Yılmaz", user.DisplayName);
        Assert.True(user.EmailConfirmed);
        Assert.True(user.IsActive);
        Assert.True(user.LockoutEnabled);
    }

    [Fact]
    public void DeactivatedUserCannotRemainActive()
    {
        var user = ApplicationUser.Create(
            "personel@belediye.gov.tr",
            "Ayşe",
            "Yılmaz",
            DateTime.UnixEpoch);

        user.Deactivate(
            "municipality-admin-1",
            "Personel kurumdan ayrıldı.",
            new DateTime(2026, 8, 6, 10, 0, 0, DateTimeKind.Utc));

        Assert.False(user.IsActive);
        Assert.NotNull(user.UpdatedAtUtc);
        Assert.Equal("municipality-admin-1", user.DeactivatedByUserId);
        Assert.Equal("Personel kurumdan ayrıldı.", user.DeactivationReason);
    }

    [Fact]
    public void RefreshTokenStoresItsOwnHashCopy()
    {
        var hash = Enumerable.Range(0, 32).Select(value => (byte)value).ToArray();
        var token = RefreshTokenRecord.Create(
            "user-1",
            hash,
            "device-1",
            "127.0.0.1",
            DateTime.UnixEpoch,
            DateTime.UnixEpoch.AddDays(30));

        hash[0] = byte.MaxValue;

        Assert.Equal(0, token.TokenHash[0]);
        Assert.False(token.IsRevoked);
        Assert.False(token.IsExpired(DateTime.UnixEpoch.AddDays(1)));
    }

    [Fact]
    public void IdempotencyRecordHashesNormalizedActorUserId()
    {
        var record = IdempotencyRecord.Create(
            " user-1 ",
            "TEST_ENDPOINT",
            "test-key-0001",
            new byte[32],
            DateTime.UnixEpoch,
            DateTime.UnixEpoch.AddHours(1));

        Assert.Equal("user-1", record.ActorUserId);
        Assert.Equal(
            SHA256.HashData(Encoding.UTF8.GetBytes("user-1")),
            record.ActorUserIdHash);
    }

    [Fact]
    public void RefreshTokenCanBeRevokedOnlyOnce()
    {
        var token = RefreshTokenRecord.Create(
            "user-1",
            new byte[32],
            null,
            null,
            DateTime.UnixEpoch,
            DateTime.UnixEpoch.AddDays(30));
        var firstRevocation = DateTime.UnixEpoch.AddHours(1);

        token.Revoke(firstRevocation, "127.0.0.1");
        token.Revoke(firstRevocation.AddHours(1), "127.0.0.2");

        Assert.True(token.IsRevoked);
        Assert.Equal(firstRevocation, token.RevokedAtUtc);
        Assert.Equal("127.0.0.1", token.RevokedByIp);
    }
}
