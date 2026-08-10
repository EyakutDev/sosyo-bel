namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// Kullanıcı yönetimi transaction'ında belediye ve ilk yöneticiyi birlikte
/// oluşturabilmek için Belediyeler tablosunun dar Identity eşlemesidir.
/// </summary>
internal sealed class IdentityMunicipalityRecord
{
    private IdentityMunicipalityRecord()
    {
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

    public static IdentityMunicipalityRecord Create(
        string code,
        string name,
        DateTime createdAtUtc)
    {
        return new IdentityMunicipalityRecord
        {
            PublicId = Guid.NewGuid(),
            Code = NormalizeRequired(code, nameof(code), 50).ToUpperInvariant(),
            Name = NormalizeRequired(name, nameof(name), 200),
            IsActive = true,
            CreatedAtUtc = DateTime.SpecifyKind(createdAtUtc, DateTimeKind.Utc),
        };
    }

    private static string NormalizeRequired(
        string value,
        string parameterName,
        int maxLength)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value, parameterName);
        var normalized = value.Trim();
        if (normalized.Length > maxLength)
        {
            throw new ArgumentOutOfRangeException(parameterName);
        }

        return normalized;
    }
}
