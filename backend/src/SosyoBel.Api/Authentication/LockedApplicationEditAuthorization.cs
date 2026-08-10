using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Authentication;

internal sealed class LockedApplicationEditRequirement : IAuthorizationRequirement;

/// <summary>
/// Kilitli başvuru düzenleme izni kısa ömürlü token claim'ine güvenmez; her
/// istekte üyelik ve özel izin veritabanından yeniden doğrulanır.
/// </summary>
internal sealed class LockedApplicationEditAuthorizationHandler(
    IAccessPermissionChecker permissionChecker)
    : AuthorizationHandler<LockedApplicationEditRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        LockedApplicationEditRequirement requirement)
    {
        var userId = context.User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var municipalityIdValue = context.User.FindFirstValue(
            CustomClaimTypes.MunicipalityId);
        var membershipIdValue = context.User.FindFirstValue(
            CustomClaimTypes.MunicipalityMembershipId);

        if (string.IsNullOrWhiteSpace(userId) ||
            !int.TryParse(
                municipalityIdValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var municipalityId) ||
            !long.TryParse(
                membershipIdValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var membershipId))
        {
            return;
        }

        var cancellationToken = context.Resource is HttpContext httpContext
            ? httpContext.RequestAborted
            : CancellationToken.None;
        if (await permissionChecker.HasPermissionAsync(
                userId,
                membershipId,
                municipalityId,
                PermissionCodes.LockedApplicationEdit,
                cancellationToken))
        {
            context.Succeed(requirement);
        }
    }
}
