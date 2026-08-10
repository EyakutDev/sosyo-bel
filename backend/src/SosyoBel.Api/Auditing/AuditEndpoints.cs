using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using SosyoBel.Application.Auditing;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Auditing;

internal static class AuditEndpoints
{
    public static IEndpointRouteBuilder MapAuditEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/system/audit", GetAllAsync)
            .WithTags("Denetim Kayıtları")
            .WithSummary("Sistem genelindeki denetim kayıtlarını getirir")
            .WithDescription(
                "Yalnızca sistem yöneticisi kullanabilir. Tüm belediyelerin işlem geçmişini döndürür; " +
                "municipalityCode ile tek belediyeye filtrelenebilir. limit değeri 1-200 arasındadır.")
            .RequireAuthorization(AuthorizationPolicyNames.SystemAdministrator);
        endpoints.MapGet("/api/v1/municipality/audit", GetMunicipalityAsync)
            .WithTags("Denetim Kayıtları")
            .WithSummary("Aktif belediyenin denetim kayıtlarını getirir")
            .WithDescription(
                "Belediye yöneticisinin yalnızca tokenında yer alan belediyeye ait işlem geçmişini " +
                "görmesini sağlar. limit değeri 1-200 arasındadır ve varsayılanı 100'dür.")
            .RequireAuthorization(AuthorizationPolicyNames.MunicipalityAdministrator);
        endpoints.MapGet("/api/v1/audit/mine", GetOwnAsync)
            .WithTags("Denetim Kayıtları")
            .WithSummary("Personelin kendi işlem geçmişini getirir")
            .WithDescription(
                "Oturum açmış personelin yalnızca kendi belediyesi içinde gerçekleştirdiği işlemleri " +
                "döndürür. limit değeri 1-200 arasındadır ve varsayılanı 100'dür.")
            .RequireAuthorization(AuthorizationPolicyNames.Personnel);

        return endpoints;
    }

    private static async Task<IResult> GetAllAsync(
        string? municipalityCode,
        int? limit,
        IAuditEventQuery query,
        CancellationToken cancellationToken)
    {
        if (municipalityCode?.Length > 50)
        {
            return Validation("municipalityCode", "Belediye kodu en fazla 50 karakter olabilir.");
        }

        var requestedLimit = limit ?? 100;
        if (!IsValidLimit(requestedLimit))
        {
            return Validation("limit", "Limit 1 ile 200 arasında olmalıdır.");
        }

        return Results.Ok(await query.GetAllAsync(
            municipalityCode,
            requestedLimit,
            cancellationToken));
    }

    private static async Task<IResult> GetMunicipalityAsync(
        int? limit,
        ClaimsPrincipal principal,
        IAuditEventQuery query,
        CancellationToken cancellationToken)
    {
        if (!TryReadMunicipalityId(principal, out var municipalityId))
        {
            return Results.Forbid();
        }

        var requestedLimit = limit ?? 100;
        if (!IsValidLimit(requestedLimit))
        {
            return Validation("limit", "Limit 1 ile 200 arasında olmalıdır.");
        }

        return Results.Ok(await query.GetMunicipalityAsync(
            municipalityId,
            requestedLimit,
            cancellationToken));
    }

    private static async Task<IResult> GetOwnAsync(
        int? limit,
        ClaimsPrincipal principal,
        IAuditEventQuery query,
        CancellationToken cancellationToken)
    {
        var userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub);
        if (string.IsNullOrWhiteSpace(userId) ||
            !TryReadMunicipalityId(principal, out var municipalityId))
        {
            return Results.Forbid();
        }

        var requestedLimit = limit ?? 100;
        if (!IsValidLimit(requestedLimit))
        {
            return Validation("limit", "Limit 1 ile 200 arasında olmalıdır.");
        }

        return Results.Ok(await query.GetOwnAsync(
            municipalityId,
            userId,
            requestedLimit,
            cancellationToken));
    }

    private static bool TryReadMunicipalityId(
        ClaimsPrincipal principal,
        out int municipalityId) =>
        int.TryParse(
            principal.FindFirstValue(CustomClaimTypes.MunicipalityId),
            NumberStyles.None,
            CultureInfo.InvariantCulture,
            out municipalityId) && municipalityId > 0;

    private static bool IsValidLimit(int limit) => limit is >= 1 and <= 200;

    private static IResult Validation(string field, string message) =>
        Results.ValidationProblem(new Dictionary<string, string[]>
        {
            [field] = [message],
        });
}
