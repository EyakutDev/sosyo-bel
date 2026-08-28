using Microsoft.EntityFrameworkCore;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.Infrastructure.Persistence;

internal static class ApplicationPersistenceModelConfiguration
{
    public static void Configure(ModelBuilder builder)
    {
        ConfigureApplication(builder);
        ConfigureFieldData(builder);
        ConfigureReferences(builder);
        ConfigureStatusHistory(builder);
        ConfigureIdempotency(builder);
    }

    private static void ConfigureFieldData(ModelBuilder builder)
    {
        builder.Entity<ApplicationFamilyMemberRecord>(entity =>
        {
            // Sirketin basvuru anindaki aile tablosu ana kayittir. Mobil API'ye
            // ozel yasam durumu ve audit alanlari bire bir uzantiya ayrilir.
            entity.ToTable(
                "BasvuruAileFertleri",
                "dbo",
                table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.FullName)
                .HasColumnName("AdSoyad")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.Age).HasColumnName("Yas").HasColumnType("int");
            entity.Property(value => value.RelationshipId).HasColumnName("YakinlikId");
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.EmploymentStatusId).HasColumnName("CalismaDurumuId");
            entity.Property(value => value.EducationStatusId).HasColumnName("EgitimDurumuId");
            entity.Property(value => value.RowVersion).IsRowVersion();

            entity.SplitToTable(
                "BasvuruAileFertiUygulamaBilgileri",
                "sosyobel",
                split =>
                {
                    split.Property(value => value.Id).HasColumnName("BasvuruAileFertiId");
                    split.Property(value => value.OtherRelationshipDescription)
                        .HasColumnName("YakinlikDigerAciklama");
                    split.Property(value => value.DisabilityDescription)
                        .HasColumnName("EngelAciklamasi");
                    split.Property(value => value.VitalStatusId).HasColumnName("YasamDurumuId");
                    split.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId");
                    split.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
                    split.Property(value => value.RowVersion).HasColumnName("RowVersion");
                });

            entity.Property(value => value.OtherRelationshipDescription).HasMaxLength(100);
            entity.Property(value => value.DisabilityDescription).HasMaxLength(250);
            entity.Property(value => value.CreatedByUserId).HasMaxLength(450);
        });

        builder.Entity<ApplicationHouseholdAnswerRecord>(entity =>
        {
            entity.ToTable("BasvuruHaneCevaplari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.QuestionId).HasColumnName("SoruId");
            entity.Property(value => value.OptionId).HasColumnName("SecenekId");
            entity.Property(value => value.TextAnswer).HasColumnName("SerbestMetinCevap").HasMaxLength(1000);
            entity.Property(value => value.NumericAnswer)
                .HasColumnName("SayisalCevap")
                .HasPrecision(18, 2);
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(450);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
        });

        builder.Entity<ApplicationPhotoRecord>(entity =>
        {
            entity.ToTable("BasvuruFotograflari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.StorageKey).HasColumnName("StorageKey").HasMaxLength(500);
            entity.Property(value => value.OriginalFileName).HasColumnName("OrijinalDosyaAdi").HasMaxLength(255);
            entity.Property(value => value.ContentType).HasColumnName("MimeType").HasMaxLength(100).IsUnicode(false);
            entity.Property(value => value.Length).HasColumnName("BoyutByte");
            entity.Property(value => value.Sha256).HasColumnName("Sha256").HasColumnType("binary(32)");
            entity.Property(value => value.Order).HasColumnName("SiraNo");
            entity.Property(value => value.ScanStatusCode).HasColumnName("TaramaDurumuKodu").HasMaxLength(30);
            entity.Property(value => value.ExifRemoved).HasColumnName("ExifTemizlendiMi");
            entity.Property(value => value.IsDeleted).HasColumnName("SilindiMi");
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(450);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.DeletedByUserId).HasColumnName("SilenUserId").HasMaxLength(450);
            entity.Property(value => value.DeletedAtUtc).HasColumnName("SilinmeTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
        });
    }

    private static void ConfigureApplication(ModelBuilder builder)
    {
        builder.Entity<ApplicationRecord>(entity =>
        {
            // İş verisi şirketin mevcut tablosunda kalır. API'ye özgü alanlar aynı
            // entity'nin bire bir sosyobel uzantısına bölünür; dbo tablosu değiştirilmez.
            entity.ToTable("Basvurular", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.IdentityNumber).HasColumnName("BasvuranTcKimlikNo").HasMaxLength(11).IsFixedLength();
            entity.Property(value => value.ApplicantFirstName).HasColumnName("BasvuranAd").HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicantLastName).HasColumnName("BasvuranSoyad").HasColumnType("nvarchar(max)");
            entity.Property(value => value.BirthDateStorage).HasColumnName("BasvuranDogumTarihi").HasColumnType("nvarchar(max)");
            entity.Ignore(value => value.BirthDate);
            entity.Property(value => value.PhoneNumber).HasColumnName("BasvuranTelefon").HasColumnType("nvarchar(max)");
            entity.Property(value => value.Address).HasColumnName("BasvuruAcikAdres").HasColumnType("nvarchar(max)");
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityRate).HasColumnName("EngelOrani").HasColumnType("int");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.HelpTypeId).HasColumnName("YardimTuruId");
            entity.Property(value => value.RequestChannelId).HasColumnName("TalepGelisKanaliId");
            entity.Property(value => value.Description).HasColumnName("TalepAciklamasi").HasColumnType("nvarchar(max)");
            entity.Property(value => value.StatusId).HasColumnName("BasvuruDurumuId");
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(450);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("BasvuruTarihi");
            entity.Property(value => value.RowVersion).IsRowVersion();

            entity.SplitToTable(
                "BasvuruUygulamaBilgileri",
                "sosyobel",
                split =>
                {
                    split.Property(value => value.Id).HasColumnName("BasvuruId");
                    split.Property(value => value.PublicId).HasColumnName("PublicId");
                    split.Property(value => value.ApplicationNumber).HasColumnName("BasvuruNo");
                    split.Property(value => value.FieldInspectionNote).HasColumnName("SahaIncelemeNotu");
                    split.Property(value => value.UpdatedByUserId).HasColumnName("GuncelleyenUserId");
                    split.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
                    split.Property(value => value.SubmittedByUserId).HasColumnName("KurulaGonderenUserId");
                    split.Property(value => value.SubmittedAtUtc).HasColumnName("KurulaGonderilmeTarihiUtc");
                    split.Property(value => value.RowVersion).HasColumnName("RowVersion");
                });

            entity.Property(value => value.ApplicationNumber).HasMaxLength(40).IsRequired(false);
            entity.Property(value => value.FieldInspectionNote).HasMaxLength(2000);
            entity.Property(value => value.UpdatedByUserId).HasMaxLength(450);
            entity.Property(value => value.SubmittedByUserId).HasMaxLength(450);
            entity.HasIndex(value => value.PublicId).IsUnique();
        });
    }

    private static void ConfigureReferences(ModelBuilder builder)
    {
        builder.Entity<ApplicationStatusReference>(entity =>
        {
            entity.ToTable("BasvuruDurumlari", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<HelpTypeReference>(entity =>
        {
            entity.ToTable("YardimTurleri", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<DisabilityTypeReference>(entity =>
        {
            entity.ToTable("EngelTurleri", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<RequestChannelReference>(entity =>
        {
            entity.ToTable("TalepGelisKanallari", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<RelationshipReference>(entity =>
        {
            entity.ToTable("Yakinliklar", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<EmploymentStatusReference>(entity =>
        {
            entity.ToTable("CalismaDurumlari", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<EducationStatusReference>(entity =>
        {
            entity.ToTable("EgitimDurumlari", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Name).HasColumnName("Name");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
        builder.Entity<VitalStatusReference>(entity =>
        {
            entity.ToTable("YasamDurumlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.Name).HasColumnName("Ad").HasMaxLength(100);
            entity.Property(value => value.Order).HasColumnName("SiraNo");
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<HouseholdQuestionReference>(entity =>
        {
            entity.ToTable("HaneSorulari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(80);
            entity.Property(value => value.Label).HasColumnName("SoruMetni").HasMaxLength(300);
            entity.Property(value => value.AnswerTypeCode).HasColumnName("CevapTipi").HasMaxLength(30);
            entity.Property(value => value.IsRequired).HasColumnName("ZorunluMu");
            entity.Property(value => value.Order).HasColumnName("Sira");
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<HouseholdQuestionOptionReference>(entity =>
        {
            entity.ToTable("HaneSoruSecenekleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.QuestionId).HasColumnName("SoruId");
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(80);
            entity.Property(value => value.Label).HasColumnName("Etiket").HasMaxLength(200);
            entity.Property(value => value.Order).HasColumnName("Sira");
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
    }

    private static void ConfigureStatusHistory(ModelBuilder builder)
    {
        builder.Entity<ApplicationStatusHistoryRecord>(entity =>
        {
            entity.ToTable("BasvuruDurumGecmisi", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.PreviousStatusId).HasColumnName("OncekiDurumId");
            entity.Property(value => value.NewStatusId).HasColumnName("YeniDurumId");
            entity.Property(value => value.Description).HasColumnName("Aciklama").HasMaxLength(1000);
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(450);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
        });
    }

    private static void ConfigureIdempotency(ModelBuilder builder)
    {
        builder.Entity<IdempotencyRecord>(entity =>
        {
            entity.ToTable("IdempotencyKayitlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ActorUserId).HasColumnName("ActorUserId").HasMaxLength(450);
            entity.Property(value => value.ActorUserIdHash)
                .HasColumnName("ActorUserIdHash")
                .HasColumnType("binary(32)");
            entity.Property(value => value.EndpointCode).HasColumnName("EndpointKodu").HasMaxLength(150);
            entity.Property(value => value.IdempotencyKey).HasColumnName("IdempotencyKey").HasMaxLength(100);
            entity.Property(value => value.RequestHash).HasColumnName("IstekHash").HasColumnType("binary(32)");
            entity.Property(value => value.HttpStatusCode).HasColumnName("HttpDurumKodu");
            entity.Property(value => value.ResultJson).HasColumnName("SonucJson");
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.ExpiresAtUtc).HasColumnName("SonKullanmaTarihiUtc");
            entity.Ignore(value => value.IsCompleted);
            entity.HasIndex(value => new
            {
                value.ActorUserIdHash,
                value.EndpointCode,
                value.IdempotencyKey,
            }).IsUnique();
            entity.HasIndex(value => new { value.ActorUserId, value.EndpointCode });
        });
    }
}
