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
            entity.ToTable("BasvuruAileFertleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.SourceFamilyMemberId).HasColumnName("KaynakAileFerdiId");
            entity.Property(value => value.FullName).HasColumnName("AdSoyad").HasMaxLength(200);
            entity.Property(value => value.Age).HasColumnName("Yas");
            entity.Property(value => value.RelationshipId).HasColumnName("YakinlikId");
            entity.Property(value => value.OtherRelationshipDescription).HasColumnName("YakinlikDigerAciklama").HasMaxLength(100);
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.DisabilityDescription).HasColumnName("EngelAciklamasi").HasMaxLength(250);
            entity.Property(value => value.EmploymentStatusId).HasColumnName("CalismaDurumuId");
            entity.Property(value => value.EducationStatusId).HasColumnName("EgitimDurumuId");
            entity.Property(value => value.VitalStatusId).HasColumnName("YasamDurumuId");
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(128);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
        });

        builder.Entity<ApplicationHouseholdAnswerRecord>(entity =>
        {
            entity.ToTable("BasvuruHaneCevaplari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.QuestionId).HasColumnName("SoruId");
            entity.Property(value => value.OptionId).HasColumnName("SecenekId");
            entity.Property(value => value.TextAnswer).HasColumnName("SerbestMetinCevap").HasMaxLength(1000);
            entity.Property(value => value.NumericAnswer).HasColumnName("SayisalCevap");
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(128);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
        });

        builder.Entity<ApplicationPhotoRecord>(entity =>
        {
            entity.ToTable("BasvuruFotograflari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
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
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(128);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.DeletedByUserId).HasColumnName("SilenUserId").HasMaxLength(128);
            entity.Property(value => value.DeletedAtUtc).HasColumnName("SilinmeTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
        });
    }

    private static void ConfigureApplication(ModelBuilder builder)
    {
        builder.Entity<ApplicationRecord>(entity =>
        {
            entity.ToTable("Basvurular", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.PublicId).HasColumnName("PublicId");
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.ApplicationNumber).HasColumnName("BasvuruNo").HasMaxLength(40);
            entity.Property(value => value.IdentityNumber).HasColumnName("BasvuranTcKimlikNo").HasMaxLength(11).IsFixedLength();
            entity.Property(value => value.ApplicantFirstName).HasColumnName("BasvuranAd").HasMaxLength(100);
            entity.Property(value => value.ApplicantLastName).HasColumnName("BasvuranSoyad").HasMaxLength(100);
            entity.Property(value => value.BirthDate).HasColumnName("BasvuranDogumTarihi");
            entity.Property(value => value.PhoneNumber).HasColumnName("BasvuranTelefon").HasMaxLength(16).IsUnicode(false);
            entity.Property(value => value.Address).HasColumnName("BasvuruAcikAdres").HasMaxLength(500);
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityRate).HasColumnName("EngelOrani");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.HelpTypeId).HasColumnName("YardimTuruId");
            entity.Property(value => value.RequestChannelId).HasColumnName("TalepGelisKanaliId");
            entity.Property(value => value.Description).HasColumnName("TalepAciklamasi").HasMaxLength(1000);
            entity.Property(value => value.FieldInspectionNote).HasColumnName("SahaIncelemeNotu").HasMaxLength(2000);
            entity.Property(value => value.StatusId).HasColumnName("BasvuruDurumuId");
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(128);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.UpdatedByUserId).HasColumnName("GuncelleyenUserId").HasMaxLength(128);
            entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
            entity.Property(value => value.SubmittedByUserId).HasColumnName("KurulaGonderenUserId").HasMaxLength(128);
            entity.Property(value => value.SubmittedAtUtc).HasColumnName("KurulaGonderilmeTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
            entity.HasIndex(value => value.PublicId).IsUnique();
        });
    }

    private static void ConfigureReferences(ModelBuilder builder)
    {
        builder.Entity<ApplicationStatusReference>(entity =>
        {
            entity.ToTable("BasvuruDurumlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<HelpTypeReference>(entity =>
        {
            entity.ToTable("YardimTurleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<DisabilityTypeReference>(entity =>
        {
            entity.ToTable("EngelTurleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<RequestChannelReference>(entity =>
        {
            entity.ToTable("TalepGelisKanallari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<RelationshipReference>(entity =>
        {
            entity.ToTable("Yakinliklar", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<EmploymentStatusReference>(entity =>
        {
            entity.ToTable("CalismaDurumlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<EducationStatusReference>(entity =>
        {
            entity.ToTable("EgitimDurumlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<VitalStatusReference>(entity =>
        {
            entity.ToTable("YasamDurumlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<HouseholdQuestionReference>(entity =>
        {
            entity.ToTable("HaneSorulari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(80);
            entity.Property(value => value.AnswerTypeCode).HasColumnName("CevapTipi").HasMaxLength(30);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
        builder.Entity<HouseholdQuestionOptionReference>(entity =>
        {
            entity.ToTable("HaneSoruSecenekleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.QuestionId).HasColumnName("SoruId");
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(80);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        });
    }

    private static void ConfigureStatusHistory(ModelBuilder builder)
    {
        builder.Entity<ApplicationStatusHistoryRecord>(entity =>
        {
            entity.ToTable("BasvuruDurumGecmisi", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.PreviousStatusId).HasColumnName("OncekiDurumId");
            entity.Property(value => value.NewStatusId).HasColumnName("YeniDurumId");
            entity.Property(value => value.Description).HasColumnName("Aciklama").HasMaxLength(1000);
            entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(128);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
        });
    }

    private static void ConfigureIdempotency(ModelBuilder builder)
    {
        builder.Entity<IdempotencyRecord>(entity =>
        {
            entity.ToTable("IdempotencyKayitlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ActorUserId).HasColumnName("ActorUserId").HasMaxLength(128);
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
                value.ActorUserId,
                value.EndpointCode,
                value.IdempotencyKey,
            }).IsUnique();
        });
    }
}
