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
                "Oturumdaki kullanıcının dbo.Basvurular kayıtları ile dbo.SahaAktiviteleri üzerinden atanmış " +
                "görevlerini tek listede döndürür. " +
                "limit değeri 1-100 arasındadır ve varsayılanı 50'dir.")
            .RequireAuthorization(AuthorizationPolicyNames.MobileFieldOperations);

        return endpoints;
    }

    private static async Task<IResult> GetMineAsync(
        int? limit,
        ClaimsPrincipal principal,
        IUserWorkItemQuery query,
        CancellationToken cancellationToken)
    {
        var userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub);
        if (string.IsNullOrWhiteSpace(userId))
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
            requestedLimit,
            cancellationToken);
        return Results.Ok(workItems);
    }
}
