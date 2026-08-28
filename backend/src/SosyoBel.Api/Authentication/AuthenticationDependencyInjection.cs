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

        services.AddAuthorizationBuilder()
            .AddPolicy(
                AuthorizationPolicyNames.MobileFieldOperations,
                policy => policy
                    .RequireAuthenticatedUser()
                    // Uygulama tek belediyelidir. Mobil yetki yalnız şirketin mevcut
                    // dbo.AspNetRoles kayıtlarından okunur; ek üyelik tablosu aranmaz.
                    .RequireRole(
                        CompanyIdentityRoleCodes.Administrator,
                        CompanyIdentityRoleCodes.Board,
                        CompanyIdentityRoleCodes.Personnel))
            // Yeni endpointlerin yanlışlıkla anonim açılmasını engeller. Yalnız açıkça
            // AllowAnonymous verilen login ve health uçları kimlik doğrulama istemez.
            .SetFallbackPolicy(
                new AuthorizationPolicyBuilder()
                    .RequireAuthenticatedUser()
                    .Build());

        return services;
    }
}
