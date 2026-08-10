using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using SosyoBel.Application.Applications;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class ApplicationLifecycleTests
{
    private static readonly DateOnly Today = new(2026, 8, 10);

    [Fact]
    public void DraftValidationNormalizesPhoneCodesAndText()
    {
        var input = Draft() with
        {
            PhoneNumber = "+90 (555)-123-4567",
            HelpTypeCode = " gida ",
            Description = " ihtiyaç açıklaması ",
        };

        var valid = ApplicationDraftValidation.TryNormalize(
            input,
            Today,
            out var normalized,
            out var errors);

        Assert.True(valid);
        Assert.Empty(errors);
        Assert.Equal("5551234567", normalized.PhoneNumber);
        Assert.Equal("GIDA", normalized.HelpTypeCode);
        Assert.Equal("ihtiyaç açıklaması", normalized.Description);
    }

    [Fact]
    public void DraftValidationRejectsDisabilityDetailsWhenStatusIsNone()
    {
        var input = Draft() with
        {
            HasDisability = false,
            DisabilityTypeCode = "ORTOPEDIK",
            DisabilityRate = 45,
        };

        var valid = ApplicationDraftValidation.TryNormalize(
            input,
            Today,
            out _,
            out var errors);

        Assert.False(valid);
        Assert.Contains("disabilityTypeCode", errors.Keys);
        Assert.Contains("disabilityRate", errors.Keys);
    }

    [Fact]
    public void FieldDataValidationNormalizesManualFamilyAndHouseholdCodes()
    {
        var family = new[]
        {
            new ApplicationFamilyMemberData(
                " Ayşe Yılmaz ",
                42,
                " diger ",
                " Teyze ",
                true,
                " suregen_hastalik ",
                null,
                " calisiyor ",
                " lise ",
                " sag "),
        };
        var answers = new[]
        {
            new ApplicationHouseholdAnswerData(" mulkiyet_durumu ", " kiraci "),
        };

        var valid = ApplicationFieldDataValidation.TryNormalize(
            family,
            answers,
            saveToBeneficiaryDirectory: false,
            out var normalizedFamily,
            out var normalizedAnswers,
            out var errors);

        Assert.True(valid);
        Assert.Empty(errors);
        var member = Assert.Single(normalizedFamily);
        Assert.Equal("Ayşe Yılmaz", member.FullName);
        Assert.Equal("DIGER", member.RelationshipCode);
        Assert.Equal("Teyze", member.OtherRelationshipDescription);
        Assert.Equal("SUREGEN_HASTALIK", member.DisabilityTypeCode);
        Assert.Equal("CALISIYOR", member.EmploymentStatusCode);
        var answer = Assert.Single(normalizedAnswers);
        Assert.Equal("MULKIYET_DURUMU", answer.QuestionCode);
        Assert.Equal("KIRACI", answer.OptionCode);
    }

    [Fact]
    public void FieldDataValidationRejectsDuplicateQuestionAndUnlinkedDirectoryWrite()
    {
        var answers = new[]
        {
            new ApplicationHouseholdAnswerData("EV_TEMIZLIGI", "EVET"),
            new ApplicationHouseholdAnswerData("ev_temizligi", "HAYIR"),
        };

        var valid = ApplicationFieldDataValidation.TryNormalize(
            [],
            answers,
            saveToBeneficiaryDirectory: true,
            out _,
            out _,
            out var errors);

        Assert.False(valid);
        Assert.Contains("householdAnswers[1].questionCode", errors.Keys);
        Assert.Contains("saveToBeneficiaryDirectory", errors.Keys);
    }

    [Theory]
    [InlineData(ApplicationStatusCodes.Draft, true)]
    [InlineData(ApplicationStatusCodes.PendingBoard, false)]
    [InlineData(ApplicationStatusCodes.Completed, false)]
    public void OnlyDraftStatusCanBeEdited(string statusCode, bool expected)
    {
        Assert.Equal(expected, ApplicationStatusRules.IsEditable(statusCode));
        Assert.Equal(expected, ApplicationStatusRules.CanSubmitToBoard(statusCode));
    }

    [Fact]
    public void ApplicationRowVersionMatchesSqlRowVersionColumn()
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);
        var metadata = context.Model.FindEntityType(typeof(ApplicationRecord));
        var property = metadata?.FindProperty(nameof(ApplicationRecord.RowVersion));
        var table = StoreObjectIdentifier.Table("Basvurular", "sosyobel");

        Assert.NotNull(property);
        Assert.True(property.IsConcurrencyToken);
        Assert.Equal(ValueGenerated.OnAddOrUpdate, property.ValueGenerated);
        Assert.Equal("RowVersion", property.GetColumnName(table));
    }

    [Theory]
    [InlineData(typeof(ApplicationHouseholdAnswerRecord), "BasvuruHaneCevaplari")]
    [InlineData(typeof(ApplicationPhotoRecord), "BasvuruFotograflari")]
    public void FieldEntityIdentityMatchesSqlIntColumn(Type entityType, string tableName)
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);
        var property = context.Model.FindEntityType(entityType)?.FindProperty("Id");
        var table = StoreObjectIdentifier.Table(tableName, "sosyobel");

        Assert.NotNull(property);
        Assert.Equal(typeof(int), property.ClrType);
        Assert.Equal("int", property.GetColumnType(table));
    }

    private static ApplicationDraftData Draft() =>
        new(
            "12345678901",
            new DateOnly(1990, 1, 1),
            "5551234567",
            "GIDA",
            false,
            null,
            null,
            null,
            null,
            null,
            null,
            null);
}
