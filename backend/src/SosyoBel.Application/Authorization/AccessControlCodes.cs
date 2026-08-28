namespace SosyoBel.Application.Authorization;

/// <summary>
/// Şirketin mevcut dbo.AspNetRoles tablosunda kullandığı rol adlarıdır.
/// Mobil API yeni rol veya belediye üyeliği oluşturmaz.
/// </summary>
public static class CompanyIdentityRoleCodes
{
    public const string Administrator = "Admin";
    public const string Board = "Kurul";
    public const string Personnel = "Personel";

    public static bool GrantsMobileFieldAccess(string? role) =>
        string.Equals(role, Administrator, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(role, Board, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(role, Personnel, StringComparison.OrdinalIgnoreCase);
}

public static class AuthorizationPolicyNames
{
    public const string MobileFieldOperations = "sosyobel.mobile-field-operations";
}
