using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SosyoBel.Application.Administration;
using SosyoBel.Application.Authentication;
using SosyoBel.Application.Authorization;

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
                options.User.RequireUniqueEmail = true;
                options.Stores.MaxLengthForKeys = 128;
                options.SignIn.RequireConfirmedEmail = true;

                options.Password.RequiredLength = 10;
                options.Password.RequiredUniqueChars = 4;
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = false;

                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddRoles<IdentityRole>()
            .AddSignInManager()
            .AddEntityFrameworkStores<AuthenticationDbContext>();

        services
            .AddOptions<AuthenticationSessionOptions>()
            .Bind(configuration.GetSection(AuthenticationSessionOptions.SectionName))
            .Validate(
                options => options.RefreshTokenDays is >= 1 and <= 90,
                "Refresh token süresi 1 ile 90 gün arasında olmalıdır.")
            .ValidateOnStart();

        services.AddSingleton(TimeProvider.System);
        services.AddScoped<IAuthenticationService, IdentityAuthenticationService>();
        services.AddScoped<IAccountAdministrationService, AccountAdministrationService>();
        services.AddScoped<ISystemAdministratorBootstrapper, SystemAdministratorBootstrapper>();
        services.AddScoped<IAccessPermissionChecker, DatabaseAccessPermissionChecker>();
        services.AddScoped<IActiveMunicipalityMembershipChecker, ActiveMunicipalityMembershipChecker>();
        services.AddScoped<IActiveSystemAdministratorChecker, ActiveSystemAdministratorChecker>();

        return services;
    }
}
