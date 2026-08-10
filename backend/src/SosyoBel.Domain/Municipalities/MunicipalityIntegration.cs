namespace SosyoBel.Domain.Municipalities;

/// <summary>
/// Bir belediyeye ait veri kaynağının gizli olmayan bağlantı tanımıdır.
/// Parola veya API anahtarı yerine yalnız secret kasasındaki kaydın referansı tutulur.
/// </summary>
public sealed class MunicipalityIntegration
{
    private MunicipalityIntegration()
    {
    }

    private MunicipalityIntegration(
        int municipalityId,
        string name,
        MunicipalityIntegrationType type,
        MunicipalityIntegrationAccessScope accessScope)
    {
        if (municipalityId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        }

        PublicId = Guid.NewGuid();
        MunicipalityId = municipalityId;
        Name = NormalizeRequired(name, nameof(name), 150);
        Type = type;
        AccessScope = accessScope;
        ConnectionTimeoutSeconds = 30;
        RetryCount = 3;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public int Id { get; private set; }

    public Guid PublicId { get; private set; }

    public int MunicipalityId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public MunicipalityIntegrationType Type { get; private set; }

    public MunicipalityIntegrationAccessScope AccessScope { get; private set; }

    public MunicipalityAuthenticationType? AuthenticationType { get; private set; }

    public string? ServerAddress { get; private set; }

    public int? Port { get; private set; }

    public string? DatabaseName { get; private set; }

    public string? ApiBaseUrl { get; private set; }

    public string? SecretReference { get; private set; }

    public string? AdditionalSettingsJson { get; private set; }

    public short ConnectionTimeoutSeconds { get; private set; }

    public byte RetryCount { get; private set; }

    public bool IsActive { get; private set; }

    public DateTime? LastSuccessfulConnectionUtc { get; private set; }

    public string? LastErrorCode { get; private set; }

    public string? CreatedByUserId { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public string? UpdatedByUserId { get; private set; }

    public DateTime? UpdatedAtUtc { get; private set; }

    public byte[] RowVersion { get; private set; } = [];

    public static MunicipalityIntegration Create(
        int municipalityId,
        string name,
        MunicipalityIntegrationType type,
        MunicipalityIntegrationAccessScope accessScope) =>
        new(municipalityId, name, type, accessScope);

    public void ConfigureSqlServer(
        string serverAddress,
        int port,
        string databaseName,
        string secretReference,
        MunicipalityAuthenticationType authenticationType)
    {
        if (Type is not MunicipalityIntegrationType.SqlServer)
        {
            throw new InvalidOperationException("Yalnız SQL Server entegrasyonu SQL bağlantısıyla yapılandırılabilir.");
        }

        if (port is < 1 or > 65535)
        {
            throw new ArgumentOutOfRangeException(nameof(port));
        }

        ServerAddress = NormalizeRequired(serverAddress, nameof(serverAddress), 255);
        Port = port;
        DatabaseName = NormalizeRequired(databaseName, nameof(databaseName), 128);
        SecretReference = NormalizeSecretReference(secretReference);
        AuthenticationType = authenticationType;
        ApiBaseUrl = null;
        Touch();
    }

    public void ConfigureRestApi(
        Uri baseUrl,
        string secretReference,
        MunicipalityAuthenticationType authenticationType)
    {
        ArgumentNullException.ThrowIfNull(baseUrl);
        if (Type is not MunicipalityIntegrationType.RestApi)
        {
            throw new InvalidOperationException("Yalnız REST API entegrasyonu URL ile yapılandırılabilir.");
        }

        if (!baseUrl.IsAbsoluteUri || baseUrl.Scheme != Uri.UriSchemeHttps)
        {
            throw new ArgumentException("REST API adresi mutlak bir HTTPS adresi olmalıdır.", nameof(baseUrl));
        }

        ApiBaseUrl = NormalizeRequired(baseUrl.ToString().TrimEnd('/'), nameof(baseUrl), 500);
        SecretReference = NormalizeSecretReference(secretReference);
        AuthenticationType = authenticationType;
        ServerAddress = null;
        Port = null;
        DatabaseName = null;
        Touch();
    }

    public void SetResilience(short timeoutSeconds, byte retryCount)
    {
        if (timeoutSeconds is < 1 or > 120)
        {
            throw new ArgumentOutOfRangeException(nameof(timeoutSeconds));
        }

        if (retryCount > 10)
        {
            throw new ArgumentOutOfRangeException(nameof(retryCount));
        }

        ConnectionTimeoutSeconds = timeoutSeconds;
        RetryCount = retryCount;
        Touch();
    }

    public void Activate()
    {
        ValidateActiveConfiguration();
        IsActive = true;
        Touch();
    }

    public void Deactivate()
    {
        IsActive = false;
        Touch();
    }

    private void ValidateActiveConfiguration()
    {
        if (Type is MunicipalityIntegrationType.SqlServer &&
            (string.IsNullOrWhiteSpace(ServerAddress) || Port is null ||
             string.IsNullOrWhiteSpace(DatabaseName) || string.IsNullOrWhiteSpace(SecretReference)))
        {
            throw new InvalidOperationException("SQL Server entegrasyonu aktif edilmeden önce bağlantı ayarları tamamlanmalıdır.");
        }

        if (Type is MunicipalityIntegrationType.RestApi &&
            (string.IsNullOrWhiteSpace(ApiBaseUrl) || string.IsNullOrWhiteSpace(SecretReference)))
        {
            throw new InvalidOperationException("REST API entegrasyonu aktif edilmeden önce URL ve secret referansı tamamlanmalıdır.");
        }
    }

    private void Touch() => UpdatedAtUtc = DateTime.UtcNow;

    private static string NormalizeSecretReference(string value)
    {
        var normalized = NormalizeRequired(value, nameof(value), 300);
        if (!normalized.StartsWith("env://", StringComparison.OrdinalIgnoreCase) &&
            !normalized.StartsWith("vault://", StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException(
                "Secret referansı env:// veya vault:// ile başlamalıdır.",
                nameof(value));
        }

        return normalized;
    }

    private static string NormalizeRequired(string value, string parameterName, int maxLength)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value, parameterName);

        var normalized = value.Trim();
        if (normalized.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(
                parameterName,
                $"Değer en fazla {maxLength} karakter olabilir.");
        }

        return normalized;
    }
}
