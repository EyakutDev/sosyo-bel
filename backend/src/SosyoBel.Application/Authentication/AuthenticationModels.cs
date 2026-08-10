namespace SosyoBel.Application.Authentication;

public sealed record MunicipalityOption(string Code, string Name);

/// <summary>
/// Sistem yöneticisinin belediye kapsamı olmadığı için belediye alanları nullable'dır.
/// Belediye kullanıcılarında üyelik kimliği token ile sunucu tarafında doğrulanır.
/// </summary>
public sealed record AuthenticatedUserProfile(
    string UserId,
    string Email,
    string DisplayName,
    string? MunicipalityCode,
    string? MunicipalityName,
    long? MunicipalityMembershipId,
    IReadOnlyCollection<string> Roles);

public sealed record AuthenticationSession(
    string AccessToken,
    DateTime AccessTokenExpiresAtUtc,
    string RefreshToken,
    DateTime RefreshTokenExpiresAtUtc,
    AuthenticatedUserProfile User);

public sealed record AuthenticationResult(
    AuthenticationStatus Status,
    AuthenticationSession? Session = null,
    IReadOnlyCollection<MunicipalityOption>? Municipalities = null);

public sealed record LoginInput(
    string Email,
    string Password,
    string? MunicipalityCode,
    string? DeviceId,
    string? IpAddress);

public sealed record RefreshInput(
    string RefreshToken,
    string? MunicipalityCode,
    string? DeviceId,
    string? IpAddress);

public sealed record LogoutInput(string RefreshToken, string? IpAddress);

public sealed record AccessTokenSubject(
    string UserId,
    string Email,
    string DisplayName,
    int? MunicipalityId,
    string? MunicipalityCode,
    long? MunicipalityMembershipId,
    IReadOnlyCollection<string> Roles);

public sealed record IssuedAccessToken(string Value, DateTime ExpiresAtUtc);
