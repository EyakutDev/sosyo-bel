using SosyoBel.Application.Authorization;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.UnitTests;

public sealed class AccessControlModelTests
{
    [Fact]
    public void MunicipalityMembershipAcceptsOnlyTenantRoles()
    {
        var membership = UserMunicipalityMembership.Create(
            "user-1",
            42,
            RoleCodes.Personnel,
            DateTime.UnixEpoch);

        Assert.Equal(RoleCodes.Personnel, membership.RoleCode);
        Assert.True(membership.IsActive);
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            UserMunicipalityMembership.Create(
                "user-1",
                42,
                RoleCodes.SystemAdministrator,
                DateTime.UnixEpoch));
    }

    [Fact]
    public void DeactivationRequiresAuditableReason()
    {
        var user = ApplicationUser.Create(
            "personel@belediye.gov.tr",
            "Ayşe",
            "Yılmaz",
            DateTime.UnixEpoch,
            "municipality-admin-1");

        Assert.Throws<ArgumentOutOfRangeException>(() =>
            user.Deactivate(
                "municipality-admin-1",
                "kısa",
                DateTime.UnixEpoch.AddHours(1)));

        Assert.True(user.IsActive);
    }

    [Fact]
    public void PermissionCanBeRevokedAndGrantedAgain()
    {
        var permission = UserPermissionRecord.Create(
            "user-1",
            42,
            PermissionCodes.LockedApplicationEdit,
            "system-admin-1",
            DateTime.UnixEpoch);

        permission.Revoke("system-admin-1", DateTime.UnixEpoch.AddHours(1));

        Assert.False(permission.IsActive);
        Assert.Equal("system-admin-1", permission.RevokedByUserId);

        permission.Grant("system-admin-2", DateTime.UnixEpoch.AddHours(2));

        Assert.True(permission.IsActive);
        Assert.Equal("system-admin-2", permission.GrantedByUserId);
        Assert.Null(permission.RevokedByUserId);
        Assert.Null(permission.RevokedAtUtc);
    }

    [Fact]
    public void KpsLookupPermissionIsAValidPersistedPermission()
    {
        var permission = UserPermissionRecord.Create(
            "personnel-1",
            42,
            PermissionCodes.KpsLookup,
            "municipality-admin-1",
            DateTime.UnixEpoch);

        Assert.Equal(PermissionCodes.KpsLookup, permission.PermissionCode);
        Assert.True(permission.IsActive);
    }

    [Fact]
    public void IdempotencyRecordCopiesHashAndAcceptsOnlyJsonResult()
    {
        var hash = Enumerable.Range(0, 32).Select(value => (byte)value).ToArray();
        var record = IdempotencyRecord.Create(
            "system-admin-1",
            "SYSTEM_CREATE_MUNICIPALITY",
            "request-0001",
            hash,
            DateTime.UnixEpoch,
            DateTime.UnixEpoch.AddDays(1));

        hash[0] = byte.MaxValue;

        Assert.Equal(0, record.RequestHash[0]);
        Assert.ThrowsAny<System.Text.Json.JsonException>(() =>
            record.Complete(200, "not-json"));

        record.Complete(200, "{\"ok\":true}");

        Assert.True(record.IsCompleted);
        Assert.Equal(200, record.HttpStatusCode);
    }
}
