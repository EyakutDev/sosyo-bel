using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Identity tabloları ile kullanıcı/belediye, yetki, audit, idempotency ve refresh
/// token kayıtlarını aynı transaction sınırında yönetir.
/// </summary>
internal sealed class AuthenticationDbContext(
    DbContextOptions<AuthenticationDbContext> options)
    : IdentityDbContext<ApplicationUser, IdentityRole, string>(options)
{
    public DbSet<IdentityMunicipalityRecord> Municipalities =>
        Set<IdentityMunicipalityRecord>();

    public DbSet<UserApplicationInfo> UserApplicationInfos =>
        Set<UserApplicationInfo>();

    public DbSet<UserMunicipalityMembership> UserMunicipalities =>
        Set<UserMunicipalityMembership>();

    public DbSet<UserPermissionRecord> UserPermissions => Set<UserPermissionRecord>();

    public DbSet<AdministrationAuditRecord> AdministrationAudit =>
        Set<AdministrationAuditRecord>();

    public DbSet<IdempotencyRecord> IdempotencyRecords => Set<IdempotencyRecord>();

    public DbSet<RefreshTokenRecord> RefreshTokens => Set<RefreshTokenRecord>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        ConfigureIdentityKeyLengths(builder);
        ConfigureApplicationUser(builder);
        ConfigureUserApplicationInfo(builder);
        ConfigureMunicipality(builder);
        ConfigureMembership(builder);
        ConfigurePermission(builder);
        ConfigureAdministrationAudit(builder);
        ConfigureIdempotency(builder);
        ConfigureRefreshToken(builder);
    }

    private static void ConfigureIdentityKeyLengths(ModelBuilder builder)
    {
        builder.Entity<IdentityRole>(entity =>
            entity.Property(role => role.Id).HasMaxLength(450));
        builder.Entity<IdentityRoleClaim<string>>(entity =>
            entity.Property(claim => claim.RoleId).HasMaxLength(450));
        builder.Entity<IdentityUserClaim<string>>(entity =>
            entity.Property(claim => claim.UserId).HasMaxLength(450));
        builder.Entity<IdentityUserLogin<string>>(entity =>
        {
            entity.Property(login => login.LoginProvider).HasMaxLength(450);
            entity.Property(login => login.ProviderKey).HasMaxLength(450);
            entity.Property(login => login.UserId).HasMaxLength(450);
        });
        builder.Entity<IdentityUserRole<string>>(entity =>
        {
            entity.Property(role => role.UserId).HasMaxLength(450);
            entity.Property(role => role.RoleId).HasMaxLength(450);
        });
        builder.Entity<IdentityUserToken<string>>(entity =>
        {
            entity.Property(token => token.UserId).HasMaxLength(450);
            entity.Property(token => token.LoginProvider).HasMaxLength(450);
            entity.Property(token => token.Name).HasMaxLength(450);
        });
    }

    private static void ConfigureApplicationUser(ModelBuilder builder)
    {
        builder.Entity<ApplicationUser>(entity =>
        {
            entity.Property(user => user.Id).HasMaxLength(450);
            entity.Property(user => user.FirstName).HasColumnName("Ad").HasMaxLength(100);
            entity.Property(user => user.LastName).HasColumnName("Soyad").HasMaxLength(100);
            entity.Ignore(user => user.DisplayName);
            entity.Ignore(user => user.IsActive);
            entity.Ignore(user => user.CreatedAtUtc);
            entity.Ignore(user => user.UpdatedAtUtc);
            entity.Ignore(user => user.CreatedByUserId);
            entity.Ignore(user => user.DeactivatedByUserId);
            entity.Ignore(user => user.DeactivatedAtUtc);
            entity.Ignore(user => user.DeactivationReason);
            entity.Ignore(user => user.RowVersion);

            entity.HasOne(user => user.ApplicationInfo)
                .WithOne()
                .HasForeignKey<UserApplicationInfo>(value => value.UserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.Navigation(user => user.ApplicationInfo).AutoInclude();
        });
    }

    private static void ConfigureUserApplicationInfo(ModelBuilder builder)
    {
        builder.Entity<UserApplicationInfo>(entity =>
        {
            entity.ToTable("KullaniciUygulamaBilgileri", "sosyobel");
            entity.HasKey(value => value.UserId);
            entity.Property(value => value.UserId).HasColumnName("UserId").HasMaxLength(450);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
            entity.Property(value => value.CreatedByUserId)
                .HasColumnName("OlusturanUserId")
                .HasMaxLength(450);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.UpdatedByUserId)
                .HasColumnName("GuncelleyenUserId")
                .HasMaxLength(450);
            entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
            entity.Property(value => value.DeactivatedByUserId)
                .HasColumnName("DevreDisiBirakanUserId")
                .HasMaxLength(450);
            entity.Property(value => value.DeactivatedAtUtc)
                .HasColumnName("DevreDisiTarihiUtc");
            entity.Property(value => value.DeactivationReason)
                .HasColumnName("DevreDisiGerekce")
                .HasMaxLength(1000);
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();

            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.UpdatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.DeactivatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static void ConfigureMunicipality(ModelBuilder builder)
    {
        builder.Entity<IdentityMunicipalityRecord>(entity =>
        {
            entity.ToTable("Belediyeler", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.PublicId).HasColumnName("PublicId");
            entity.Property(value => value.Code).HasColumnName("Kod").HasMaxLength(50);
            entity.Property(value => value.Name).HasColumnName("Ad").HasMaxLength(200);
            entity.Property(value => value.LogoStorageKey)
                .HasColumnName("LogoStorageKey")
                .HasMaxLength(500);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.UpdatedAtUtc).HasColumnName("GuncellenmeTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
            entity.HasIndex(value => value.PublicId).IsUnique();
            entity.HasIndex(value => value.Code).IsUnique();
        });
    }

    private static void ConfigureMembership(ModelBuilder builder)
    {
        builder.Entity<UserMunicipalityMembership>(entity =>
        {
            entity.ToTable("KullaniciBelediyeleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.UserId).HasColumnName("UserId").HasMaxLength(450);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.RoleCode).HasColumnName("RolKodu").HasMaxLength(50);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.HasAlternateKey(value => new { value.UserId, value.MunicipalityId })
                .HasName("UQ_KullaniciBelediyeleri_User_Belediye");
            entity.HasIndex(value => new
            {
                value.MunicipalityId,
                value.RoleCode,
                value.IsActive,
            });
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.UserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<IdentityMunicipalityRecord>()
                .WithMany()
                .HasForeignKey(value => value.MunicipalityId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static void ConfigurePermission(ModelBuilder builder)
    {
        builder.Entity<UserPermissionRecord>(entity =>
        {
            entity.ToTable("KullaniciYetkileri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.UserId).HasColumnName("UserId").HasMaxLength(450);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.PermissionCode)
                .HasColumnName("YetkiKodu")
                .HasMaxLength(80);
            entity.Property(value => value.IsActive).HasColumnName("AktifMi");
            entity.Property(value => value.GrantedByUserId)
                .HasColumnName("VerenUserId")
                .HasMaxLength(450);
            entity.Property(value => value.GrantedAtUtc).HasColumnName("VerilmeTarihiUtc");
            entity.Property(value => value.RevokedByUserId)
                .HasColumnName("IptalEdenUserId")
                .HasMaxLength(450);
            entity.Property(value => value.RevokedAtUtc).HasColumnName("IptalTarihiUtc");
            entity.Property(value => value.RowVersion).HasColumnName("RowVersion").IsRowVersion();
            entity.HasIndex(value => new
            {
                value.UserId,
                value.MunicipalityId,
                value.PermissionCode,
            }).IsUnique();
            entity.HasOne<UserMunicipalityMembership>()
                .WithMany()
                .HasForeignKey(value => new { value.UserId, value.MunicipalityId })
                .HasPrincipalKey(value => new { value.UserId, value.MunicipalityId })
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.GrantedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.RevokedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static void ConfigureAdministrationAudit(ModelBuilder builder)
    {
        builder.Entity<AdministrationAuditRecord>(entity =>
        {
            entity.ToTable("IslemGecmisleri", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.MunicipalityId).HasColumnName("BelediyeId");
            entity.Property(value => value.EntityType)
                .HasColumnName("VarlikTuru")
                .HasMaxLength(100);
            entity.Property(value => value.EntityPublicId).HasColumnName("VarlikPublicId");
            entity.Property(value => value.OperationCode)
                .HasColumnName("IslemKodu")
                .HasMaxLength(100);
            entity.Property(value => value.Description)
                .HasColumnName("Aciklama")
                .HasMaxLength(1000);
            entity.Property(value => value.ChangeSummaryJson)
                .HasColumnName("DegisiklikOzetiJson");
            entity.Property(value => value.ActorUserId)
                .HasColumnName("OlusturanUserId")
                .HasMaxLength(450);
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.Reason).HasColumnName("Gerekce").HasMaxLength(1000);
            entity.Property(value => value.ActorIp)
                .HasColumnName("OlusturanIp")
                .HasColumnType("varchar(45)");
            entity.Property(value => value.DeviceId)
                .HasColumnName("CihazKimligi")
                .HasMaxLength(200);
            entity.Property(value => value.CorrelationId).HasColumnName("CorrelationId");
            entity.Property(value => value.TargetUserId)
                .HasColumnName("HedefUserId")
                .HasMaxLength(450);
            entity.HasOne<IdentityMunicipalityRecord>()
                .WithMany()
                .HasForeignKey(value => value.MunicipalityId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.ActorUserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.TargetUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static void ConfigureIdempotency(ModelBuilder builder)
    {
        builder.Entity<IdempotencyRecord>(entity =>
        {
            entity.ToTable("IdempotencyKayitlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.ActorUserId)
                .HasColumnName("ActorUserId")
                .HasMaxLength(450);
            entity.Property(value => value.ActorUserIdHash)
                .HasColumnName("ActorUserIdHash")
                .HasColumnType("binary(32)");
            entity.Property(value => value.EndpointCode)
                .HasColumnName("EndpointKodu")
                .HasMaxLength(150);
            entity.Property(value => value.IdempotencyKey)
                .HasColumnName("IdempotencyKey")
                .HasMaxLength(100);
            entity.Property(value => value.RequestHash)
                .HasColumnName("IstekHash")
                .HasColumnType("binary(32)");
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
            entity.HasIndex(value => new
            {
                value.ActorUserId,
                value.EndpointCode,
            });
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.ActorUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static void ConfigureRefreshToken(ModelBuilder builder)
    {
        builder.Entity<RefreshTokenRecord>(entity =>
        {
            entity.ToTable("YenilemeTokenlari", "sosyobel");
            entity.HasKey(value => value.Id);
            entity.Property(value => value.UserId).HasColumnName("UserId").HasMaxLength(450);
            entity.Property(value => value.TokenHash)
                .HasColumnName("TokenHash")
                .HasColumnType("binary(32)");
            entity.Property(value => value.DeviceId)
                .HasColumnName("CihazKimligi")
                .HasMaxLength(200);
            entity.Property(value => value.CreatedByIp)
                .HasColumnName("OlusturanIp")
                .HasColumnType("varchar(45)");
            entity.Property(value => value.CreatedAtUtc).HasColumnName("OlusturulmaTarihiUtc");
            entity.Property(value => value.ExpiresAtUtc).HasColumnName("SonKullanmaTarihiUtc");
            entity.Property(value => value.RevokedAtUtc).HasColumnName("IptalTarihiUtc");
            entity.Property(value => value.RevokedByIp)
                .HasColumnName("IptalEdenIp")
                .HasColumnType("varchar(45)");
            entity.Ignore(value => value.IsRevoked);
            entity.HasIndex(value => value.TokenHash).IsUnique();
            entity.HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(value => value.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
