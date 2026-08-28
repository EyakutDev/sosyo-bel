using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Mobilin sabit DIGER kodunu şirketin mevcut dbo.Yakinliklar tablosundaki
/// "Diğer" satırıyla eşleştirir. Sayısal kimlik hiçbir ortam için sabitlenmez.
/// </summary>
internal static class CompanyRelationshipReferenceResolver
{
    public const string OtherCode = "DIGER";
    private const string OtherNameKey = "DIGER";

    public static async Task<int?> ResolveOtherIdAsync(
        DbContext context,
        CancellationToken cancellationToken)
    {
        var activeRelationships = await context.Set<RelationshipReference>()
            .AsNoTracking()
            .Where(value => !value.IsDeleted)
            .Select(value => new { value.Id, value.Name })
            .ToArrayAsync(cancellationToken);

        var matches = activeRelationships
            .Where(value => IsOther(value.Name))
            .Select(value => value.Id)
            .Take(2)
            .ToArray();
        return matches.Length == 1 ? matches[0] : null;
    }

    internal static bool IsOther(string? name) =>
        string.Equals(Normalize(name), OtherNameKey, StringComparison.Ordinal);

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
