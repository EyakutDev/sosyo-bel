using Microsoft.AspNetCore.Identity;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

internal sealed class ActiveSystemAdministratorChecker(
    UserManager<ApplicationUser> userManager) : IActiveSystemAdministratorChecker
{
    public async Task<bool> IsActiveAsync(
        string userId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var user = await userManager.FindByIdAsync(userId);
        return user is not null &&
               user.IsActive &&
               await userManager.IsInRoleAsync(user, RoleCodes.SystemAdministrator);
    }
}
