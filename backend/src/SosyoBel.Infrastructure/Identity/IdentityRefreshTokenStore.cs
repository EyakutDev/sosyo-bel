using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Mobil refresh oturumlarını şirketin mevcut dbo.AspNetUserTokens tablosunda
/// saklar. Açık token hiçbir zaman veritabanına yazılmaz; yalnız SHA-256 özeti
/// ve oturum yaşam döngüsü bilgileri tutulur.
/// </summary>
internal sealed class IdentityRefreshTokenStore(AuthenticationDbContext dbContext)
{
    internal const string LoginProvider = "SosyoBel.Api";
    internal const string TokenNamePrefix = "RefreshToken:";

    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    public IssuedIdentityRefreshToken Issue(
        string userId,
        string? deviceId,
        string? createdByIp,
        DateTime createdAtUtc,
        DateTime expiresAtUtc)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (expiresAtUtc <= createdAtUtc)
        {
            throw new ArgumentOutOfRangeException(nameof(expiresAtUtc));
        }

        var sessionId = Guid.NewGuid();
        var secret = Base64UrlEncode(RandomNumberGenerator.GetBytes(64));
        var rawToken = string.Join(
            '.',
            Base64UrlEncode(Encoding.UTF8.GetBytes(userId)),
            sessionId.ToString("N"),
            secret);
        var metadata = new RefreshTokenMetadata(
            Convert.ToBase64String(Hash(rawToken)),
            NormalizeOptional(deviceId, 200),
            NormalizeOptional(createdByIp, 45),
            EnsureUtc(createdAtUtc),
            EnsureUtc(expiresAtUtc),
            null,
            null);

        dbContext.UserTokens.Add(new IdentityUserToken<string>
        {
            UserId = userId,
            LoginProvider = LoginProvider,
            Name = TokenNamePrefix + sessionId.ToString("N"),
            Value = JsonSerializer.Serialize(metadata, JsonOptions),
        });

