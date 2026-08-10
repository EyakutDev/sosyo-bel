using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Authentication;

internal sealed record ActiveMunicipalityMembershipRequirement(string RoleCode)
    : IAuthorizationRequirement;

/// <summary>
/// Access token geçerli olsa bile kullanıcı, belediye veya üyelik kapatılmışsa
/// belediye endpoint'lerine erişimi anında keser.
/// </summary>
internal sealed class ActiveMunicipalityMembershipAuthorizationHandler(
    IActiveMunicipalityMembershipChecker membershipChecker)
    : AuthorizationHandler<ActiveMunicipalityMembershipRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ActiveMunicipalityMembershipRequirement requirement)
    {
        var userId = context.User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var municipalityValue = context.User.FindFirstValue(
            CustomClaimTypes.MunicipalityId);
        var membershipValue = context.User.FindFirstValue(
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
            return;
        }

        var cancellationToken = context.Resource is HttpContext httpContext
            ? httpContext.RequestAborted
            : CancellationToken.None;
        if (await membershipChecker.HasActiveRoleAsync(
                userId,
                membershipId,
                municipalityId,
                requirement.RoleCode,
                cancellationToken))
        {
            context.Succeed(requirement);
        }
    }
}
