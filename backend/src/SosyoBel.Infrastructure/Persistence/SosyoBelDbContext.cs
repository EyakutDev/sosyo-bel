using Microsoft.EntityFrameworkCore;
using SosyoBel.Domain.Municipalities;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Yalnız V2 `sosyobel` şemasına bağlanır. Eski dbo iş tablolarının yanlışlıkla
/// API modeline dâhil edilmesini engellemek için eşlemeler açıkça tanımlanır.
/// </summary>
public sealed class SosyoBelDbContext(DbContextOptions<SosyoBelDbContext> options)
    : DbContext(options)
{
    public DbSet<Municipality> Municipalities => Set<Municipality>();

    public DbSet<MunicipalityIntegration> MunicipalityIntegrations =>
        Set<MunicipalityIntegration>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        ConfigureMunicipality(modelBuilder.Entity<Municipality>());
        ConfigureMunicipalityIntegration(modelBuilder.Entity<MunicipalityIntegration>());
        ApplicationPersistenceModelConfiguration.Configure(modelBuilder);
    }

    private static void ConfigureMunicipality(
        Microsoft.EntityFrameworkCore.Metadata.Builders.EntityTypeBuilder<Municipality> entity)
    {
        entity.ToTable("Belediyeler", "sosyobel");
        entity.HasKey(value => value.Id);
        entity.Property(value => value.PublicId).HasColumnName("PublicId");
        entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
        entity.Property(value => value.Name).HasColumnName("Ad").HasMaxLength(200);
        entity.Property(value => value.LogoStorageKey).HasColumnName("LogoStorageKey").HasMaxLength(500);
        entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
        entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
        entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
        entity.HasIndex(value => value.PublicId).IsUnique();
        entity.HasIndex(value => value.Code).IsUnique();
    }

    private static void ConfigureMunicipalityIntegration(
        Microsoft.EntityFrameworkCore.Metadata.Builders.EntityTypeBuilder<MunicipalityIntegration> entity)
    {
        entity.ToTable("BelediyeEntegrasyonlari", "sosyobel");
        entity.HasKey(value => value.Id);
        entity.Property(value => value.PublicId).HasColumnName("PublicId");
        entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
        entity.Property(value => value.Name).HasColumnName("Ad").HasMaxLength(150);
        entity.Property(value => value.Type)
            .HasColumnName("EntegrasyonTuruKodu")
            .HasMaxLength(30)
            .HasConversion(
                value => MunicipalityIntegrationCodes.ToCode(value),
                value => MunicipalityIntegrationCodes.ParseType(value));
        entity.Property(value => value.AccessScope)
            .HasColumnName("YetkiKapsamiKodu")
            .HasMaxLength(30)
            .HasConversion(
                value => MunicipalityIntegrationCodes.ToCode(value),
                value => MunicipalityIntegrationCodes.ParseAccessScope(value));
        entity.Property(value => value.AuthenticationType)
            .HasColumnName("KimlikDogrulamaTuruKodu")
            .HasMaxLength(30)
            .HasConversion(
                value => MunicipalityIntegrationCodes.ToCode(value),
                value => MunicipalityIntegrationCodes.ParseAuthenticationType(value));
        entity.Property(value => value.ServerAddress).HasColumnName("SunucuAdresi").HasMaxLength(255);
        entity.Property(value => value.Port).HasColumnName("Port");
        entity.Property(value => value.DatabaseName).HasColumnName("VeritabaniAdi").HasMaxLength(128);
        entity.Property(value => value.ApiBaseUrl).HasColumnName("ApiBaseUrl").HasMaxLength(500);
        entity.Property(value => value.SecretReference).HasColumnName("SecretReference").HasMaxLength(300);
        entity.Property(value => value.AdditionalSettingsJson).HasColumnName("EkAyarlarJson");
        entity.Property(value => value.ConnectionTimeoutSeconds)
            .HasColumnName("BaglantiZamanAsimiSaniye");
        entity.Property(value => value.RetryCount).HasColumnName("YenidenDenemeSayisi");
        entity.Property(value => value.IsActive).HasColumnName("AktifMi");
        entity.Property(value => value.LastSuccessfulConnectionUtc)
            .HasColumnName("SonBasariliBaglantiUtc");
        entity.Property(value => value.LastErrorCode).HasColumnName("SonHataKodu").HasMaxLength(100);
        entity.Property(value => value.CreatedByUserId).HasColumnName("OlusturanUserId").HasMaxLength(128);
        entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
        entity.Property(value => value.UpdatedByUserId).HasColumnName("GuncelleyenUserId").HasMaxLength(128);
        entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
        entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();

        entity.HasIndex(value => value.PublicId).IsUnique();
        entity.HasIndex(value => new { value.MunicipalityId, value.Name }).IsUnique();
        entity.HasOne<Municipality>()
            .WithMany()
            .HasForeignKey(value => value.MunicipalityId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
