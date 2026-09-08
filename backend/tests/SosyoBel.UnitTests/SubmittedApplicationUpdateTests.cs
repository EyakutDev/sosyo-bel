using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Kps;
using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class SubmittedApplicationUpdateTests
{
    [Fact]
    public void Update_target_query_uses_only_company_dbo_application_table()
    {
        var options = new DbContextOptionsBuilder<CompanyApplicationDbContext>()
            .UseSqlServer(
                "Server=localhost;Database=SosyoBelUpdateContract;" +
                "Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new CompanyApplicationDbContext(options);

        var sql = SubmittedApplicationUpdateService
            .BuildUpdateTargetQuery(context, 42)
            .ToQueryString();

        Assert.Contains("[dbo].[Basvurular]", sql);
        Assert.DoesNotContain("[sosyobel]", sql.ToLowerInvariant());
        Assert.DoesNotContain("BasvuruUygulamaBilgileri", sql);
    }

    [Fact]
    public void Editable_data_is_normalized_without_accepting_kps_fields()
    {
        var input = new SubmittedApplicationEditableData(
            " +90 (534) 551 28 73 ",
            " yardim_turu:12 ",
            true,
            " engel_turu:4 ",
            45,
            " Talep açıklaması ",
            " Ek not ");

        var isValid = SubmittedApplicationUpdateValidation.TryNormalize(
            input,
            out var normalized,
            out var errors);

        Assert.True(isValid);
        Assert.Empty(errors);
        Assert.Equal("5345512873", normalized.PhoneNumber);
        Assert.Equal("YARDIM_TURU:12", normalized.HelpTypeCode);
        Assert.Equal("ENGEL_TURU:4", normalized.DisabilityTypeCode);
        Assert.Equal("Talep açıklaması", normalized.Description);
        Assert.Equal("Ek not", normalized.FieldInspectionNote);
    }

    [Fact]
    public void Editable_data_rejects_disability_details_when_not_disabled()
    {
        var input = new SubmittedApplicationEditableData(
            "5345512873",
            "YARDIM_TURU:12",
            false,
            "ENGEL_TURU:4",
            45,
            null,
            null);

        var isValid = SubmittedApplicationUpdateValidation.TryNormalize(
            input,
            out _,
            out var errors);

        Assert.False(isValid);
        Assert.Contains("disabilityTypeCode", errors.Keys);
        Assert.Contains("disabilityRate", errors.Keys);
    }

    [Fact]
    public void Record_update_changes_only_personnel_editable_fields()
    {
        var application = CreatePendingApplication();
        var originalIdentityNumber = application.ApplicantIdentityNumber;
        var originalFirstName = application.ApplicantFirstName;
        var originalLastName = application.ApplicantLastName;
        var originalBirthDate = application.ApplicantBirthDate;
        var originalAddress = application.ApplicationAddress;
        var originalCitizenId = application.CitizenId;
        var originalPublicToken = application.PublicToken;
        var originalStatusId = application.StatusId;

        application.UpdateEditableFields(
            "5554443322",
            helpTypeId: 21,
            hasDisability: false,
            disabilityTypeId: null,
            disabilityRate: null,
            description: "Güncellenmiş açıklama");

        Assert.Equal("5554443322", application.ApplicantPhone);
        Assert.Equal(21, application.HelpTypeId);
        Assert.False(application.HasDisability);
        Assert.Null(application.DisabilityTypeId);
        Assert.Null(application.DisabilityRate);
        Assert.Equal("Güncellenmiş açıklama", application.Description);

        Assert.Equal(originalIdentityNumber, application.ApplicantIdentityNumber);
        Assert.Equal(originalFirstName, application.ApplicantFirstName);
        Assert.Equal(originalLastName, application.ApplicantLastName);
        Assert.Equal(originalBirthDate, application.ApplicantBirthDate);
        Assert.Equal(originalAddress, application.ApplicationAddress);
        Assert.Equal(originalCitizenId, application.CitizenId);
        Assert.Equal(originalPublicToken, application.PublicToken);
        Assert.Equal(originalStatusId, application.StatusId);
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
    public void Update_access_requires_both_owner_and_pending_status(
        string ownerUserId,
        string actorUserId,
        string statusCode,
        int expected)
    {
        var access = SubmittedApplicationUpdateService.ClassifyAccess(
            ownerUserId,
            actorUserId,
            statusCode);

        Assert.Equal((SubmittedApplicationUpdateAccess)expected, access);
    }

    private static CompanyApplicationRecord CreatePendingApplication()
    {
        var draft = new ApplicationDraftData(
            "17611268484",
            new DateOnly(1982, 1, 1),
            "5345512873",
            "YARDIM_TURU:12",
            true,
            "ENGEL_TURU:4",
            45,
            "Talep açıklaması",
            null,
            null,
            null,
            null);
        var profile = new KpsProfile(
            "17611268484",
            "Hüriye",
            "Bucak",
            "Mehmet",
            "Kadriye",
            new DateOnly(1982, 1, 1),
            "Kahta",
            "Kadın",
            "Evli",
            "Açık",
            "ORDUZU MAH. KATMER SK. NO: 7",
            3019326028,
            44,
            1772,
            165111,
            840454,
            "ORDUZU MAH.",
            "KATMER SK.",
            "7",
            "1");

        return CompanyApplicationRecord.CreatePending(
            statusId: 1,
            helpTypeId: 12,
            disabilityTypeId: 4,
            requestChannelId: 3,
            neighborhoodId: 25,
            streetId: 61,
            actorUserId: "owner-user",
            applicationDate: new DateTime(2026, 9, 7, 12, 0, 0),
            publicToken: "4c298f0d2cf74e9eb01eb748cd529653",
            draft,
            profile,
            citizenId: 42);
    }
}
