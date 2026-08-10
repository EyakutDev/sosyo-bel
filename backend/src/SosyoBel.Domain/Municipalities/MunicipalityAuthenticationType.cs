namespace SosyoBel.Domain.Municipalities;

public enum MunicipalityAuthenticationType
{
    None,
    SqlAccount,
    WindowsActiveDirectory,
    OAuth2,
    ApiKey,
    MutualTls,
}