        return new IssuedIdentityRefreshToken(rawToken, metadata.ExpiresAtUtc);
    }

    public async Task<StoredIdentityRefreshToken?> FindAsync(
        string rawToken,
        CancellationToken cancellationToken)
    {
        if (!TryReadLocator(rawToken, out var userId, out var tokenName))
        {
            return null;
        }

        var entity = await dbContext.UserTokens.SingleOrDefaultAsync(
            value =>
                value.UserId == userId &&
                value.LoginProvider == LoginProvider &&
                value.Name == tokenName,
            cancellationToken);
        if (entity?.Value is null || !TryDeserialize(entity.Value, out var metadata))
        {
            return null;
        }

        byte[] storedHash;
        try
        {
            storedHash = Convert.FromBase64String(metadata.TokenHashBase64);
        }
        catch (FormatException)
        {
            return null;
        }

        var suppliedHash = Hash(rawToken);
        if (storedHash.Length != suppliedHash.Length ||
            !CryptographicOperations.FixedTimeEquals(storedHash, suppliedHash))
        {
            return null;
        }

        return new StoredIdentityRefreshToken(entity, metadata);
    }

    public void Revoke(
        StoredIdentityRefreshToken token,
        DateTime revokedAtUtc,
        string? revokedByIp)
    {
        if (token.IsRevoked)
        {
            return;
        }

        var updated = token.Metadata with
        {
            RevokedAtUtc = EnsureUtc(revokedAtUtc),
            RevokedByIp = NormalizeOptional(revokedByIp, 45),
        };
        token.Entity.Value = JsonSerializer.Serialize(updated, JsonOptions);
    }

    public async Task<int> RevokeAllActiveAsync(
        string userId,
        DateTime revokedAtUtc,
        string? revokedByIp,
        CancellationToken cancellationToken)
    {
        var entities = await dbContext.UserTokens
            .Where(value =>
                value.UserId == userId &&
                value.LoginProvider == LoginProvider &&
                value.Name.StartsWith(TokenNamePrefix))
            .ToListAsync(cancellationToken);
        var revokedCount = 0;

        foreach (var entity in entities)
        {
            if (entity.Value is null || !TryDeserialize(entity.Value, out var metadata) ||
                metadata.RevokedAtUtc is not null ||
                metadata.ExpiresAtUtc <= revokedAtUtc)
            {
                continue;
            }

            entity.Value = JsonSerializer.Serialize(
                metadata with
                {
                    RevokedAtUtc = EnsureUtc(revokedAtUtc),
                    RevokedByIp = NormalizeOptional(revokedByIp, 45),
                },
                JsonOptions);
            revokedCount++;
        }

        return revokedCount;
    }

    public async Task RemoveExpiredOrInvalidAsync(
        string userId,
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        var entities = await dbContext.UserTokens
            .Where(value =>
                value.UserId == userId &&
                value.LoginProvider == LoginProvider &&
                value.Name.StartsWith(TokenNamePrefix))
            .ToListAsync(cancellationToken);

        foreach (var entity in entities)
        {
            if (entity.Value is null ||
                !TryDeserialize(entity.Value, out var metadata) ||
                metadata.ExpiresAtUtc <= utcNow)
            {
                dbContext.UserTokens.Remove(entity);
            }
        }
    }

    internal static bool TryReadLocator(
        string? rawToken,
        out string userId,
        out string tokenName)
    {
        userId = string.Empty;
        tokenName = string.Empty;
        if (string.IsNullOrWhiteSpace(rawToken))
        {
            return false;
        }

        var segments = rawToken.Split('.');
        if (segments.Length != 3 ||
            !Guid.TryParseExact(segments[1], "N", out var sessionId) ||
            segments[2].Length < 43)
        {
            return false;
        }

        try
        {
            userId = Encoding.UTF8.GetString(Base64UrlDecode(segments[0]));
        }
        catch (FormatException)
        {
            return false;
        }

        if (string.IsNullOrWhiteSpace(userId))
        {
            return false;
        }

        tokenName = TokenNamePrefix + sessionId.ToString("N");
        return true;
    }

    private static bool TryDeserialize(string json, out RefreshTokenMetadata metadata)
    {
        try
        {
            metadata = JsonSerializer.Deserialize<RefreshTokenMetadata>(json, JsonOptions)!;
            return metadata is not null &&
                   !string.IsNullOrWhiteSpace(metadata.TokenHashBase64);
        }
        catch (JsonException)
        {
            metadata = null!;
            return false;
        }
    }

    private static byte[] Hash(string token) =>
        SHA256.HashData(Encoding.UTF8.GetBytes(token));

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

    private static byte[] Base64UrlDecode(string value)
    {
        var base64 = value.Replace('-', '+').Replace('_', '/');
        base64 = (base64.Length % 4) switch
        {
            0 => base64,
            2 => base64 + "==",
            3 => base64 + "=",
            _ => throw new FormatException("Geçersiz Base64Url değeri."),
        };
        return Convert.FromBase64String(base64);
    }

    private static DateTime EnsureUtc(DateTime value) =>
        DateTime.SpecifyKind(value, DateTimeKind.Utc);

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        var normalized = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        if (normalized?.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        return normalized;
    }

    internal sealed record RefreshTokenMetadata(
        string TokenHashBase64,
        string? DeviceId,
        string? CreatedByIp,
        DateTime CreatedAtUtc,
        DateTime ExpiresAtUtc,
        DateTime? RevokedAtUtc,
        string? RevokedByIp);
}

internal sealed record IssuedIdentityRefreshToken(string Value, DateTime ExpiresAtUtc);

internal sealed record StoredIdentityRefreshToken(
    IdentityUserToken<string> Entity,
    IdentityRefreshTokenStore.RefreshTokenMetadata Metadata)
{
    public bool IsRevoked => Metadata.RevokedAtUtc is not null;

    public bool IsExpired(DateTime utcNow) => Metadata.ExpiresAtUtc <= utcNow;

    public bool MatchesDevice(string? deviceId) =>
        string.Equals(Metadata.DeviceId, deviceId, StringComparison.Ordinal);
}
