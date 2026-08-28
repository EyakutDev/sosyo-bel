using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Mobil başvurular için yetkili tarafından belirlenen "yüz yüze görüşme"
/// kanalını şirketin mevcut dbo lookup tablosundan bulur.
/// </summary>
internal static class CompanyRequestChannelResolver
{
    private const string FaceToFaceKey = "YUZYUZEGORUSME";

    public static async Task<int?> ResolveFaceToFaceIdAsync(
        DbContext context,
        CancellationToken cancellationToken)
    {
        var activeChannels = await context.Set<RequestChannelReference>()
            .AsNoTracking()
            .Where(channel => !channel.IsDeleted)
            .Select(channel => new { channel.Id, channel.Name })
            .ToArrayAsync(cancellationToken);

        // Birden fazla aynı anlamdaki etkin kayıt varsa rastgele ID seçilmez.
        // Veritabanı yöneticisi mükerrer kaydı düzeltince işlem tekrar denenebilir.
        var matches = activeChannels
            .Where(channel => IsFaceToFace(channel.Name))
            .Select(channel => channel.Id)
            .Take(2)
            .ToArray();

        return matches.Length == 1 ? matches[0] : null;
    }

    internal static bool IsFaceToFace(string? name) =>
        string.Equals(Normalize(name), FaceToFaceKey, StringComparison.Ordinal);

    private static string Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;

        var builder = new StringBuilder(value.Length);
        foreach (var character in value.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) ==
                UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            var normalizedCharacter = character switch
            {
                'ı' or 'İ' => 'I',
                _ => char.ToUpperInvariant(character),
            };
            if (char.IsLetterOrDigit(normalizedCharacter))
                builder.Append(normalizedCharacter);
        }

        return builder.ToString();
    }
}
