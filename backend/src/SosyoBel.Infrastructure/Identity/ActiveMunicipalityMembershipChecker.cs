using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

internal sealed class ActiveMunicipalityMembershipChecker(
    AuthenticationDbContext dbContext) : IActiveMunicipalityMembershipChecker
{
    public Task<bool> HasActiveRoleAsync(
        string userId,
        long municipalityMembershipId,
        int municipalityId,
        string requiredRoleCode,
        CancellationToken cancellationToken)
    {
        if (!RoleCodes.IsMunicipalityRole(requiredRoleCode))
        {
            return Task.FromResult(false);
        }

        return (
            from membership in dbContext.UserMunicipalities.AsNoTracking()
            join municipality in dbContext.Municipalities.AsNoTracking()
                on membership.MunicipalityId equals municipality.Id
            join user in dbContext.Users.AsNoTracking()
                on membership.UserId equals user.Id
            where membership.Id == municipalityMembershipId &&
                  membership.UserId == userId &&
                  membership.MunicipalityId == municipalityId &&
                  membership.RoleCode == requiredRoleCode &&
                  membership.IsActive &&
                  municipality.IsActive &&
                  user.IsActive
            select membership.Id)
            .AnyAsync(cancellationToken);
    }
}
