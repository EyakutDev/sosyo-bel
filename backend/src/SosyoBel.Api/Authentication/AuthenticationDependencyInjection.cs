using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using SosyoBel.Application.Authentication;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Authentication;

internal static class AuthenticationDependencyInjection
{
    public static IServiceCollection AddSosyoBelAuthentication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var jwtOptions = configuration
            .GetSection(JwtOptions.SectionName)
            .Get<JwtOptions>() ?? throw new InvalidOperationException("JWT ayarları bulunamadı.");
        jwtOptions.Validate();

        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        services.AddSingleton<IAccessTokenIssuer, JwtAccessTokenIssuer>();
        services.AddScoped<IAuthorizationHandler, ActiveSystemAdministratorAuthorizationHandler>();
        services.AddScoped<IAuthorizationHandler, ActiveMunicipalityMembershipAuthorizationHandler>();
        services.AddScoped<IAuthorizationHandler, LockedApplicationEditAuthorizationHandler>();

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = jwtOptions.Issuer,
                    ValidateAudience = true,
                    ValidAudience = jwtOptions.Audience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(jwtOptions.GetSigningKeyBytes()),
                    ValidateLifetime = true,
                    RequireExpirationTime = true,
                    RequireSignedTokens = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                    NameClaimType = "name",
                    RoleClaimType = "role",
                };
            });

        // Belediye politikaları role ek olarak üyelik claim'ini de şart koşar.
        // Bu sayede yalnız rol adına bakılarak tenant dışına çıkılamaz.
        services.AddAuthorizationBuilder()
            .AddPolicy(
                AuthorizationPolicyNames.SystemAdministrator,
                policy => policy
                    .RequireAuthenticatedUser()
                    .RequireRole(RoleCodes.SystemAdministrator)
                    .AddRequirements(new ActiveSystemAdministratorRequirement()))
            .AddPolicy(
                AuthorizationPolicyNames.MunicipalityAdministrator,
                policy => policy
                    .RequireAuthenticatedUser()
                    .RequireRole(RoleCodes.MunicipalityAdministrator)
                    .RequireClaim(CustomClaimTypes.MunicipalityId)
                    .RequireClaim(CustomClaimTypes.MunicipalityMembershipId)
                    .AddRequirements(new ActiveMunicipalityMembershipRequirement(
                        RoleCodes.MunicipalityAdministrator)))
            .AddPolicy(
                AuthorizationPolicyNames.Personnel,
                policy => policy
                    .RequireAuthenticatedUser()
                    .RequireRole(RoleCodes.Personnel)
                    .RequireClaim(CustomClaimTypes.MunicipalityId)
                    .RequireClaim(CustomClaimTypes.MunicipalityMembershipId)
                    .AddRequirements(new ActiveMunicipalityMembershipRequirement(
                        RoleCodes.Personnel)))
            .AddPolicy(
                AuthorizationPolicyNames.LockedApplicationEdit,
                policy => policy
                    .RequireAuthenticatedUser()
                    .RequireClaim(CustomClaimTypes.MunicipalityId)
                    .RequireClaim(CustomClaimTypes.MunicipalityMembershipId)
                    .AddRequirements(new LockedApplicationEditRequirement()))
            // Yeni endpoint'lerin yanlışlıkla anonim açılmasını engeller. Yalnız açıkça
            // AllowAnonymous verilen giriş ve sağlık uçları kimlik doğrulama istemez.
            .SetFallbackPolicy(
                new AuthorizationPolicyBuilder()
                    .RequireAuthenticatedUser()
                    .Build());

        return services;
    }
}
