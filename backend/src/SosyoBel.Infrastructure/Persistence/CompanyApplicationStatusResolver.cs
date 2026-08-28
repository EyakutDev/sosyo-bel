using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Mobil durum kodları ile şirketin mevcut dbo.BasvuruDurumlari adları
/// arasındaki çözümlemeyi yapar. Ayrı bir eşleme tablosu oluşturmaz.
/// </summary>
internal static class CompanyApplicationStatusResolver
{
    public static async Task<ApplicationStatusReference?> FindActiveAsync(
        DbContext context,
        string mobileStatusCode,
        CancellationToken cancellationToken)
    {
        var activeStatuses = await context.Set<ApplicationStatusReference>()
            .AsNoTracking()
            .Where(status => !status.IsDeleted)
            .ToArrayAsync(cancellationToken);

        var matches = activeStatuses
            .Where(status => string.Equals(
                CompanyWorkflowStatusMapper.MapApplication(status.Name),
                mobileStatusCode,
                StringComparison.Ordinal))
            .Take(2)
            .ToArray();

        // Aynı mobil duruma karşılık gelen mükerrer etkin kayıt varsa rastgele
        // seçim yapılmaz; kurum verisi düzeltilene kadar işlem güvenli biçimde durur.
        return matches.Length == 1 ? matches[0] : null;
    }

    public static async Task<string?> FindCodeAsync(
        DbContext context,
        int statusId,
        CancellationToken cancellationToken)
    {
        var name = await context.Set<ApplicationStatusReference>()
            .AsNoTracking()
            .Where(status => status.Id == statusId)
            .Select(status => status.Name)
            .SingleOrDefaultAsync(cancellationToken);
        if (name is null) return null;

        var code = CompanyWorkflowStatusMapper.MapApplication(name);
        return string.Equals(
            code,
            SosyoBel.Application.WorkItems.WorkItemStatusCodes.Unknown,
            StringComparison.Ordinal)
            ? null
            : code;
    }
}
