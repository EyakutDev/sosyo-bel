using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// Kurumun KPS kimlik ve adres uçlarına body içermeyen GET istekleri gönderir.
/// Query parametreleri yalnız bu sınıfta üretilir ve loglanmaz.
/// </summary>
internal sealed class KpsClient : IKpsClient, IDisposable
{
    private const string IdentityPath = "api/kps/sorgula";
    private const string AddressPath = "api/kpsadres/sorgula";
    private readonly HttpClient httpClient;
    private readonly Uri baseUri;

    public KpsClient(Microsoft.Extensions.Options.IOptions<KpsOptions> options)
        : this(options.Value)
    {
    }

    internal KpsClient(KpsOptions options, HttpMessageHandler? messageHandler = null)
    {
        ArgumentNullException.ThrowIfNull(options);
        baseUri = ValidateAndNormalizeBaseUri(options.BaseUrl);
        if (options.TimeoutSeconds is < 1 or > 120)
        {
            throw new InvalidOperationException(
                "Kps:TimeoutSeconds 1 ile 120 saniye arasında olmalıdır.");
        }

        var handler = messageHandler ?? new SocketsHttpHandler
        {
            // Uzun yaşayan istemci DNS değişikliklerini düzenli olarak yeniler.
            PooledConnectionLifetime = TimeSpan.FromMinutes(5),
            AutomaticDecompression = DecompressionMethods.GZip |
                                     DecompressionMethods.Deflate,
            AllowAutoRedirect = false,
        };
        httpClient = new HttpClient(handler, disposeHandler: true)
        {
            Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds),
        };
        httpClient.DefaultRequestHeaders.Accept.Add(
            new MediaTypeWithQualityHeaderValue("application/json"));
    }

    public async Task<KpsIdentityInformation> GetIdentityAsync(
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken)
    {
        var normalized = NormalizeCriteria(criteria);
        var json = await GetJsonAsync(IdentityPath, normalized, cancellationToken);
        return KpsResponseReader.ReadIdentity(json, normalized.IdentityNumber);
    }

    public async Task<KpsAddressInformation> GetAddressAsync(
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken)
    {
        var normalized = NormalizeCriteria(criteria);
        var json = await GetJsonAsync(AddressPath, normalized, cancellationToken);
        return KpsResponseReader.ReadAddress(json, normalized.IdentityNumber);
    }

    private async Task<string> GetJsonAsync(
        string relativePath,
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Get,
            BuildRequestUri(relativePath, criteria));

        try
        {
            using var response = await httpClient.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                throw new KpsClientException(
                    "KPS_HTTP_HATASI",
                    "KPS servisi isteği başarılı olarak sonuçlandırmadı.",
                    response.StatusCode);
            }

            return await response.Content.ReadAsStringAsync(cancellationToken);
        }
        catch (OperationCanceledException error)
            when (!cancellationToken.IsCancellationRequested)
        {
            throw new KpsClientException(
                "KPS_ZAMAN_ASIMI",
                "KPS servisi zamanında yanıt vermedi.",
                innerException: error);
        }
        catch (HttpRequestException error)
        {
            throw new KpsClientException(
                "KPS_ERISILEMIYOR",
                "KPS servisine ulaşılamadı.",
                error.StatusCode,
                error);
        }
    }

    private Uri BuildRequestUri(string path, KpsLookupCriteria criteria)
    {
        var query = string.Format(
            CultureInfo.InvariantCulture,
            "tcKimlikNo={0}&dogumYil={1}&dogumAy={2}&dogumGun={3}",
            Uri.EscapeDataString(criteria.IdentityNumber),
            criteria.BirthDate.Year,
            criteria.BirthDate.Month,
            criteria.BirthDate.Day);
        return new Uri(baseUri, $"{path}?{query}");
    }

    private static KpsLookupCriteria NormalizeCriteria(KpsLookupCriteria criteria)
    {
        ArgumentNullException.ThrowIfNull(criteria);
        var identityNumber = criteria.IdentityNumber?.Trim() ?? string.Empty;
        if (identityNumber.Length != 11 ||
            identityNumber.Any(value => !char.IsAsciiDigit(value)))
        {
            throw new ArgumentException(
                "T.C. kimlik numarası 11 rakam olmalıdır.",
                nameof(criteria));
        }

        return criteria with { IdentityNumber = identityNumber };
    }

    private static Uri ValidateAndNormalizeBaseUri(string value)
    {
        if (!Uri.TryCreate(value?.Trim(), UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps) ||
            !string.IsNullOrEmpty(uri.Query) ||
            !string.IsNullOrEmpty(uri.Fragment) ||
            !string.IsNullOrEmpty(uri.UserInfo))
        {
            throw new InvalidOperationException(
                "Kps:BaseUrl query, fragment veya kullanıcı bilgisi içermeyen mutlak HTTP/HTTPS adresi olmalıdır.");
        }

        return new Uri(uri.ToString().TrimEnd('/') + "/", UriKind.Absolute);
    }

    public void Dispose() => httpClient.Dispose();
}
