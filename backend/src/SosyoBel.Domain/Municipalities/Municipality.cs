namespace SosyoBel.Domain.Municipalities;

/// <summary>
/// Sisteme tanımlanan belediyenin koddan bağımsız, kalıcı iş kaydıdır.
/// Logo dosyasının kendisi yerine güvenli dosya deposundaki anahtarı tutulur.
/// </summary>
public sealed class Municipality
{
    private Municipality()
    {
    }

    private Municipality(string code, string name)
    {
        PublicId = Guid.NewGuid();
        Code = NormalizeRequired(code, nameof(code), 50).ToUpperInvariant();
        Name = NormalizeRequired(name, nameof(name), 200);
        IsActive = true;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public int Id { get; private set; }

    public Guid PublicId { get; private set; }

    public string Code { get; private set; } = string.Empty;

    public string Name { get; private set; } = string.Empty;

    public string? LogoStorageKey { get; private set; }

    public bool IsActive { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? UpdatedAtUtc { get; private set; }

    public byte[] RowVersion { get; private set; } = [];

    public static Municipality Create(string code, string name) => new(code, name);

    public void UpdateBranding(string name, string? logoStorageKey)
    {
        Name = NormalizeRequired(name, nameof(name), 200);
        LogoStorageKey = NormalizeOptional(logoStorageKey, 500);
        UpdatedAtUtc = DateTime.UtcNow;
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

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        if (normalized.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(
                nameof(value),
                $"Değer en fazla {maxLength} karakter olabilir.");
        }

        return normalized;
    }
}
