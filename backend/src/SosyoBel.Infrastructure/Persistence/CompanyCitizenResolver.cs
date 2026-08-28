using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

internal enum CompanyCitizenMatchStatus
{
    NotFound,
    Found,
    Ambiguous,
}

internal sealed record CompanyCitizenMatch(
    CompanyCitizenMatchStatus Status,
    int? CitizenId = null);

/// <summary>
/// Mobil başvuruyu şirketin mevcut dbo.Vatandaslar kaydıyla yalnız T.C. kimlik
/// numarası üzerinden eşleştirir. Vatandaş satırında hiçbir değişiklik yapmaz.
/// </summary>
internal static class CompanyCitizenResolver
{
    public static async Task<CompanyCitizenMatch> ResolveAsync(
        DbContext context,
        string identityNumber,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(context);
        if (identityNumber.Length != 11 ||
            identityNumber.Any(value => !char.IsAsciiDigit(value)))
        {
            throw new ArgumentException(
                "T.C. kimlik numarası 11 rakam olmalıdır.",
                nameof(identityNumber));
        }

        // Şirketin kurul onay akışı pasif vatandaşı da aynı T.C. üzerinden bulup
        // yeniden etkinleştiriyor. Bu yüzden Sil alanına göre filtre uygulanmaz.
        var matchingIds = await context.Set<CompanyCitizenRecord>()
            .AsNoTracking()
            .Where(value => value.IdentityNumber == identityNumber)
            .Select(value => value.Id)
            .Take(2)
            .ToArrayAsync(cancellationToken);

        return Classify(matchingIds);
    }

    internal static CompanyCitizenMatch Classify(IReadOnlyCollection<int> matchingIds)
    {
        ArgumentNullException.ThrowIfNull(matchingIds);
        return matchingIds.Count switch
        {
            0 => new CompanyCitizenMatch(CompanyCitizenMatchStatus.NotFound),
            1 => new CompanyCitizenMatch(
                CompanyCitizenMatchStatus.Found,
                matchingIds.Single()),
            _ => new CompanyCitizenMatch(CompanyCitizenMatchStatus.Ambiguous),
        };
    }
}
