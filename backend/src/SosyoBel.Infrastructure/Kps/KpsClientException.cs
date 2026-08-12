using System.Net;

namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// KPS taşıma katmanı hatasını hassas istek adresini veya response içeriğini
/// üst katmana sızdırmadan sınıflandırır.
/// </summary>
internal sealed class KpsClientException(
    string code,
    string message,
    HttpStatusCode? statusCode = null,
    Exception? innerException = null)
    : Exception(message, innerException)
{
    public string Code { get; } = code;

    public HttpStatusCode? StatusCode { get; } = statusCode;
}
