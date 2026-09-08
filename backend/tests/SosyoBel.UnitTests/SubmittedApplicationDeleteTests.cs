using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class SubmittedApplicationDeleteTests
{
    [Fact]
    public void Delete_target_query_uses_only_company_dbo_application_table()
    {
        var options = new DbContextOptionsBuilder<CompanyApplicationDbContext>()
            .UseSqlServer(
                "Server=localhost;Database=SosyoBelDeleteContract;" +
                "Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new CompanyApplicationDbContext(options);

        var sql = SubmittedApplicationDeleteService
            .BuildDeleteTargetQuery(context, 42)
            .ToQueryString();

        Assert.Contains("[dbo].[Basvurular]", sql);
        Assert.DoesNotContain("[sosyobel]", sql.ToLowerInvariant());
        Assert.DoesNotContain("BasvuruUygulamaBilgileri", sql);
    }

    [Theory]
    [InlineData(
        "owner-user",
        "owner-user",
        WorkItemStatusCodes.BoardPending,
        (int)SubmittedApplicationUpdateAccess.Allowed)]
    [InlineData(
        "owner-user",
        "another-user",
        WorkItemStatusCodes.BoardPending,
        (int)SubmittedApplicationUpdateAccess.NotOwner)]
    [InlineData(
        "owner-user",
        "owner-user",
        WorkItemStatusCodes.Completed,
        (int)SubmittedApplicationUpdateAccess.NotPending)]
    public void Delete_access_requires_both_owner_and_pending_status(
        string ownerUserId,
        string actorUserId,
        string statusCode,
        int expected)
    {
        var access = SubmittedApplicationDeleteService.ClassifyAccess(
            ownerUserId,
            actorUserId,
            statusCode);

        Assert.Equal((SubmittedApplicationUpdateAccess)expected, access);
    }
}
