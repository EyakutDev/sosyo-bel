using SosyoBel.Domain.Municipalities;

namespace SosyoBel.Infrastructure.Persistence;

internal static class MunicipalityIntegrationCodes
{
    public static string ToCode(MunicipalityIntegrationType value) => value switch
    {
        MunicipalityIntegrationType.SqlServer => "SQL_SERVER",
        MunicipalityIntegrationType.RestApi => "REST_API",
        MunicipalityIntegrationType.Csv => "CSV",
        MunicipalityIntegrationType.Demo => "DEMO",
        _ => throw new ArgumentOutOfRangeException(nameof(value), value, null),
    };

    public static MunicipalityIntegrationType ParseType(string value) => value switch
    {
        "SQL_SERVER" => MunicipalityIntegrationType.SqlServer,
        "REST_API" => MunicipalityIntegrationType.RestApi,
        "CSV" => MunicipalityIntegrationType.Csv,
        "DEMO" => MunicipalityIntegrationType.Demo,
        _ => throw new InvalidOperationException($"Bilinmeyen entegrasyon türü kodu: {value}"),
    };

    public static string ToCode(MunicipalityIntegrationAccessScope value) => value switch
    {
        MunicipalityIntegrationAccessScope.ReadOnly => "OKUMA",
        MunicipalityIntegrationAccessScope.ReadWrite => "OKUMA_YAZMA",
        _ => throw new ArgumentOutOfRangeException(nameof(value), value, null),
    };

    public static MunicipalityIntegrationAccessScope ParseAccessScope(string value) => value switch
    {
        "OKUMA" => MunicipalityIntegrationAccessScope.ReadOnly,
        "OKUMA_YAZMA" => MunicipalityIntegrationAccessScope.ReadWrite,
        _ => throw new InvalidOperationException($"Bilinmeyen yetki kapsamı kodu: {value}"),
    };

    public static string? ToCode(MunicipalityAuthenticationType? value) => value switch
    {
        null => null,
        MunicipalityAuthenticationType.None => "YOK",
        MunicipalityAuthenticationType.SqlAccount => "SQL_HESABI",
        MunicipalityAuthenticationType.WindowsActiveDirectory => "WINDOWS_AD",
        MunicipalityAuthenticationType.OAuth2 => "OAUTH2",
        MunicipalityAuthenticationType.ApiKey => "API_KEY",
        MunicipalityAuthenticationType.MutualTls => "MTLS",
        _ => throw new ArgumentOutOfRangeException(nameof(value), value, null),
    };

    public static MunicipalityAuthenticationType? ParseAuthenticationType(string? value) => value switch
    {
        null => null,
        "YOK" => MunicipalityAuthenticationType.None,
        "SQL_HESABI" => MunicipalityAuthenticationType.SqlAccount,
        "WINDOWS_AD" => MunicipalityAuthenticationType.WindowsActiveDirectory,
        "OAUTH2" => MunicipalityAuthenticationType.OAuth2,
        "API_KEY" => MunicipalityAuthenticationType.ApiKey,
        "MTLS" => MunicipalityAuthenticationType.MutualTls,
        _ => throw new InvalidOperationException($"Bilinmeyen kimlik doğrulama kodu: {value}"),
    };
}
