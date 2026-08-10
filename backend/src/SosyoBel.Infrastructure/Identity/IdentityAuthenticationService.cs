using System.Data;
using System.Security.Cryptography;
using System.Text;
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
    IAccessTokenIssuer accessTokenIssuer,
    IOptions<AuthenticationSessionOptions> sessionOptions,
    TimeProvider timeProvider,
    ILogger<IdentityAuthenticationService> logger) : IAuthenticationService
{
    private static readonly PasswordHasher<ApplicationUser> DummyPasswordHasher = new();
    private static readonly ApplicationUser DummyUser = ApplicationUser.Create(
        "dummy@sosyobel.invalid",
        "Dummy",
        "User",
        DateTime.UnixEpoch);
    private static readonly string DummyPasswordHash = DummyPasswordHasher.HashPassword(
        DummyUser,
        "This-password-is-never-valid-9374");

    public async Task<AuthenticationResult> LoginAsync(
        LoginInput input,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(input.Email);
        ArgumentException.ThrowIfNullOrWhiteSpace(input.Password);

        var user = await userManager.FindByEmailAsync(input.Email.Trim());
        if (user is null)
        {
            // Bilinmeyen e-postada da parola özeti hesaplanarak zamanlama farkı azaltılır.
            _ = DummyPasswordHasher.VerifyHashedPassword(
                DummyUser,
                DummyPasswordHash,
                input.Password);
            return new AuthenticationResult(AuthenticationStatus.InvalidCredentials);
        }

        var passwordResult = await signInManager.CheckPasswordSignInAsync(
            user,
            input.Password,
            lockoutOnFailure: true);

        if (passwordResult.IsLockedOut)
        {
            return new AuthenticationResult(AuthenticationStatus.LockedOut);
        }

        if (!passwordResult.Succeeded || !user.IsActive || !user.EmailConfirmed)
        {
            return new AuthenticationResult(AuthenticationStatus.InvalidCredentials);
        }

        var access = await ResolveAccessAsync(
            user,
            input.MunicipalityCode,
            cancellationToken);

        if (access.Status is not AuthenticationStatus.Succeeded)
        {
            return new AuthenticationResult(access.Status, Municipalities: access.Options);
        }

        return await CreateSessionAsync(
            user,
            access.Scope!,
            input.DeviceId,
            input.IpAddress,
            cancellationToken);
    }

    public async Task<AuthenticationResult> RefreshAsync(
        RefreshInput input,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(input.RefreshToken);

        var tokenHash = HashToken(input.RefreshToken);
        var nowUtc = timeProvider.GetUtcNow().UtcDateTime;

        await using var transaction = await authenticationDbContext.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);

        var existingToken = await authenticationDbContext.RefreshTokens
            .SingleOrDefaultAsync(token => token.TokenHash == tokenHash, cancellationToken);

        if (existingToken is null)
        {
            return new AuthenticationResult(AuthenticationStatus.InvalidRefreshToken);
        }

        if (existingToken.IsRevoked)
        {
            // İptal edilmiş token'ın yeniden sunulması kopyalanma belirtisidir.
            var activeTokens = await authenticationDbContext.RefreshTokens
                .Where(token =>
                    token.UserId == existingToken.UserId &&
                    token.RevokedAtUtc == null &&
                    token.ExpiresAtUtc > nowUtc)
                .ToListAsync(cancellationToken);

            foreach (var activeToken in activeTokens)
            {
                activeToken.Revoke(nowUtc, input.IpAddress);
            }

            await authenticationDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            logger.LogWarning(
                "İptal edilmiş refresh token yeniden kullanıldı; kullanıcı oturumları kapatıldı. UserId: {UserId}",
                existingToken.UserId);
            return new AuthenticationResult(AuthenticationStatus.RefreshTokenReuseDetected);
        }

        if (existingToken.IsExpired(nowUtc))
        {
            return new AuthenticationResult(AuthenticationStatus.InvalidRefreshToken);
        }

        var user = await userManager.FindByIdAsync(existingToken.UserId);
        if (user is null || !user.IsActive || !user.EmailConfirmed ||
            await userManager.IsLockedOutAsync(user))
        {
            existingToken.Revoke(nowUtc, input.IpAddress);
            await authenticationDbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return new AuthenticationResult(AuthenticationStatus.AccessDenied);
        }

        // Rol ve üyelik refresh sırasında yeniden okunur; eski token yetkisi taşınmaz.
        var access = await ResolveAccessAsync(
            user,
            input.MunicipalityCode,
            cancellationToken);

        if (access.Status is not AuthenticationStatus.Succeeded)
        {
            if (access.Status is AuthenticationStatus.AccessDenied)
            {
                existingToken.Revoke(nowUtc, input.IpAddress);
                await authenticationDbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
            }

            return new AuthenticationResult(access.Status, Municipalities: access.Options);
        }

        existingToken.Revoke(nowUtc, input.IpAddress);
        var result = await CreateSessionAsync(
            user,
            access.Scope!,
            input.DeviceId,
            input.IpAddress,
            cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return result;
    }

    public async Task LogoutAsync(LogoutInput input, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(input.RefreshToken);
        var tokenHash = HashToken(input.RefreshToken);
        var token = await authenticationDbContext.RefreshTokens
            .SingleOrDefaultAsync(value => value.TokenHash == tokenHash, cancellationToken);

        if (token is null || token.IsRevoked)
        {
            return;
        }

        token.Revoke(timeProvider.GetUtcNow().UtcDateTime, input.IpAddress);
        await authenticationDbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthenticationResult> CreateSessionAsync(
        ApplicationUser user,
        ResolvedAccessScope accessScope,
        string? deviceId,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        var accessToken = accessTokenIssuer.Issue(new AccessTokenSubject(
            user.Id,
            user.Email!,
            user.DisplayName,
            accessScope.MunicipalityId,
            accessScope.MunicipalityCode,
            accessScope.MunicipalityMembershipId,
            accessScope.Roles));

        var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
        var refreshToken = GenerateRefreshToken();
        var refreshExpiresAtUtc = nowUtc.AddDays(sessionOptions.Value.RefreshTokenDays);

        authenticationDbContext.RefreshTokens.Add(RefreshTokenRecord.Create(
            user.Id,
            HashToken(refreshToken),
            deviceId,
            ipAddress,
            nowUtc,
            refreshExpiresAtUtc));
        await authenticationDbContext.SaveChangesAsync(cancellationToken);

        return new AuthenticationResult(
            AuthenticationStatus.Succeeded,
            new AuthenticationSession(
                accessToken.Value,
                accessToken.ExpiresAtUtc,
                refreshToken,
                refreshExpiresAtUtc,
                new AuthenticatedUserProfile(
                    user.Id,
                    user.Email!,
                    user.DisplayName,
                    accessScope.MunicipalityCode,
                    accessScope.MunicipalityName,
                    accessScope.MunicipalityMembershipId,
                    accessScope.Roles)));
    }

    private async Task<AccessResolution> ResolveAccessAsync(
        ApplicationUser user,
        string? requestedMunicipalityCode,
        CancellationToken cancellationToken)
    {
        var identityRoles = await userManager.GetRolesAsync(user);
        if (identityRoles.Contains(RoleCodes.SystemAdministrator, StringComparer.Ordinal))
        {
            // Sistem yöneticisi tenant dışıdır; belediye claim'i üretmez.
            return new AccessResolution(
                AuthenticationStatus.Succeeded,
                ResolvedAccessScope.ForSystemAdministrator());
        }

        var scopes = await (
            from membership in authenticationDbContext.UserMunicipalities.AsNoTracking()
            join municipality in authenticationDbContext.Municipalities.AsNoTracking()
                on membership.MunicipalityId equals municipality.Id
            where membership.UserId == user.Id &&
                  membership.IsActive &&
                  municipality.IsActive &&
                  (membership.RoleCode == RoleCodes.MunicipalityAdministrator ||
                   membership.RoleCode == RoleCodes.Personnel)
            orderby municipality.Name
            select new ResolvedAccessScope(
                membership.Id,
                municipality.Id,
                municipality.Code,
                municipality.Name,
                new[] { membership.RoleCode }))
            .ToArrayAsync(cancellationToken);

        if (scopes.Length == 0)
        {
            return new AccessResolution(AuthenticationStatus.AccessDenied);
        }

        if (!string.IsNullOrWhiteSpace(requestedMunicipalityCode))
        {
            var normalizedCode = requestedMunicipalityCode.Trim().ToUpperInvariant();
            var selected = scopes.SingleOrDefault(value =>
                string.Equals(
                    value.MunicipalityCode,
                    normalizedCode,
                    StringComparison.Ordinal));
            return selected is null
                ? new AccessResolution(AuthenticationStatus.AccessDenied)
                : new AccessResolution(AuthenticationStatus.Succeeded, selected);
        }

        if (scopes.Length == 1)
        {
            return new AccessResolution(AuthenticationStatus.Succeeded, scopes[0]);
        }

        return new AccessResolution(
            AuthenticationStatus.MunicipalitySelectionRequired,
            Options: scopes
                .Select(value => new MunicipalityOption(
                    value.MunicipalityCode!,
                    value.MunicipalityName!))
                .ToArray());
    }

    private static string GenerateRefreshToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(64);
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static byte[] HashToken(string token) =>
        SHA256.HashData(Encoding.UTF8.GetBytes(token));

    private sealed record ResolvedAccessScope(
        long? MunicipalityMembershipId,
        int? MunicipalityId,
        string? MunicipalityCode,
        string? MunicipalityName,
        IReadOnlyCollection<string> Roles)
    {
        public static ResolvedAccessScope ForSystemAdministrator() =>
            new(
                null,
                null,
                null,
                null,
                new[] { RoleCodes.SystemAdministrator });
    }

    private sealed record AccessResolution(
        AuthenticationStatus Status,
        ResolvedAccessScope? Scope = null,
        IReadOnlyCollection<MunicipalityOption>? Options = null);
}
