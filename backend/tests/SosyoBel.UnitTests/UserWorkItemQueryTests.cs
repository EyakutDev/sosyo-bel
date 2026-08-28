using Microsoft.EntityFrameworkCore;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class UserWorkItemQueryTests
{
    [Fact]
    public void Own_application_query_uses_only_existing_company_dbo_tables()
    {
        var options = new DbContextOptionsBuilder<CompanyApplicationDbContext>()
            .UseSqlServer(
                "Server=localhost;Database=SosyoBelQueryContract;"
                + "Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new CompanyApplicationDbContext(options);

        var sql = UserWorkItemQuery.BuildOwnApplicationsQuery(
                context,
                "personnel-user-id",
                25)
            .ToQueryString();

        Assert.Contains("[dbo].[Basvurular]", sql);
        Assert.Contains("[dbo].[BasvuruDurumlari]", sql);
        Assert.DoesNotContain("sosyobel", sql.ToLowerInvariant());
        Assert.DoesNotContain("BasvuruUygulamaBilgileri", sql);
    }
}
