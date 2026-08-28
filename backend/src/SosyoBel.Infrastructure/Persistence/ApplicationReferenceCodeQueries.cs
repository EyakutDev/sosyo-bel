using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirket lookup tablolarındaki sayısal kimlikleri, mobil API'nin değişmez
/// kodlarıyla birleştiren ortak sorguları içerir.
/// </summary>
internal static class ApplicationReferenceCodeQueries
{
    public const string EmploymentStatus = "CALISMA_DURUMU";
    public const string EducationStatus = "EGITIM_DURUMU";
    public const string DisabilityType = "ENGEL_TURU";
    public const string Relationship = "YAKINLIK";
    public const string HelpType = "YARDIM_TURU";

    /// <summary>
    /// Mobil istemciden gelen tür güvenli kodu çözer ve karşılığındaki etkin dbo
    /// lookup satırını doğrular. Başka bir referans türüne ait kod kabul edilmez.
    /// </summary>
    public static async Task<int?> ResolveActiveCompanyReferenceIdAsync<TSource>(
        this DbContext context,
        string referenceTypeCode,
        string? code,
        CancellationToken cancellationToken)
        where TSource : class, ICompanyReferenceSource
    {
        if (!CompanyReferenceCode.TryDecode(referenceTypeCode, code, out var sourceId))
            return null;

        return await context.Set<TSource>()
            .AsNoTracking()
            .Where(value => value.Id == sourceId && !value.IsDeleted)
            .Select(value => (int?)value.Id)
            .SingleOrDefaultAsync(cancellationToken);
    }

    /// <summary>
    /// Aynı türe ait birden çok mobil kodu tek dbo sorgusunda doğrular.
    /// Sonuç yalnız etkin ve gerçekten mevcut lookup kayıtlarını içerir.
    /// </summary>
    public static async Task<IReadOnlyDictionary<string, int>>
        ResolveActiveCompanyReferenceIdsAsync<TSource>(
            this DbContext context,
            string referenceTypeCode,
            IReadOnlySet<string> codes,
            CancellationToken cancellationToken)
        where TSource : class, ICompanyReferenceSource
    {
        var decoded = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var code in codes)
        {
            if (CompanyReferenceCode.TryDecode(referenceTypeCode, code, out var sourceId))
                decoded[code] = sourceId;
        }

        if (decoded.Count == 0)
            return new Dictionary<string, int>(StringComparer.Ordinal);

        var requestedIds = decoded.Values.ToHashSet();
        var activeIds = await context.Set<TSource>()
            .AsNoTracking()
            .Where(value => requestedIds.Contains(value.Id) && !value.IsDeleted)
            .Select(value => value.Id)
            .ToArrayAsync(cancellationToken);
        var activeIdSet = activeIds.ToHashSet();

        return decoded
            .Where(value => activeIdSet.Contains(value.Value))
            .ToDictionary(value => value.Key, value => value.Value, StringComparer.Ordinal);
    }
}
