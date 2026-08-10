using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Authentication;

internal sealed class ActiveSystemAdministratorRequirement : IAuthorizationRequirement;

internal sealed class ActiveSystemAdministratorAuthorizationHandler(
    IActiveSystemAdministratorChecker checker)
    : AuthorizationHandler<ActiveSystemAdministratorRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ActiveSystemAdministratorRequirement requirement)
    {
        var userId = context.User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        var cancellationToken = context.Resource is HttpContext httpContext
            ? httpContext.RequestAborted
            : CancellationToken.None;
        if (await checker.IsActiveAsync(userId, cancellationToken))
        {
            context.Succeed(requirement);
        }
    }
}
