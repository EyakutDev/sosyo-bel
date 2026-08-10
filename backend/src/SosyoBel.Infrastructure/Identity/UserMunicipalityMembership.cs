using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Kullanıcının tek bir belediyedeki rolünü temsil eder. Rolün üyelik üzerinde
/// tutulması, başka bir belediyeye yanlışlıkla yetki taşınmasını önler.
/// </summary>
internal sealed class UserMunicipalityMembership
{
    private UserMunicipalityMembership()
    {
    }

    public long Id { get; private set; }

    public string UserId { get; private set; } = string.Empty;

    public int MunicipalityId { get; private set; }

    public string RoleCode { get; private set; } = string.Empty;

    public bool IsActive { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public static UserMunicipalityMembership Create(
        string userId,
        int municipalityId,
        string roleCode,
        DateTime createdAtUtc)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (userId.Trim().Length > 128)
        {
            throw new ArgumentOutOfRangeException(nameof(userId));
        }

        if (municipalityId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        }

        if (!RoleCodes.IsMunicipalityRole(roleCode))
        {
            throw new ArgumentOutOfRangeException(nameof(roleCode));
        }

        return new UserMunicipalityMembership
        {
            UserId = userId.Trim(),
            MunicipalityId = municipalityId,
            RoleCode = roleCode,
            IsActive = true,
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
        };
    }

    public void Deactivate() => IsActive = false;
}