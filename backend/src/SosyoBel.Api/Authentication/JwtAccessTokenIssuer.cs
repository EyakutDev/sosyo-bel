using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SosyoBel.Application.Authentication;

namespace SosyoBel.Api.Authentication;

internal sealed class JwtAccessTokenIssuer(
    IOptions<JwtOptions> options,
    TimeProvider timeProvider) : IAccessTokenIssuer
{
    public IssuedAccessToken Issue(AccessTokenSubject subject)
    {
        var jwtOptions = options.Value;
        var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
        var expiresAtUtc = nowUtc.AddMinutes(jwtOptions.AccessTokenMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, subject.UserId),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
            new(
                JwtRegisteredClaimNames.Iat,
                new DateTimeOffset(nowUtc).ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture),
                ClaimValueTypes.Integer64),
            new(JwtRegisteredClaimNames.PreferredUsername, subject.Username),
            new(JwtRegisteredClaimNames.Name, subject.DisplayName),
            new("client_id", "sosyobel-mobile"),
        };

        // Mevcut web hesaplarında e-posta boş olabildiği için yalnızca doluysa
        // claim üretilir; tokenın asıl kullanıcı anahtarı sub ve preferred_username'dır.
        if (!string.IsNullOrWhiteSpace(subject.Email))
        {
            claims.Add(new Claim(JwtRegisteredClaimNames.Email, subject.Email));
        }

        claims.AddRange(subject.Roles.Select(role => new Claim("role", role)));

        var signingCredentials = new SigningCredentials(
            new SymmetricSecurityKey(jwtOptions.GetSigningKeyBytes()),
            SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            jwtOptions.Issuer,
            jwtOptions.Audience,
            claims,
            notBefore: nowUtc,
            expires: expiresAtUtc,
            signingCredentials);

        return new IssuedAccessToken(
            new JwtSecurityTokenHandler().WriteToken(token),
            expiresAtUtc);
    }
}
