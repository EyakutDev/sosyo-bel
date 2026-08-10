using SosyoBel.Domain.Municipalities;

namespace SosyoBel.Application.Municipalities;

/// <summary>
/// Bağlantıyı kuracak adapter'a verilen gizli olmayan çalışma tanımıdır.
/// Secret değeri yalnız ISecretResolver üzerinden işlem anında alınır.
/// </summary>
public sealed record MunicipalityIntegrationDescriptor(
    int MunicipalityId,
    MunicipalityIntegrationType Type,
    MunicipalityIntegrationAccessScope AccessScope,
    string? ServerAddress,
    int? Port,
    string? DatabaseName,
    Uri? ApiBaseUrl,
    string? SecretReference,
    short ConnectionTimeoutSeconds,
    byte RetryCount);
