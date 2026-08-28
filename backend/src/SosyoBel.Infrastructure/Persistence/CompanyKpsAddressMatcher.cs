using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// KPS mahalle/sokak adlarını şirket web uygulamasıyla aynı kurallarla normalize
/// ederek mevcut dbo.Mahalleler ve dbo.Sokaklar kimliklerine dönüştürür.
/// </summary>
internal static partial class CompanyKpsAddressMatcher
{
    private static readonly CultureInfo TurkishCulture =
        CultureInfo.GetCultureInfo("tr-TR");

    public static async Task<(int? NeighborhoodId, int? StreetId)> ResolveAsync(
        DbContext context,
        KpsProfile profile,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(profile);

        var neighborhoodKey = NormalizeNeighborhoodName(profile.Neighborhood);
        if (neighborhoodKey.Length == 0) return (null, null);

        var neighborhoods = await context.Set<CompanyNeighborhoodReference>()
            .AsNoTracking()
            .Where(value => !value.IsDeleted)
            .Select(value => new { value.Id, value.Name })
            .ToArrayAsync(cancellationToken);

        var neighborhoodMatches = neighborhoods
            .Where(value => string.Equals(
                NormalizeNeighborhoodName(value.Name),
                neighborhoodKey,
                StringComparison.Ordinal))
            .Take(2)
            .ToArray();
        if (neighborhoodMatches.Length != 1) return (null, null);

        var neighborhoodId = neighborhoodMatches[0].Id;
        var streetKey = NormalizeStreetName(profile.Street);
        if (streetKey.Length == 0) return (neighborhoodId, null);

        var streets = await context.Set<CompanyStreetReference>()
            .AsNoTracking()
            .Where(value =>
                !value.IsDeleted &&
                value.NeighborhoodId == neighborhoodId)
            .Select(value => new { value.Id, value.Name })
            .ToArrayAsync(cancellationToken);
        var streetMatches = streets
            .Where(value => string.Equals(
                NormalizeStreetName(value.Name),
                streetKey,
                StringComparison.Ordinal))
            .Take(2)
            .ToArray();

        // Web uygulamasında olduğu gibi mahalle eşleşmesi başvuru için yeterlidir.
        // Sokak bulunamazsa yanlış bir sokağa bağlamak yerine SokakId boş bırakılır.
        return streetMatches.Length == 1
            ? (neighborhoodId, streetMatches[0].Id)
            : (neighborhoodId, null);
    }

    internal static string NormalizeNeighborhoodName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return string.Empty;
        var normalized = name.Trim().ToUpper(TurkishCulture);
        return NeighborhoodSuffixRegex().Replace(normalized, string.Empty).Trim();
    }

    internal static string NormalizeStreetName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return string.Empty;
        var normalized = name.Trim().ToUpper(TurkishCulture);
        normalized = StreetSuffixRegex().Replace(normalized, string.Empty).Trim();
        return normalized.Replace(".", string.Empty, StringComparison.Ordinal).Trim();
    }

    [GeneratedRegex(
        @"[\s\.]*(MAH\.?|MAHALLE(Sİ|SI)?\.?)$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex NeighborhoodSuffixRegex();

    [GeneratedRegex(
        @"[\s\.]*(SK\.?|SOKAK|SOK\.?|CAD\.?|CADDE(Sİ|SI)?\.?|CD\.?|BULVAR(I|İ)?\.?|BLV\.?)$",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex StreetSuffixRegex();
}
