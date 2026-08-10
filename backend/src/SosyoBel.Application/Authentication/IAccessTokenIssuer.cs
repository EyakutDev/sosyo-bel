namespace SosyoBel.Application.Authentication;

/// <summary>
/// Token biçimini Application katmanından ayırır; ileride harici OIDC sağlayıcısına
/// geçilirse giriş iş akışı değiştirilmeden yeni üretici bağlanabilir.
/// </summary>
public interface IAccessTokenIssuer
{
    IssuedAccessToken Issue(AccessTokenSubject subject);
}
