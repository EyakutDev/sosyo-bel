using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.WorkItems;
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

    [Fact]
    public void Visible_query_includes_own_records_and_only_other_pending_records()
    {
        var options = new DbContextOptionsBuilder<CompanyApplicationDbContext>()
            .UseSqlServer(
                "Server=localhost;Database=SosyoBelQueryContract;"
                + "Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new CompanyApplicationDbContext(options);

        var sql = UserWorkItemQuery.BuildVisibleApplicationsQuery(
                context,
                "current-user",
                25)
            .ToQueryString();
        var normalizedSql = sql.ToLowerInvariant();

        Assert.Contains("[dbo].[Basvurular]", sql);
        Assert.Contains("[dbo].[BasvuruDurumlari]", sql);
        Assert.Contains("OlusturanUserId", sql);
        Assert.Contains("Beklemede", sql);
        Assert.Contains("Kurul Bekliyor", sql);
        Assert.DoesNotContain("[sosyobel]", normalizedSql);
    }

    [Fact]
    public void Visible_mapping_keeps_pending_web_record_without_mobile_public_token()
    {
        UserWorkItemQuery.UserWorkItemRow[] rows =
        [
            new()
            {
                ApplicationPublicToken = "web-token",
                ApplicationId = 3751,
                ApplicantFirstName = "Test",
                ApplicantLastName = "Örnek",
                CompanyStatusName = "Beklemede",
                CreatedByUserId = "another-user",
                ActivityAtUtc = new DateTime(2026, 9, 7, 12, 0, 0),
            },
        ];

        var item = Assert.Single(UserWorkItemQuery.MapApplications(
            rows,
            "current-user",
            WorkItemSourceCodes.Application,
            requirePublicId: false,
            enableSubmittedApplicationEditing: true));

        Assert.Equal(3751, item.ApplicationId);
        Assert.Null(item.ApplicationPublicId);
        Assert.Equal(WorkItemSourceCodes.Application, item.SourceCode);
        Assert.False(item.IsOwnedByCurrentUser);
        Assert.False(item.IsEditable);
    }

    [Fact]
    public void Owner_pending_application_is_marked_editable()
    {
        UserWorkItemQuery.UserWorkItemRow[] rows =
        [
            new()
            {
                ApplicationPublicToken =
                    "4c298f0d2cf74e9eb01eb748cd529653",
                ApplicationId = 42,
                CompanyStatusName = "Beklemede",
                CreatedByUserId = "current-user",
                ActivityAtUtc = new DateTime(2026, 9, 7, 12, 0, 0),
            },
        ];

        var item = Assert.Single(UserWorkItemQuery.MapApplications(
            rows,
            "current-user",
            WorkItemSourceCodes.Application,
            requirePublicId: false,
            enableSubmittedApplicationEditing: true));

        Assert.True(item.IsOwnedByCurrentUser);
        Assert.True(item.IsEditable);
    }

    [Fact]
    public void Existing_mine_contract_keeps_submitted_application_non_editable()
    {
        UserWorkItemQuery.UserWorkItemRow[] rows =
        [
            new()
            {
                ApplicationPublicToken =
                    "4c298f0d2cf74e9eb01eb748cd529653",
                ApplicationId = 42,
                CompanyStatusName = "Beklemede",
                CreatedByUserId = "current-user",
                ActivityAtUtc = new DateTime(2026, 9, 7, 12, 0, 0),
            },
        ];

        var item = Assert.Single(UserWorkItemQuery.MapApplications(
            rows,
            "current-user",
            WorkItemSourceCodes.OwnApplication,
            requirePublicId: true,
            enableSubmittedApplicationEditing: false));

        Assert.True(item.IsOwnedByCurrentUser);
        Assert.False(item.IsEditable);
    }
}
