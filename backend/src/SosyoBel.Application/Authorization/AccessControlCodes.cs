namespace SosyoBel.Application.Authorization;

/// <summary>
/// Kalıcı rol kodlarıdır. Belediye rolleri Identity rolü olarak değil,
/// KullaniciBelediyeleri kaydında tutulur.
/// </summary>
public static class RoleCodes
{
    public const string SystemAdministrator = "SISTEM_YONETICISI";
    public const string MunicipalityAdministrator = "BELEDIYE_YONETICISI";
    public const string Personnel = "PERSONEL";

    public static bool IsMunicipalityRole(string? roleCode) =>
        string.Equals(roleCode, MunicipalityAdministrator, StringComparison.Ordinal) ||
        string.Equals(roleCode, Personnel, StringComparison.Ordinal);
}

public static class PermissionCodes
{
    public const string LockedApplicationEdit = "KILITLI_BASVURU_DUZENLE";
    public const string KpsLookup = "KPS_SORGULA";
}

/// <summary>
/// API ile token üreticisinin aynı claim adlarını kullanmasını sağlar.
/// </summary>
public static class CustomClaimTypes
{
    public const string MunicipalityId = "municipality_id";
    public const string MunicipalityCode = "municipality_code";
    public const string MunicipalityMembershipId = "municipality_membership_id";
}

public static class AuthorizationPolicyNames
{
    public const string SystemAdministrator = "sosyobel.system-administrator";
    public const string MunicipalityAdministrator = "sosyobel.municipality-administrator";
    public const string Personnel = "sosyobel.personnel";
    public const string LockedApplicationEdit = "sosyobel.locked-application-edit";
}
