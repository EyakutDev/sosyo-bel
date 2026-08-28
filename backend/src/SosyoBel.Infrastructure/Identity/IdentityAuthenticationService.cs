using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SosyoBel.Application.Authentication;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

internal sealed class IdentityAuthenticationService(
    UserManager<ApplicationUser> userManager,
    SignInManager<ApplicationUser> signInManager,
    AuthenticationDbContext authenticationDbContext,
    IdentityRefreshTokenStore refreshTokenStore,
    IAccessTokenIssuer accessTokenIssuer,
    IOptions<AuthenticationSessionOptions> sessionOptions,
    TimeProvider timeProvider,
    ILogger<IdentityAuthenticationService> logger) : IAuthenticationService
{
    private static readonly PasswordHasher<ApplicationUser> DummyPasswordHasher = new();
    private static readonly ApplicationUser DummyUser = new()
    {
        UserName = "dummy@sosyobel.invalid",
    };
    private static readonly string DummyPasswordHash = DummyPasswordHasher.HashPassword(
        DummyUser,
        "This-password-is-never-valid-9374");

    public async Task<AuthenticationResult> LoginAsync(
        LoginInput input,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(input.Username);
        ArgumentException.ThrowIfNullOrWhiteSpace(input.Password);

        // Şirketin web uygulaması gibi kullanıcı adı üzerinden mevcut
        // dbo.AspNetUsers kaydı bulunur; e-posta giriş anahtarı değildir.
        var user = await userManager.FindByNameAsync(input.Username.Trim());
        if (user is null)
        {
            // Bilinmeyen kullanıcı adında da parola özeti hesaplanarak zamanlama
            // farkından hesap varlığının anlaşılması zorlaştırılır.
            _ = DummyPasswordHasher.VerifyHashedPassword(
                DummyUser,
                DummyPasswordHash,
                input.Password);
            return new AuthenticationResult(AuthenticationStatus.InvalidCredentials);
        }

        var passwordResult = await signInManager.CheckPasswordSignInAsync(
            user,
            input.Password,
            lockoutOnFailure: false);
        if (passwordResult.IsLockedOut)
        {
            return new AuthenticationResult(AuthenticationStatus.LockedOut);
        }

        if (!passwordResult.Succeeded)
        {
            return new AuthenticationResult(AuthenticationStatus.InvalidCredentials);
        }

        var roles = await ResolveMobileRolesAsync(user);
        if (roles.Count == 0)
        {
            return new AuthenticationResult(AuthenticationStatus.AccessDenied);
        }

        return await CreateSessionAsync(
            user,
            roles,
            input.DeviceId,
            input.IpAddress,
            cancellationToken);
    }

    public async Task<AuthenticationResult> RefreshAsync(
        RefreshInput input,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(input.RefreshToken);
        var nowUtc = timeProvider.GetUtcNow().UtcDateTime;

        // Aynı refresh tokenın eş zamanlı iki kez döndürülmesini engellemek için
        // okuma, iptal ve yeni token ekleme tek Serializable transaction içindedir.
        await using var transaction = await authenticationDbContext.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);
        var existingToken = await refreshTokenStore.FindAsync(
            input.RefreshToken,
            cancellationToken);

        if (existingToken is null ||
            existingToken.IsExpired(nowUtc) ||
            !existingToken.MatchesDevice(input.DeviceId))
        {
            return new AuthenticationResult(AuthenticationStatus.InvalidRefreshToken);
        }

        if (existingToken.IsRevoked)
        {
            // Döndürülmüş tokenın yeniden sunulması kopyalanma belirtisidir.
            await refreshTokenStore.RevokeAllActiveAsync(
                existingToken.Entity.UserId,
                nowUtc,
                input.IpAddress,
                cancellationToken);
            await authenticationDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            logger.LogWarning(
                "İptal edilmiş refresh token yeniden kullanıldı; kullanıcı oturumları kapatıldı. UserId: {UserId}",
                existingToken.Entity.UserId);
            return new AuthenticationResult(AuthenticationStatus.RefreshTokenReuseDetected);
        }

        var user = await userManager.FindByIdAsync(existingToken.Entity.UserId);
        if (user is null || await userManager.IsLockedOutAsync(user))
        {
            refreshTokenStore.Revoke(existingToken, nowUtc, input.IpAddress);
            await authenticationDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return new AuthenticationResult(AuthenticationStatus.AccessDenied);
        }

        // Roller her yenilemede dbo.AspNetUserRoles üzerinden tekrar okunur;
        // kaldırılmış bir yetki eski refresh tokenla taşınamaz.
        var roles = await ResolveMobileRolesAsync(user);
        if (roles.Count == 0)
        {
            refreshTokenStore.Revoke(existingToken, nowUtc, input.IpAddress);
            await authenticationDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return new AuthenticationResult(AuthenticationStatus.AccessDenied);
        }

        refreshTokenStore.Revoke(existingToken, nowUtc, input.IpAddress);
        var result = await CreateSessionAsync(
            user,
            roles,
            input.DeviceId,
            input.IpAddress,
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return result;
    }

    public async Task LogoutAsync(LogoutInput input, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(input.RefreshToken);
        var token = await refreshTokenStore.FindAsync(input.RefreshToken, cancellationToken);
        if (token is null || token.IsRevoked)
        {
            return;
        }

        refreshTokenStore.Revoke(
            token,
            timeProvider.GetUtcNow().UtcDateTime,
            input.IpAddress);
        await authenticationDbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthenticationResult> CreateSessionAsync(
        ApplicationUser user,
        IReadOnlyCollection<string> roles,
        string? deviceId,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        var username = user.UserName ??
            throw new InvalidOperationException("Identity kullanıcısının kullanıcı adı bulunamadı.");
        var displayName = string.IsNullOrWhiteSpace(user.DisplayName)
            ? username
            : user.DisplayName;
        var accessToken = accessTokenIssuer.Issue(new AccessTokenSubject(
            user.Id,
            username,
            string.IsNullOrWhiteSpace(user.Email) ? null : user.Email,
            displayName,
            roles));

        var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
        var refreshExpiresAtUtc = nowUtc.AddDays(sessionOptions.Value.RefreshTokenDays);
        // Aynı kullanıcıya ait süresi dolmuş API oturumları yeni tabloya ihtiyaç
        // olmadan mevcut AspNetUserTokens tablosunda düzenli olarak temizlenir.
        await refreshTokenStore.RemoveExpiredOrInvalidAsync(
            user.Id,
            nowUtc,
            cancellationToken);
        var refreshToken = refreshTokenStore.Issue(
            user.Id,
            deviceId,
            ipAddress,
            nowUtc,
            refreshExpiresAtUtc);
        await authenticationDbContext.SaveChangesAsync(cancellationToken);

        return new AuthenticationResult(
            AuthenticationStatus.Succeeded,
            new AuthenticationSession(
                accessToken.Value,
                accessToken.ExpiresAtUtc,
                refreshToken.Value,
                refreshToken.ExpiresAtUtc,
                new AuthenticatedUserProfile(
                    user.Id,
                    username,
                    string.IsNullOrWhiteSpace(user.Email) ? null : user.Email,
                    displayName,
                    roles)));
    }

    private async Task<IReadOnlyCollection<string>> ResolveMobileRolesAsync(
        ApplicationUser user)
    {
        var identityRoles = await userManager.GetRolesAsync(user);
        return identityRoles
            .Where(CompanyIdentityRoleCodes.GrantsMobileFieldAccess)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }
}
