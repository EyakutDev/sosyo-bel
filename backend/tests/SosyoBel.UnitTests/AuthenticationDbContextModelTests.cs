using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.UnitTests;

public sealed class AuthenticationDbContextModelTests
{
    [Fact]
    public void IdentityModelUsesOnlyExistingCompanyDboTables()
    {
        using var context = CreateContext();
        var mappedTables = context.Model.GetEntityTypes()
            .Select(entity => (entity.GetTableName(), entity.GetSchema()))
            .ToArray();

        Assert.Equal(7, mappedTables.Length);
        Assert.All(mappedTables, mapping => Assert.Equal("dbo", mapping.Item2));
        Assert.Equal(
            [
                "AspNetRoleClaims",
                "AspNetRoles",
                "AspNetUserClaims",
                "AspNetUserLogins",
                "AspNetUserRoles",
                "AspNetUserTokens",
                "AspNetUsers",
            ],
            mappedTables
                .Select(mapping => mapping.Item1!)
                .Order(StringComparer.Ordinal)
                .ToArray());
    }

    [Fact]
    public void UserNameAndProfileColumnsMatchCompanySchema()
    {
        using var context = CreateContext();

        AssertColumn(
            context,
            typeof(ApplicationUser),
            nameof(ApplicationUser.FirstName),
            "AspNetUsers",
            "Ad");
        AssertColumn(
            context,
            typeof(ApplicationUser),
            nameof(ApplicationUser.LastName),
            "AspNetUsers",
            "Soyad");
    }

    [Fact]
    public void IdentityKeysMatchCompanySchemaLength()
    {
        using var context = CreateContext();

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

    private static AuthenticationDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AuthenticationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;User Id=unused;Password=unused;TrustServerCertificate=True")
            .Options;
        return new AuthenticationDbContext(options);
    }

    private static void AssertColumn(
        DbContext context,
        Type entityType,
        string propertyName,
        string tableName,
        string expectedColumnName)
    {
        var metadata = context.Model.FindEntityType(entityType);
        Assert.NotNull(metadata);
        var property = metadata.FindProperty(propertyName);
        Assert.NotNull(property);
        var table = StoreObjectIdentifier.Table(tableName, "dbo");

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
