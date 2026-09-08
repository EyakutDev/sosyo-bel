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
        endpoints.MapGet("/api/v1/work-items", GetVisibleAsync)
            .WithTags("İş Listesi")
            .WithSummary("Yetkili personelin görebildiği iş listesini getirir")
            .WithDescription(
                "Kullanıcının kendi tüm dbo.Basvurular kayıtlarını, diğer kullanıcıların yalnız Beklemede " +
                "durumundaki başvurularını ve kendisine atanmış dbo.SahaAktiviteleri görevlerini döndürür. " +
                "Başkasına ait sonuçlanmış başvurular listeye alınmaz. Her başvuruda dbo kimliği, sahiplik " +
                "ve düzenlenebilirlik bilgisi bulunur.")
            .Produces<IReadOnlyCollection<UserWorkItemSummary>>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .RequireAuthorization(AuthorizationPolicyNames.MobileFieldOperations);

        endpoints.MapGet("/api/v1/work-items/mine", GetMineAsync)
            .WithTags("İş Listesi")
            .WithSummary("Personelin bekleyen ve tamamlanan işlerini getirir")
            .WithDescription(
                "Oturumdaki kullanıcının dbo.Basvurular kayıtları ile dbo.SahaAktiviteleri üzerinden atanmış " +
                "görevlerini tek listede döndürür. " +
                "limit değeri 1-100 arasındadır ve varsayılanı 50'dir.")
            .Produces<IReadOnlyCollection<UserWorkItemSummary>>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .RequireAuthorization(AuthorizationPolicyNames.MobileFieldOperations);

        return endpoints;
    }

    private static async Task<IResult> GetVisibleAsync(
        int? limit,
        ClaimsPrincipal principal,
        IUserWorkItemQuery query,
        CancellationToken cancellationToken)
    {
        var request = ReadRequest(limit, principal);
        if (request.Error is not null) return request.Error;

        var workItems = await query.GetVisibleAsync(
            request.UserId!,
            request.Limit,
            cancellationToken);
        return Results.Ok(workItems);
    }

    private static async Task<IResult> GetMineAsync(
        int? limit,
        ClaimsPrincipal principal,
        IUserWorkItemQuery query,
        CancellationToken cancellationToken)
    {
        var request = ReadRequest(limit, principal);
        if (request.Error is not null) return request.Error;

        var workItems = await query.GetMineAsync(
            request.UserId!,
            request.Limit,
            cancellationToken);
        return Results.Ok(workItems);
    }

    private static WorkItemListRequest ReadRequest(
        int? limit,
        ClaimsPrincipal principal)
    {
        var userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub);
        if (string.IsNullOrWhiteSpace(userId))
        {
            return new(null, 0, Results.Forbid());
        }

        var requestedLimit = limit ?? 50;
        if (requestedLimit is < 1 or > 100)
        {
            return new(
                null,
                0,
                Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["limit"] = ["Limit 1 ile 100 arasında olmalıdır."],
                }));
        }

        return new(userId, requestedLimit, null);
    }

    private sealed record WorkItemListRequest(
        string? UserId,
        int Limit,
        IResult? Error);
}
