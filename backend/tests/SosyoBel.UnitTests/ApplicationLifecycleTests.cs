using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using SosyoBel.Application.Applications;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class ApplicationLifecycleTests
{
    private static readonly DateOnly Today = new(2026, 8, 10);

    [Fact]
    public void ApplicationActorUsesOnlyAuthenticatedIdentityUserId()
    {
        var properties = typeof(ApplicationActorContext)
            .GetProperties()
            .Select(value => value.Name)
            .ToArray();

        Assert.Equal([nameof(ApplicationActorContext.ActorUserId)], properties);
    }

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
        var table = StoreObjectIdentifier.Table(
            "BasvuruUygulamaBilgileri",
            "sosyobel");

        Assert.NotNull(property);
        Assert.True(property.IsConcurrencyToken);
        Assert.Equal(ValueGenerated.OnAddOrUpdate, property.ValueGenerated);
        Assert.Equal("RowVersion", property.GetColumnName(table));
    }

    [Fact]
    public void ApplicationUsesCompanyTableAndOneToOneMetadataExtension()
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);
        var metadata = context.Model.FindEntityType(typeof(ApplicationRecord));
        var companyTable = StoreObjectIdentifier.Table("Basvurular", "dbo");
        var extensionTable = StoreObjectIdentifier.Table(
            "BasvuruUygulamaBilgileri",
            "sosyobel");

        Assert.NotNull(metadata);
        Assert.Equal(
            "BasvuranTcKimlikNo",
            metadata.FindProperty(nameof(ApplicationRecord.IdentityNumber))
                ?.GetColumnName(companyTable));
        Assert.Equal(
            "PublicId",
            metadata.FindProperty(nameof(ApplicationRecord.PublicId))
                ?.GetColumnName(extensionTable));
        Assert.Equal(
            "BasvuruId",
            metadata.FindProperty(nameof(ApplicationRecord.Id))
                ?.GetColumnName(extensionTable));
        Assert.Null(metadata.FindProperty("MunicipalityId"));
    }

    [Fact]
    public void FamilyMemberUsesCompanyTableAndOneToOneMetadataExtension()
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);
        var metadata = context.Model.FindEntityType(typeof(ApplicationFamilyMemberRecord));
        var companyTable = StoreObjectIdentifier.Table("BasvuruAileFertleri", "dbo");
        var extensionTable = StoreObjectIdentifier.Table(
            "BasvuruAileFertiUygulamaBilgileri",
            "sosyobel");

        Assert.NotNull(metadata);
        Assert.Equal(
            "AdSoyad",
            metadata.FindProperty(nameof(ApplicationFamilyMemberRecord.FullName))
                ?.GetColumnName(companyTable));
        Assert.Equal(
            "YasamDurumuId",
            metadata.FindProperty(nameof(ApplicationFamilyMemberRecord.VitalStatusId))
                ?.GetColumnName(extensionTable));
        Assert.Equal(
            "BasvuruAileFertiId",
            metadata.FindProperty(nameof(ApplicationFamilyMemberRecord.Id))
                ?.GetColumnName(extensionTable));
        Assert.Null(metadata.FindProperty("MunicipalityId"));
        Assert.Null(metadata.FindProperty("SourceFamilyMemberId"));
    }

    [Theory]
    [InlineData(typeof(ApplicationStatusReference), "BasvuruDurumlari")]
    [InlineData(typeof(HelpTypeReference), "YardimTurleri")]
    [InlineData(typeof(DisabilityTypeReference), "EngelTurleri")]
    [InlineData(typeof(RequestChannelReference), "TalepGelisKanallari")]
    [InlineData(typeof(RelationshipReference), "Yakinliklar")]
    [InlineData(typeof(EmploymentStatusReference), "CalismaDurumlari")]
    [InlineData(typeof(EducationStatusReference), "EgitimDurumlari")]
    public void CoreReferencesUseExistingCompanyLookupTables(
        Type entityType,
        string tableName)
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);
        var metadata = context.Model.FindEntityType(entityType);

        Assert.NotNull(metadata);
        Assert.Equal(tableName, metadata.GetTableName());
        Assert.Equal("dbo", metadata.GetSchema());
    }

    [Fact]
    public void ReferenceCatalogFieldsMatchCompanyAndSosyoBelColumns()
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);

        var help = context.Model.FindEntityType(typeof(HelpTypeReference));
        var vital = context.Model.FindEntityType(typeof(VitalStatusReference));
        var question = context.Model.FindEntityType(typeof(HouseholdQuestionReference));
        var option = context.Model.FindEntityType(typeof(HouseholdQuestionOptionReference));
        var helpTable = StoreObjectIdentifier.Table("YardimTurleri", "dbo");
        var vitalTable = StoreObjectIdentifier.Table("YasamDurumlari", "sosyobel");
        var questionTable = StoreObjectIdentifier.Table("HaneSorulari", "sosyobel");
        var optionTable = StoreObjectIdentifier.Table("HaneSoruSecenekleri", "sosyobel");

        Assert.Equal("Name", help?.FindProperty(nameof(HelpTypeReference.Name))
            ?.GetColumnName(helpTable));
        Assert.Equal("Ad", vital?.FindProperty(nameof(VitalStatusReference.Name))
            ?.GetColumnName(vitalTable));
        Assert.Equal("SiraNo", vital?.FindProperty(nameof(VitalStatusReference.Order))
            ?.GetColumnName(vitalTable));
        Assert.Equal("SoruMetni", question?.FindProperty(nameof(HouseholdQuestionReference.Label))
            ?.GetColumnName(questionTable));
        Assert.Equal("ZorunluMu", question?.FindProperty(nameof(HouseholdQuestionReference.IsRequired))
            ?.GetColumnName(questionTable));
        Assert.Equal("Etiket", option?.FindProperty(nameof(HouseholdQuestionOptionReference.Label))
            ?.GetColumnName(optionTable));
        Assert.Equal("Sira", option?.FindProperty(nameof(HouseholdQuestionOptionReference.Order))
            ?.GetColumnName(optionTable));
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

    [Fact]
    public void HouseholdPersistenceUsesSosyoBelExtensionTables()
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);

        var answer = context.Model.FindEntityType(typeof(ApplicationHouseholdAnswerRecord));
        var question = context.Model.FindEntityType(typeof(HouseholdQuestionReference));
        var option = context.Model.FindEntityType(typeof(HouseholdQuestionOptionReference));
        var answerTable = StoreObjectIdentifier.Table("BasvuruHaneCevaplari", "sosyobel");

        Assert.NotNull(answer);
        Assert.NotNull(question);
        Assert.NotNull(option);
        Assert.Equal("sosyobel", answer.GetSchema());
        Assert.Equal("sosyobel", question.GetSchema());
        Assert.Equal("sosyobel", option.GetSchema());
        Assert.Equal(
            "BasvuruId",
            answer.FindProperty(nameof(ApplicationHouseholdAnswerRecord.ApplicationId))
                ?.GetColumnName(answerTable));
        Assert.Equal(
            "SecenekId",
            answer.FindProperty(nameof(ApplicationHouseholdAnswerRecord.OptionId))
                ?.GetColumnName(answerTable));
        Assert.Null(answer.FindProperty("MunicipalityId"));
        Assert.Null(question.FindProperty("MunicipalityId"));
    }

    [Fact]
    public void PhotoPersistenceUsesApplicationScopedSosyoBelTable()
    {
        var options = new DbContextOptionsBuilder<SosyoBelDbContext>()
            .UseSqlServer("Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        using var context = new SosyoBelDbContext(options);
        var metadata = context.Model.FindEntityType(typeof(ApplicationPhotoRecord));
        var table = StoreObjectIdentifier.Table("BasvuruFotograflari", "sosyobel");

        Assert.NotNull(metadata);
        Assert.Equal("sosyobel", metadata.GetSchema());
        Assert.Equal(
            "BasvuruId",
            metadata.FindProperty(nameof(ApplicationPhotoRecord.ApplicationId))
                ?.GetColumnName(table));
        Assert.Equal(
            "SiraNo",
            metadata.FindProperty(nameof(ApplicationPhotoRecord.Order))
                ?.GetColumnName(table));
        Assert.Equal(
            "binary(32)",
            metadata.FindProperty(nameof(ApplicationPhotoRecord.Sha256))
                ?.GetColumnType(table));
        Assert.Null(metadata.FindProperty("MunicipalityId"));
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
