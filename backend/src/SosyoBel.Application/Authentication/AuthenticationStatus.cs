namespace SosyoBel.Application.Authentication;

/// <summary>
/// API'nin altyapı hata ayrıntılarını açığa çıkarmadan yanıt üretebilmesini sağlar.
/// </summary>
public enum AuthenticationStatus
{
    Succeeded,
    InvalidCredentials,
    LockedOut,
    AccessDenied,
    MunicipalitySelectionRequired,
    InvalidRefreshToken,
    RefreshTokenReuseDetected,
}
