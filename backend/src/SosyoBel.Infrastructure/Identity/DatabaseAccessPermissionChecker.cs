using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

internal sealed class DatabaseAccessPermissionChecker(
    AuthenticationDbContext dbContext) : IAccessPermissionChecker
{
    public Task<bool> HasPermissionAsync(
        string userId,
        long municipalityMembershipId,
        int municipalityId,
        string permissionCode,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        ArgumentException.ThrowIfNullOrWhiteSpace(permissionCode);

        // Token yalnız kapsam anahtarlarını taşır; aktiflik ve özel izin güncel
        // veritabanı kayıtlarından aynı sorguda doğrulanır.
        return (
            from permission in dbContext.UserPermissions.AsNoTracking()
            join membership in dbContext.UserMunicipalities.AsNoTracking()
                on new { permission.UserId, permission.MunicipalityId }
                equals new { membership.UserId, membership.MunicipalityId }
            join municipality in dbContext.Municipalities.AsNoTracking()
                on membership.MunicipalityId equals municipality.Id
            join userInfo in dbContext.UserApplicationInfos.AsNoTracking()
                on membership.UserId equals userInfo.UserId
            where permission.UserId == userId &&
                  permission.MunicipalityId == municipalityId &&
                  permission.PermissionCode == permissionCode &&
                  permission.IsActive &&
                  membership.Id == municipalityMembershipId &&
                  membership.IsActive &&
                  municipality.IsActive &&
                  userInfo.IsActive
            select permission.Id)
            .AnyAsync(cancellationToken);
    }
}
