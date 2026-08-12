using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.WorkItems;

namespace SosyoBel.Api.WorkItems;

internal static class WorkItemEndpoints
{
    public static IEndpointRouteBuilder MapWorkItemEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/work-items/mine", GetMineAsync)
            .WithTags("İş Listesi")
            .WithSummary("Personelin bekleyen ve tamamlanan işlerini getirir")
            .WithDescription(
                "Şirketin dbo.Basvurular tablosundaki, personelin kendi oluşturduğu başvuruları mobil metadata ve " +
                "kararlı durum kodlarıyla listeler. Görev atama tablosunun şirket eşlemesi kesinleştiğinde aynı " +
                "yanıt sözleşmesine ikinci kaynak olarak eklenecektir. " +
                "limit değeri 1-100 arasındadır ve varsayılanı 50'dir.")
            .RequireAuthorization(AuthorizationPolicyNames.Personnel);

        return endpoints;
    }

    private static async Task<IResult> GetMineAsync(
        int? limit,
        ClaimsPrincipal principal,
        IUserWorkItemQuery query,
        CancellationToken cancellationToken)
    {
        var userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var municipalityValue = principal.FindFirstValue(CustomClaimTypes.MunicipalityId);
        var membershipValue = principal.FindFirstValue(
            CustomClaimTypes.MunicipalityMembershipId);

        if (string.IsNullOrWhiteSpace(userId) ||
            !int.TryParse(
                municipalityValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var municipalityId) ||
            !long.TryParse(
                membershipValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var membershipId))
        {
            return Results.Forbid();
        }

        var requestedLimit = limit ?? 50;
        if (requestedLimit is < 1 or > 100)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["limit"] = ["Limit 1 ile 100 arasında olmalıdır."],
            });
        }

        var workItems = await query.GetMineAsync(
            userId,
            municipalityId,
            membershipId,
            requestedLimit,
            cancellationToken);
        return Results.Ok(workItems);
    }
}
