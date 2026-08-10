using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SosyoBel.Application.Authentication;
using SosyoBel.Application.Authorization;

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
            new(JwtRegisteredClaimNames.Email, subject.Email),
            new(JwtRegisteredClaimNames.Name, subject.DisplayName),
            new("client_id", "sosyobel-mobile"),
        };

        var tenantValueCount =
            (subject.MunicipalityId is null ? 0 : 1) +
            (subject.MunicipalityCode is null ? 0 : 1) +
            (subject.MunicipalityMembershipId is null ? 0 : 1);
        if (tenantValueCount is not (0 or 3))
        {
            throw new InvalidOperationException(
                "Belediye token kapsamı eksik veya tutarsız üretilemez.");
        }

        if (subject.MunicipalityId is int municipalityId &&
            subject.MunicipalityMembershipId is long membershipId)
        {
            claims.Add(new Claim(
                CustomClaimTypes.MunicipalityId,
                municipalityId.ToString(CultureInfo.InvariantCulture)));
            claims.Add(new Claim(
                CustomClaimTypes.MunicipalityCode,
                subject.MunicipalityCode!));
            claims.Add(new Claim(
                CustomClaimTypes.MunicipalityMembershipId,
                membershipId.ToString(CultureInfo.InvariantCulture)));
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
