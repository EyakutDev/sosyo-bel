namespace SosyoBel.Application.Authorization;

/// <summary>
/// Uzun ömürlü JWT'ye özel yetki gömmek yerine, kritik işlemlerde güncel
/// üyelik ve yetki kaydını veritabanından doğrular.
/// </summary>
public interface IAccessPermissionChecker
{
    Task<bool> HasPermissionAsync(
        string userId,
        long municipalityMembershipId,
        int municipalityId,
        string permissionCode,
        CancellationToken cancellationToken);
}
