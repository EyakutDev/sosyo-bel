using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SosyoBel.Application.Authentication;

namespace SosyoBel.Infrastructure.Identity;

public static class IdentityDependencyInjection
{
    public static IServiceCollection AddSosyoBelIdentity(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("SosyoBel");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException("ConnectionStrings:SosyoBel yapılandırılmalıdır.");
        }

        services.AddDbContext<AuthenticationDbContext>(options =>
            options.UseSqlServer(
                connectionString,
                sqlServer =>
                {
                    sqlServer.CommandTimeout(30);
                    // Refresh token rotasyonu Serializable transaction kullanır. Bu
                    // nedenle aynı işlemi belirsiz biçimde tekrarlayacak otomatik retry açılmaz.
                }));

        services
            .AddIdentityCore<ApplicationUser>(options =>
            {
                // Web uygulaması kullanıcı adıyla giriş yapar; mevcut hesaplarda
                // e-posta boş veya onaysız olabildiği için giriş koşulu yapılmaz.
                options.User.RequireUniqueEmail = false;
                // Şirketin mevcut ASP.NET Identity tablolarındaki anahtar uzunluğu.
                options.Stores.MaxLengthForKeys = 450;
                options.SignIn.RequireConfirmedEmail = false;

                // Aynı dbo.AspNetUsers kayıtlarını yöneten web uygulamasıyla
                // parola ilkeleri aynı tutulur.
                options.Password.RequiredLength = 3;
                options.Password.RequiredUniqueChars = 1;
                options.Password.RequireDigit = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireUppercase = false;
                options.Password.RequireNonAlphanumeric = false;

                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddRoles<IdentityRole>()
            .AddSignInManager()
            .AddEntityFrameworkStores<AuthenticationDbContext>()
            // Mevcut web panelinin ürettiği Identity tokenlarıyla uyumluluk korunur.
            .AddDefaultTokenProviders();

        services
            .AddOptions<AuthenticationSessionOptions>()
            .Bind(configuration.GetSection(AuthenticationSessionOptions.SectionName))
            .Validate(
                options => options.RefreshTokenDays is >= 1 and <= 90,
                "Refresh token süresi 1 ile 90 gün arasında olmalıdır.")
            .ValidateOnStart();

        services.AddSingleton(TimeProvider.System);
        services.AddScoped<IdentityRefreshTokenStore>();
        services.AddScoped<IAuthenticationService, IdentityAuthenticationService>();

        return services;
    }
}
