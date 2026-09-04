using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Net.Http.Headers;
using System.Text.Json.Serialization;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// Kurumun KPS kimlik ve adres uçlarına JSON gövdeli POST istekleri gönderir.
/// Hassas sorgu değerleri URL'ye eklenmez ve bu sınıf tarafından loglanmaz.
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
        var json = await PostJsonAsync(IdentityPath, normalized, cancellationToken);
        return KpsResponseReader.ReadIdentity(json, normalized.IdentityNumber);
    }

    public async Task<KpsAddressInformation> GetAddressAsync(
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken)
    {
        var normalized = NormalizeCriteria(criteria);
        var json = await PostJsonAsync(AddressPath, normalized, cancellationToken);
        return KpsResponseReader.ReadAddress(json, normalized.IdentityNumber);
    }

    private async Task<string> PostJsonAsync(
        string relativePath,
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri(baseUri, relativePath))
        {
            // KPS sözleşmesi T.C. kimlik numarasını JSON number olarak bekler.
            Content = JsonContent.Create(CreateRequestPayload(criteria)),
        };

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

    private static KpsRequestPayload CreateRequestPayload(KpsLookupCriteria criteria) =>
        new(
            long.Parse(criteria.IdentityNumber, CultureInfo.InvariantCulture),
            criteria.BirthDate.Year,
            criteria.BirthDate.Month,
            criteria.BirthDate.Day);

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

    private sealed record KpsRequestPayload(
        [property: JsonPropertyName("tcKimlikNo")] long IdentityNumber,
        [property: JsonPropertyName("dogumYil")] int BirthYear,
        [property: JsonPropertyName("dogumAy")] int BirthMonth,
        [property: JsonPropertyName("dogumGun")] int BirthDay);

    public void Dispose() => httpClient.Dispose();
}
