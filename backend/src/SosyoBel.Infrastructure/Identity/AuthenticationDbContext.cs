using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Şirketin mevcut ASP.NET Core Identity tablolarını kullanır. Bu context yeni
/// tablo veya şema üretmez; yalnız dbo.AspNet* tablolarının eşlemesini tanımlar.
/// </summary>
internal sealed class AuthenticationDbContext(
    DbContextOptions<AuthenticationDbContext> options)
    : IdentityDbContext<ApplicationUser, IdentityRole, string>(options)
{
    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Şirket şemasındaki bütün Identity anahtarları nvarchar(450) olarak
        // tanımlıdır. Açık eşleme, EF varsayımlarının canlı şemadan sapmasını önler.
        builder.Entity<ApplicationUser>(entity =>
        {
            entity.ToTable("AspNetUsers", "dbo");
            entity.Property(user => user.Id).HasMaxLength(450);
            entity.Property(user => user.FirstName).HasColumnName("Ad").IsRequired();
            entity.Property(user => user.LastName).HasColumnName("Soyad").IsRequired();
            entity.Ignore(user => user.DisplayName);
        });
        builder.Entity<IdentityRole>(entity =>
        {
            entity.ToTable("AspNetRoles", "dbo");
            entity.Property(role => role.Id).HasMaxLength(450);
        });
        builder.Entity<IdentityRoleClaim<string>>(entity =>
        {
            entity.ToTable("AspNetRoleClaims", "dbo");
            entity.Property(claim => claim.RoleId).HasMaxLength(450);
        });
        builder.Entity<IdentityUserClaim<string>>(entity =>
        {
            entity.ToTable("AspNetUserClaims", "dbo");
            entity.Property(claim => claim.UserId).HasMaxLength(450);
        });
        builder.Entity<IdentityUserLogin<string>>(entity =>
        {
            entity.ToTable("AspNetUserLogins", "dbo");
            entity.Property(login => login.LoginProvider).HasMaxLength(450);
            entity.Property(login => login.ProviderKey).HasMaxLength(450);
            entity.Property(login => login.UserId).HasMaxLength(450);
        });
        builder.Entity<IdentityUserRole<string>>(entity =>
        {
            entity.ToTable("AspNetUserRoles", "dbo");
            entity.Property(role => role.UserId).HasMaxLength(450);
            entity.Property(role => role.RoleId).HasMaxLength(450);
        });
        builder.Entity<IdentityUserToken<string>>(entity =>
        {
            entity.ToTable("AspNetUserTokens", "dbo");
            entity.Property(token => token.UserId).HasMaxLength(450);
            entity.Property(token => token.LoginProvider).HasMaxLength(450);
            entity.Property(token => token.Name).HasMaxLength(450);
        });
    }
}
