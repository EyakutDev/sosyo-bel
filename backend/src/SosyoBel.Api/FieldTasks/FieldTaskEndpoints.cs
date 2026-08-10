using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.FieldTasks;

namespace SosyoBel.Api.FieldTasks;

internal static class FieldTaskEndpoints
{
    public static IEndpointRouteBuilder MapFieldTaskEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/tasks/assigned", GetAssignedAsync)
            .WithTags("Saha Görevleri")
            .WithSummary("Personele atanmış saha görevlerini getirir")
            .WithDescription(
                "Oturum açmış personele, aktif belediye üyeliği kapsamında atanmış görevleri döndürür. " +
                "limit değeri 1-100 arasındadır ve varsayılanı 50'dir.")
            .RequireAuthorization(AuthorizationPolicyNames.Personnel);

        return endpoints;
    }

    private static async Task<IResult> GetAssignedAsync(
        int? limit,
        ClaimsPrincipal principal,
        IAssignedFieldTaskQuery query,
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

        var tasks = await query.GetAssignedAsync(
            userId,
            municipalityId,
            membershipId,
            requestedLimit,
            cancellationToken);
        return Results.Ok(tasks);
    }
}
