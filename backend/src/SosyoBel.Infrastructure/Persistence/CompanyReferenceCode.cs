using System.Globalization;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirketin mevcut dbo lookup kimliğini mobil API'de taşınabilecek, tür güvenli
/// bir koda dönüştürür. Sayısal kimlikler yapılandırmaya veya kaynak koda
/// sabitlenmez; her ortamın kendi dbo kayıtlarından okunur.
/// </summary>
internal static class CompanyReferenceCode
{
    private const char Separator = ':';

    public static string Encode(string referenceTypeCode, int sourceId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(referenceTypeCode);
        if (sourceId <= 0)
            throw new ArgumentOutOfRangeException(nameof(sourceId));

        return string.Concat(
            referenceTypeCode,
            Separator,
            sourceId.ToString(CultureInfo.InvariantCulture));
    }

    public static bool TryDecode(
        string referenceTypeCode,
        string? code,
        out int sourceId)
    {
        sourceId = 0;
        if (string.IsNullOrWhiteSpace(referenceTypeCode) ||
            string.IsNullOrWhiteSpace(code))
        {
            return false;
        }

        var expectedPrefix = string.Concat(referenceTypeCode, Separator);
        var normalizedCode = code.Trim();
        if (!normalizedCode.StartsWith(
                expectedPrefix,
                StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var idPart = normalizedCode[expectedPrefix.Length..];
        return int.TryParse(
                   idPart,
                   NumberStyles.None,
                   CultureInfo.InvariantCulture,
                   out sourceId) &&
               sourceId > 0;
    }
}
