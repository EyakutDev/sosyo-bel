using System.Globalization;
using System.Security.Claims;
using SosyoBel.Application.Abstractions;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Tenant;

/// <summary>
/// Belediye kimliği yalnız doğrulanmış token claim'inden okunur. Header, query
/// string veya istek gövdesindeki belediye değeri yetkilendirme için kullanılmaz.
/// </summary>
internal sealed class HttpCurrentMunicipality(IHttpContextAccessor httpContextAccessor)
    : ICurrentMunicipality
{
    internal const string MunicipalityIdClaim = CustomClaimTypes.MunicipalityId;

    public int? MunicipalityId
    {
        get
        {
            var value = httpContextAccessor.HttpContext?.User.FindFirstValue(MunicipalityIdClaim);
            return int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var id) && id > 0
                ? id
                : null;
        }
    }

    public int RequireMunicipalityId() => MunicipalityId ??
        throw new UnauthorizedAccessException("Kullanıcının belediye kapsamı bulunamadı.");
}
