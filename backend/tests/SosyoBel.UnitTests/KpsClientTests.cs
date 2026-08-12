using System.Net;
using System.Text;
using SosyoBel.Application.Kps;
using SosyoBel.Infrastructure.Kps;

namespace SosyoBel.UnitTests;

public sealed class KpsClientTests
{
    private const string SyntheticIdentityNumber = "12345678901";

    [Fact]
    public async Task IdentityAndAddressCallsUseGetQueryWithoutBody()
    {
        var handler = new RecordingHandler(
            IdentityJson(),
            AddressJson());
        using var client = new KpsClient(
            new KpsOptions
            {
                BaseUrl = "http://kps.test.local:8090/",
                TimeoutSeconds = 30,
            },
            handler);
        var criteria = new KpsLookupCriteria(
            SyntheticIdentityNumber,
            new DateOnly(1986, 9, 14));

        var identity = await client.GetIdentityAsync(criteria, CancellationToken.None);
        var address = await client.GetAddressAsync(criteria, CancellationToken.None);

        Assert.Equal("ÖRNEK", identity.FirstName);
        Assert.Equal("ÖRNEK MAH. TEST SK. NO: 1", address.FullAddress);
        Assert.Collection(
            handler.Requests,
            request => AssertRequest(request, "/api/kps/sorgula"),
            request => AssertRequest(request, "/api/kpsadres/sorgula"));
    }

    [Fact]
    public async Task NonSuccessResponseDoesNotLeakIdentityOrRequestUri()
    {
        var handler = new RecordingHandler(
            new HttpResponseMessage(HttpStatusCode.BadGateway)
            {
                Content = new StringContent(
                    $"upstream error for {SyntheticIdentityNumber}",
                    Encoding.UTF8,
                    "text/plain"),
            });
        using var client = new KpsClient(
            new KpsOptions { BaseUrl = "http://kps.test.local:8090" },
            handler);

        var error = await Assert.ThrowsAsync<KpsClientException>(() =>
            client.GetIdentityAsync(
                new KpsLookupCriteria(
                    SyntheticIdentityNumber,
                    new DateOnly(1990, 1, 1)),
                CancellationToken.None));

        Assert.Equal("KPS_HTTP_HATASI", error.Code);
        Assert.Equal(HttpStatusCode.BadGateway, error.StatusCode);
        Assert.DoesNotContain(SyntheticIdentityNumber, error.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("kps.test.local", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void BaseUrlMustBeAbsoluteHttpAddressWithoutQuery()
    {
        var error = Assert.Throws<InvalidOperationException>(() =>
            new KpsClient(
                new KpsOptions { BaseUrl = "http://kps.test.local?secret=value" },
                new RecordingHandler(IdentityJson())));

        Assert.Contains("Kps:BaseUrl", error.Message, StringComparison.Ordinal);
    }

    private static void AssertRequest(RecordedRequest request, string expectedPath)
    {
        Assert.Equal(HttpMethod.Get, request.Method);
        Assert.Equal(expectedPath, request.Path);
        Assert.Equal(
            "?tcKimlikNo=12345678901&dogumYil=1986&dogumAy=9&dogumGun=14",
            request.Query);
        Assert.False(request.HasContent);
        Assert.Equal("application/json", request.AcceptMediaType);
    }

    private static HttpResponseMessage IdentityJson() => JsonResponse("""
    {
      "Success": true,
      "TcKimlikNo": 12345678901,
      "Ad": "ÖRNEK",
      "Soyad": "KİŞİ",
      "DogumGunu": 14,
      "DogumAy": 9,
      "DogumYili": 1986
    }
    """);

    private static HttpResponseMessage AddressJson() => JsonResponse("""
    {
      "Success": true,
      "RawData": {
        "SorguSonucu": [
          {
            "KimlikNo": 12345678901,
            "YerlesimYeriAdresi": {
              "AcikAdres": "ÖRNEK MAH. TEST SK. NO: 1"
            }
          }
        ]
      }
    }
    """);

    private static HttpResponseMessage JsonResponse(string json) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json"),
    };

    private sealed class RecordingHandler(params HttpResponseMessage[] responses)
        : HttpMessageHandler
    {
        private readonly Queue<HttpResponseMessage> responses = new(responses);

        public List<RecordedRequest> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var uri = request.RequestUri ?? throw new InvalidOperationException();
            Requests.Add(new RecordedRequest(
                request.Method,
                uri.AbsolutePath,
                uri.Query,
                request.Content is not null,
                request.Headers.Accept.SingleOrDefault()?.MediaType));
            return Task.FromResult(responses.Dequeue());
        }
    }

    private sealed record RecordedRequest(
        HttpMethod Method,
        string Path,
        string Query,
        bool HasContent,
        string? AcceptMediaType);
}
