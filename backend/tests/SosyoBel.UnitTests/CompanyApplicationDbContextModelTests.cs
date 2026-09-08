using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class CompanyApplicationDbContextModelTests
{
    [Fact]
    public void ModelUsesOnlyExistingCompanyDboTablesAndExcludesThemFromMigrations()
    {
        using var context = CreateContext();
        // EF Core çalışma modeli migration annotationlarını performans için atar.
        // Şirket tablolarının migration dışında kaldığını tasarım modelinden doğrularız.
        var designTimeModel = context.GetService<IDesignTimeModel>().Model;
        var entityTypes = designTimeModel.GetEntityTypes().ToArray();

        Assert.Equal(
            [
                "BasvuruAileFertleri",
                "BasvuruDurumlari",
                "BasvuruHaneCevaplari",
                "Basvurular",
                "CalismaDurumlari",
                "EgitimDurumlari",
                "EngelTurleri",
                "HaneFotograflari",
                "Mahalleler",
                "Sokaklar",
                "TalepGelisKanallari",
                "Vatandaslar",
                "Yakinliklar",
                "YardimTurleri",
            ],
            entityTypes
                .Select(entity => entity.GetTableName()!)
                .Order(StringComparer.Ordinal)
                .ToArray());
        Assert.All(entityTypes, entity =>
        {
            Assert.Equal("dbo", entity.GetSchema());
            Assert.True(entity.IsTableExcludedFromMigrations());
        });
    }

    [Fact]
    public void CitizenColumnsMatchCompanySnapshotExactly()
    {
        using var context = CreateContext();

        AssertColumns(
            context,
            typeof(CompanyCitizenRecord),
            "Vatandaslar",
            [
                "AcikAdres", "Ad", "AdresNo", "CalismaDurumuId", "Cinsiyet",
                "CocukSayisi", "DogumTarihi", "DogumYeri", "EgitimDurumuId",
                "Email", "EngelDurumu", "EngelOrani", "EngelTuruId", "Id",
                "IlKodu", "IlceKodu", "KayitTarihi", "KpsMahalle", "KpsSokak",
                "MahalleId", "MahalleKodu", "MedeniDurumId", "OlusturanUserId",
                "Sil", "SokakId", "SokakKodu", "Soyad", "TcKimlikNo",
                "Telefon1", "Telefon2",
            ]);
    }

    [Fact]
    public void ApplicationColumnsMatchCompanySnapshotExactly()
    {
        using var context = CreateContext();

        AssertColumns(
            context,
            typeof(CompanyApplicationRecord),
            "Basvurular",
            [
                "AdresNo", "BasvuranAd", "BasvuranCinsiyet",
                "BasvuranDogumTarihi", "BasvuranDogumYeri", "BasvuranMedeniHal",
                "BasvuranSoyad", "BasvuranTcKimlikNo", "BasvuranTelefon",
                "BasvuruAcikAdres", "BasvuruDurumuId", "BasvuruMahalle",
                "BasvuruSokak", "BasvuruTarihi", "EngelDurumu", "EngelOrani",
                "EngelTuruId", "HaneFotografYolu", "Id", "IlKodu", "IlceKodu",
                "IptalAciklamasi", "IptalTarihi", "MahalleId", "MahalleKodu",
                "OlusturanUserId", "PublicToken", "SokakId", "SokakKodu",
                "TalepAciklamasi", "TalepGelisKanaliId", "VatandasId",
                "YardimTuruId",
            ]);
    }

    [Fact]
    public void ApplicationHouseholdAnswerColumnsMatchCompanySnapshotExactly()
    {
        using var context = CreateContext();

        AssertColumns(
            context,
            typeof(CompanyApplicationHouseholdAnswerRecord),
            "BasvuruHaneCevaplari",
            ["BasvuruId", "Id", "SecenekKodu", "SoruKodu"]);
    }

    [Fact]
    public void ApplicationFamilyColumnsMatchCompanySnapshotExactly()
    {
        using var context = CreateContext();

        AssertColumns(
            context,
            typeof(CompanyApplicationFamilyMemberRecord),
            "BasvuruAileFertleri",
            [
                "AdSoyad", "BasvuruId", "CalismaDurumuId", "EgitimDurumuId",
                "EngelDurumu", "EngelTuruId", "Id", "YakinlikId", "Yas",
            ]);
    }

    [Fact]
    public void HouseholdPhotoColumnsMatchCompanySnapshotExactly()
    {
        using var context = CreateContext();

        AssertColumns(
            context,
            typeof(CompanyHouseholdPhotoRecord),
            "HaneFotograflari",
            ["Aciklama", "FotografYolu", "Id", "VatandasId", "YuklenmeTarihi"]);
    }

    [Fact]
    public void KeyLengthsAndNullabilityMatchCompanySnapshot()
    {
        using var context = CreateContext();
        var citizen = context.Model.FindEntityType(typeof(CompanyCitizenRecord))!;
        var application = context.Model.FindEntityType(typeof(CompanyApplicationRecord))!;
        var family = context.Model.FindEntityType(
            typeof(CompanyApplicationFamilyMemberRecord))!;
        var householdAnswer = context.Model.FindEntityType(
            typeof(CompanyApplicationHouseholdAnswerRecord))!;
        var photo = context.Model.FindEntityType(
            typeof(CompanyHouseholdPhotoRecord))!;

        Assert.Equal(11, citizen.FindProperty(
            nameof(CompanyCitizenRecord.IdentityNumber))!.GetMaxLength());
        Assert.False(citizen.FindProperty(
            nameof(CompanyCitizenRecord.IdentityNumber))!.IsNullable);
        Assert.True(application.FindProperty(
            nameof(CompanyApplicationRecord.CitizenId))!.IsNullable);
        Assert.Equal(11, application.FindProperty(
            nameof(CompanyApplicationRecord.ApplicantIdentityNumber))!.GetMaxLength());
        Assert.Equal(32, application.FindProperty(
            nameof(CompanyApplicationRecord.PublicToken))!.GetMaxLength());
        Assert.False(application.FindProperty(
            nameof(CompanyApplicationRecord.PublicToken))!.IsNullable);
        Assert.False(family.FindProperty(
            nameof(CompanyApplicationFamilyMemberRecord.ApplicationId))!.IsNullable);
        Assert.False(householdAnswer.FindProperty(
            nameof(CompanyApplicationHouseholdAnswerRecord.ApplicationId))!.IsNullable);
        Assert.Equal(80, householdAnswer.FindProperty(
            nameof(CompanyApplicationHouseholdAnswerRecord.QuestionCode))!.GetMaxLength());
        Assert.False(householdAnswer.FindProperty(
            nameof(CompanyApplicationHouseholdAnswerRecord.QuestionCode))!.IsNullable);
        Assert.Equal(80, householdAnswer.FindProperty(
            nameof(CompanyApplicationHouseholdAnswerRecord.OptionCode))!.GetMaxLength());
        Assert.False(householdAnswer.FindProperty(
            nameof(CompanyApplicationHouseholdAnswerRecord.OptionCode))!.IsNullable);
        Assert.False(photo.FindProperty(
            nameof(CompanyHouseholdPhotoRecord.CitizenId))!.IsNullable);
        Assert.False(photo.FindProperty(
            nameof(CompanyHouseholdPhotoRecord.PhotoPath))!.IsNullable);
    }

    [Fact]
    public void CoreForeignKeysUseExistingCompanyRecordsWithoutCascadeDelete()
    {
        using var context = CreateContext();

        AssertForeignKey<CompanyApplicationRecord, CompanyCitizenRecord>(
            context,
            nameof(CompanyApplicationRecord.CitizenId));
        AssertForeignKey<CompanyApplicationFamilyMemberRecord, CompanyApplicationRecord>(
            context,
            nameof(CompanyApplicationFamilyMemberRecord.ApplicationId));
        AssertForeignKey<CompanyApplicationHouseholdAnswerRecord, CompanyApplicationRecord>(
            context,
            nameof(CompanyApplicationHouseholdAnswerRecord.ApplicationId));
        AssertForeignKey<CompanyApplicationFamilyMemberRecord, RelationshipReference>(
            context,
            nameof(CompanyApplicationFamilyMemberRecord.RelationshipId));
        AssertForeignKey<CompanyHouseholdPhotoRecord, CompanyCitizenRecord>(
            context,
            nameof(CompanyHouseholdPhotoRecord.CitizenId),
            DeleteBehavior.Cascade);
    }

    [Fact]
    public void HouseholdAnswerHasUniqueApplicationQuestionIndex()
    {
        using var context = CreateContext();
        var householdAnswer = context.Model.FindEntityType(
            typeof(CompanyApplicationHouseholdAnswerRecord))!;
        var index = Assert.Single(
            householdAnswer.GetIndexes(),
            value => value.Properties.Select(property => property.Name).SequenceEqual(
                [
                    nameof(CompanyApplicationHouseholdAnswerRecord.ApplicationId),
                    nameof(CompanyApplicationHouseholdAnswerRecord.QuestionCode),
                ]));

        Assert.True(index.IsUnique);
        Assert.Equal(
            "UQ_BasvuruHaneCevaplari_BasvuruId_SoruKodu",
            index.GetDatabaseName());
    }

    private static CompanyApplicationDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<CompanyApplicationDbContext>()
            .UseSqlServer(
                "Server=unused;Database=unused;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        return new CompanyApplicationDbContext(options);
    }

    private static void AssertColumns(
        DbContext context,
        Type entityType,
        string tableName,
        IReadOnlyCollection<string> expectedColumns)
    {
        var metadata = context.Model.FindEntityType(entityType);
        Assert.NotNull(metadata);
        var table = StoreObjectIdentifier.Table(tableName, "dbo");
        var actualColumns = metadata.GetProperties()
            .Select(property => property.GetColumnName(table)!)
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Equal(
            expectedColumns.Order(StringComparer.Ordinal).ToArray(),
            actualColumns);
    }

    private static void AssertForeignKey<TDependent, TPrincipal>(
        DbContext context,
        string foreignKeyProperty,
        DeleteBehavior expectedDeleteBehavior = DeleteBehavior.NoAction)
    {
        var dependent = context.Model.FindEntityType(typeof(TDependent));
        Assert.NotNull(dependent);
        var foreignKey = Assert.Single(
            dependent.GetForeignKeys(),
            key =>
                key.PrincipalEntityType.ClrType == typeof(TPrincipal) &&
                key.Properties.Any(property => property.Name == foreignKeyProperty));

        Assert.Equal(expectedDeleteBehavior, foreignKey.DeleteBehavior);
    }
}
