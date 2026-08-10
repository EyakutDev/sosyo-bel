using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Kritik ve geri alınabilir yetki kaydıdır. Yetki JWT'ye gömülmez; her kritik
/// işlem öncesinde bu kaydın güncel durumu doğrulanır.
/// </summary>
internal sealed class UserPermissionRecord
{
    private UserPermissionRecord()
    {
    }

    public long Id { get; private set; }

    public string UserId { get; private set; } = string.Empty;

    public int MunicipalityId { get; private set; }

    public string PermissionCode { get; private set; } = string.Empty;

    public bool IsActive { get; private set; }

    public string GrantedByUserId { get; private set; } = string.Empty;

    public DateTime GrantedAtUtc { get; private set; }

    public string? RevokedByUserId { get; private set; }

    public DateTime? RevokedAtUtc { get; private set; }

    public byte[] RowVersion { get; private set; } = [];

    public static UserPermissionRecord Create(
        string userId,
        int municipalityId,
        string permissionCode,
        string grantedByUserId,
        DateTime grantedAtUtc)
    {
        var record = new UserPermissionRecord
        {
            UserId = NormalizeUserId(userId, nameof(userId)),
            MunicipalityId = municipalityId > 0
                ? municipalityId
                : throw new ArgumentOutOfRangeException(nameof(municipalityId)),
            PermissionCode = NormalizePermission(permissionCode),
        };
        record.Grant(grantedByUserId, grantedAtUtc);
        return record;
    }

    public void Grant(string grantedByUserId, DateTime grantedAtUtc)
    {
        IsActive = true;
        GrantedByUserId = NormalizeUserId(grantedByUserId, nameof(grantedByUserId));
        GrantedAtUtc = DateTime.SpecifyKind(grantedAtUtc, DateTimeKind.Utc);
        RevokedByUserId = null;
        RevokedAtUtc = null;
    }

    public void Revoke(string revokedByUserId, DateTime revokedAtUtc)
    {
        if (!IsActive)
        {
            return;
        }

        IsActive = false;
        RevokedByUserId = NormalizeUserId(revokedByUserId, nameof(revokedByUserId));
        RevokedAtUtc = DateTime.SpecifyKind(revokedAtUtc, DateTimeKind.Utc);
    }

    private static string NormalizePermission(string permissionCode)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(permissionCode);
        if (!string.Equals(
                permissionCode,
                PermissionCodes.LockedApplicationEdit,
                StringComparison.Ordinal))
        {
            throw new ArgumentOutOfRangeException(nameof(permissionCode));
        }

        return permissionCode;
    }

    private static string NormalizeUserId(string value, string parameterName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value, parameterName);
        var normalized = value.Trim();
        if (normalized.Length > 128)
        {
            throw new ArgumentOutOfRangeException(parameterName);
        }

        return normalized;
    }
}
