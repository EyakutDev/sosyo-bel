using Microsoft.AspNetCore.Identity;
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
            nameof(ApplicationUser.FirstName),
            "AspNetUsers",
            null,
            "Ad");
        AssertColumn(
            context,
            typeof(UserApplicationInfo),
            nameof(UserApplicationInfo.DeactivationReason),
            "KullaniciUygulamaBilgileri",
            "sosyobel",
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
            typeof(IdempotencyRecord),
            nameof(IdempotencyRecord.ActorUserIdHash),
            "IdempotencyKayitlari",
            "sosyobel",
            "ActorUserIdHash");
        AssertColumn(
            context,
            typeof(AdministrationAuditRecord),
            nameof(AdministrationAuditRecord.TargetUserId),
            "IslemGecmisleri",
            "sosyobel",
            "HedefUserId");
    }

    [Fact]
    public void IdempotencyUniqueIndexUsesFixedLengthActorHash()
    {
        var options = new DbContextOptionsBuilder<AuthenticationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;User Id=unused;Password=unused;TrustServerCertificate=True")
            .Options;
        using var context = new AuthenticationDbContext(options);

        var entity = context.Model.FindEntityType(typeof(IdempotencyRecord));
        Assert.NotNull(entity);
        var uniqueIndex = entity.GetIndexes().Single(index =>
            index.IsUnique &&
            index.Properties.Select(property => property.Name).SequenceEqual(
                [
                    nameof(IdempotencyRecord.ActorUserIdHash),
                    nameof(IdempotencyRecord.EndpointCode),
                    nameof(IdempotencyRecord.IdempotencyKey),
                ]));

        Assert.Equal("binary(32)", uniqueIndex.Properties[0].GetColumnType());
    }

    [Fact]
    public void IdentityKeysMatchCompanySchemaLength()
    {
        var options = new DbContextOptionsBuilder<AuthenticationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;User Id=unused;Password=unused;TrustServerCertificate=True")
            .Options;
        using var context = new AuthenticationDbContext(options);

        AssertMaxLength(context, typeof(ApplicationUser), nameof(ApplicationUser.Id), 450);
        AssertMaxLength(context, typeof(IdentityRole), nameof(IdentityRole.Id), 450);
        AssertMaxLength(
            context,
            typeof(IdentityUserLogin<string>),
            nameof(IdentityUserLogin<string>.LoginProvider),
            450);
        AssertMaxLength(
            context,
            typeof(IdentityUserToken<string>),
            nameof(IdentityUserToken<string>.Name),
            450);
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

    private static void AssertMaxLength(
        DbContext context,
        Type entityType,
        string propertyName,
        int expectedMaxLength)
    {
        var metadata = context.Model.FindEntityType(entityType);
        Assert.NotNull(metadata);
        var property = metadata.FindProperty(propertyName);
        Assert.NotNull(property);
        Assert.Equal(expectedMaxLength, property.GetMaxLength());
    }
}
