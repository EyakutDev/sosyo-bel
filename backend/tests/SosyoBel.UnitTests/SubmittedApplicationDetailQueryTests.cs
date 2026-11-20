using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Applications;
using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class SubmittedApplicationDetailQueryTests
{
    [Fact]
    public void Detail_queries_use_only_verified_company_dbo_tables()
    {
        var options = new DbContextOptionsBuilder<CompanyApplicationDbContext>()
            .UseSqlServer(
                "Server=localhost;Database=SosyoBelDetailContract;" +
                "Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new CompanyApplicationDbContext(options);

        var sql = string.Join(
            Environment.NewLine,
            SubmittedApplicationDetailQuery
                .BuildApplicationQuery(context, 42, "current-user")
                .ToQueryString(),
            SubmittedApplicationDetailQuery
                .BuildFamilyQuery(context, 42)
                .ToQueryString(),
            SubmittedApplicationDetailQuery
                .BuildHouseholdAnswerQuery(context, 42)
                .ToQueryString(),
            SubmittedApplicationDetailQuery
                .BuildPhotoQuery(
                    context,
                    9,
                    "/uploads/hanefotograflari/application/")
                .ToQueryString());

        Assert.Contains("[dbo].[Basvurular]", sql);
        Assert.Contains("[dbo].[BasvuruDurumlari]", sql);
        Assert.Contains("[dbo].[Vatandaslar]", sql);
        Assert.Contains("[dbo].[BasvuruAileFertleri]", sql);
        Assert.Contains("[dbo].[Yakinliklar]", sql);
        Assert.Contains("[dbo].[BasvuruHaneCevaplari]", sql);
        Assert.Contains("[dbo].[HaneFotograflari]", sql);
        Assert.Contains("OlusturanUserId", sql);
        Assert.Contains("Beklemede", sql);
        Assert.DoesNotContain("[sosyobel]", sql.ToLowerInvariant());
    }

    [Fact]
    public void Detail_maps_stored_snapshot_and_allows_only_owner_to_edit_pending_application()
    {
        var publicId = Guid.Parse("4c298f0d-2cf7-4e9e-b01e-b748cd529653");
        var application = PendingApplication(publicId, "owner-user");
        SubmittedApplicationDetailQuery.CompanyApplicationFamilyRow[] family =
        [
            new()
            {
                Id = 3,
                FullName = "Ayşe Örnek",
                Age = 40,
                HasDisability = false,
                EmploymentStatusId = 6,
                EducationStatusId = 7,
                RelationshipId = 8,
                RelationshipName = "Diğer",
            },
        ];
        SubmittedApplicationDetailQuery.CompanyApplicationHouseholdAnswerRow[]
            household =
        [
            new()
            {
                Id = 1,
                QuestionCode = "EV_ESYALARI",
                OptionCode = "YETERLI",
            },
            new()
            {
                Id = 2,
                QuestionCode = "MULKIYET_DURUMU",
                OptionCode = "EV_SAHIBI",
            },
        ];
        SubmittedApplicationDetailQuery.CompanyApplicationPhotoRow[] photos =
        [
            new()
            {
                Id = 15,
                UrlPath =
                    $"/uploads/hanefotograflari/{publicId:N}/01-photo.jpg",
                Description = " Başvuru Formundan Yüklendi ",
                UploadedAt = new DateTime(2026, 9, 7, 15, 30, 0),
            },
        ];

        var result = SubmittedApplicationDetailQuery.BuildDetails(
            new ApplicationActorContext("owner-user"),
            application,
            family,
            household,
            photos);

        Assert.Equal(42, result.ApplicationId);
        Assert.Equal(publicId, result.ApplicationPublicId);
        Assert.Equal("#42", result.ApplicationNumber);
        Assert.Equal(WorkItemStatusCodes.BoardPending, result.StatusCode);
        Assert.True(result.IsOwnedByCurrentUser);
        Assert.True(result.IsEditable);
        Assert.Equal(new DateOnly(1982, 1, 1), result.BirthDate);
        Assert.Equal("YARDIM_TURU:12", result.HelpTypeCode);
        Assert.Equal("ENGEL_TURU:4", result.DisabilityTypeCode);

        var member = Assert.Single(result.FamilyMembers);
        Assert.Equal("DIGER", member.RelationshipCode);
        Assert.Equal("CALISMA_DURUMU:6", member.EmploymentStatusCode);
        Assert.Equal("EGITIM_DURUMU:7", member.EducationStatusCode);
        Assert.Null(member.VitalStatusCode);

        Assert.Equal(
            ["MULKIYET_DURUMU", "EV_ESYALARI"],
            result.HouseholdAnswers.Select(answer => answer.QuestionCode));
        var photo = Assert.Single(result.Photos);
        Assert.Equal(15, photo.PhotoId);
        Assert.Equal("Başvuru Formundan Yüklendi", photo.Description);
    }

    [Fact]
    public void Detail_does_not_allow_non_owner_to_edit_pending_application()
    {
        var application = PendingApplication(
            Guid.Parse("94452f16-1a8b-4c32-9429-ac55f425d8d9"),
            "owner-user");

        var result = SubmittedApplicationDetailQuery.BuildDetails(
            new ApplicationActorContext("different-user"),
            application,
            [],
            [],
            []);

        Assert.False(result.IsOwnedByCurrentUser);
        Assert.False(result.IsEditable);
    }

    private static SubmittedApplicationDetailQuery.CompanyApplicationDetailRow
        PendingApplication(Guid publicId, string ownerUserId) =>
        new()
        {
            ApplicationId = 42,
            CitizenId = 9,
            PublicToken = publicId.ToString("N"),
            CompanyStatusName = "Beklemede",
            CreatedByUserId = ownerUserId,
            ApplicationDate = new DateTime(2026, 9, 7, 14, 0, 0),
            IdentityNumber = "10000000146",
            FirstName = "Test",
            LastName = "Örnek",
            BirthDateStorage = "01.01.1982",
            PhoneNumber = "5345512873",
            HelpTypeId = 12,
            HasDisability = true,
            DisabilityTypeId = 4,
            DisabilityRate = 45,
            Description = "Talep açıklaması",
            Address = "Battalgazi / Malatya",
            Gender = "Kadın",
            BirthPlace = "Merkez",
            MaritalStatus = "Evli",
        };
}
