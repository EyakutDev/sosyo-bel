namespace SosyoBel.Api.Authentication;

internal sealed class JwtOptions
{
    public const string SectionName = "Authentication:Jwt";

    public string Issuer { get; init; } = string.Empty;

    public string Audience { get; init; } = string.Empty;

    public string SigningKeyBase64 { get; init; } = string.Empty;

    public int AccessTokenMinutes { get; init; } = 15;

    public byte[] GetSigningKeyBytes()
    {
        byte[] keyBytes;

        try
        {
            keyBytes = Convert.FromBase64String(SigningKeyBase64);
        }
        catch (FormatException exception)
        {
            throw new InvalidOperationException(
                "Authentication:Jwt:SigningKeyBase64 geçerli Base64 olmalıdır.",
                exception);
        }

        if (keyBytes.Length < 32)
        {
            throw new InvalidOperationException("JWT imza anahtarı en az 32 byte olmalıdır.");
        }

        return keyBytes;
    }

    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(Issuer) || string.IsNullOrWhiteSpace(Audience))
        {
            throw new InvalidOperationException("JWT issuer ve audience değerleri zorunludur.");
        }

        if (AccessTokenMinutes is < 5 or > 60)
        {
            throw new InvalidOperationException("Access token süresi 5 ile 60 dakika arasında olmalıdır.");
        }

        _ = GetSigningKeyBytes();
    }
}
