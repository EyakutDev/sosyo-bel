using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.UnitTests;

public sealed class AuthenticationDbContextModelTests
{
    [Fact]
    public void AccessControlEntitiesMatchHardenedSqlSchema()
    {
        var options = new DbContextOptionsBuilder<AuthenticationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;User Id=unused;Password=unused;TrustServerCertificate=True")
            .Options;
        using var context = new AuthenticationDbContext(options);

        AssertColumn(
            context,
            typeof(UserMunicipalityMembership),
            nameof(UserMunicipalityMembership.RoleCode),
            "KullaniciBelediyeleri",
            "sosyobel",
            "RolKodu");
        AssertColumn(
            context,
            typeof(ApplicationUser),
            nameof(ApplicationUser.DeactivationReason),
            "AspNetUsers",
            null,
            "DevreDisiGerekce");
        AssertColumn(
            context,
            typeof(UserPermissionRecord),
            nameof(UserPermissionRecord.PermissionCode),
            "KullaniciYetkileri",
            "sosyobel",
            "YetkiKodu");
        AssertColumn(
            context,
            typeof(IdempotencyRecord),
            nameof(IdempotencyRecord.RequestHash),
            "IdempotencyKayitlari",
            "sosyobel",
            "IstekHash");
        AssertColumn(
            context,
            typeof(AdministrationAuditRecord),
            nameof(AdministrationAuditRecord.TargetUserId),
            "IslemGecmisleri",
            "sosyobel",
            "HedefUserId");
    }

    [Fact]
    public void PermissionForeignKeyIncludesUserAndMunicipalityScope()
    {
        var options = new DbContextOptionsBuilder<AuthenticationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;User Id=unused;Password=unused;TrustServerCertificate=True")
            .Options;
        using var context = new AuthenticationDbContext(options);

        var permissionEntity = context.Model.FindEntityType(typeof(UserPermissionRecord));
        Assert.NotNull(permissionEntity);

        var scopedForeignKey = permissionEntity.GetForeignKeys().SingleOrDefault(key =>
            key.PrincipalEntityType.ClrType == typeof(UserMunicipalityMembership));

        Assert.NotNull(scopedForeignKey);
        Assert.Equal(
            [nameof(UserPermissionRecord.UserId), nameof(UserPermissionRecord.MunicipalityId)],
            scopedForeignKey.Properties.Select(property => property.Name));
    }

    private static void AssertColumn(
        DbContext context,
        Type entityType,
        string propertyName,
        string tableName,
        string? schema,
        string expectedColumnName)
    {
        var metadata = context.Model.FindEntityType(entityType);
        Assert.NotNull(metadata);
        var property = metadata.FindProperty(propertyName);
        Assert.NotNull(property);
        var table = StoreObjectIdentifier.Table(tableName, schema);

        Assert.Equal(expectedColumnName, property.GetColumnName(table));
    }
}
