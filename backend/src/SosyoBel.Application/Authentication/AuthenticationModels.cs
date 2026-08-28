namespace SosyoBel.Application.Authentication;

/// <summary>
/// Oturum açan mevcut ASP.NET Identity kullanıcısının mobil istemciye
/// döndürülen profilidir. E-posta, şirketin mevcut hesaplarında boş olabildiği
/// için zorunlu değildir; giriş anahtarı kullanıcı adıdır.
/// </summary>
public sealed record AuthenticatedUserProfile(
    string UserId,
    string Username,
    string? Email,
    string DisplayName,
    IReadOnlyCollection<string> Roles);

public sealed record AuthenticationSession(
    string AccessToken,
    DateTime AccessTokenExpiresAtUtc,
    string RefreshToken,
    DateTime RefreshTokenExpiresAtUtc,
    AuthenticatedUserProfile User);

public sealed record AuthenticationResult(
    AuthenticationStatus Status,
    AuthenticationSession? Session = null);

public sealed record LoginInput(
    string Username,
    string Password,
    string? DeviceId,
    string? IpAddress);

public sealed record RefreshInput(
    string RefreshToken,
    string? DeviceId,
    string? IpAddress);

public sealed record LogoutInput(string RefreshToken, string? IpAddress);

public sealed record AccessTokenSubject(
    string UserId,
    string Username,
    string? Email,
    string DisplayName,
    IReadOnlyCollection<string> Roles);

public sealed record IssuedAccessToken(string Value, DateTime ExpiresAtUtc);
