using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Abstractions;
using SosyoBel.Domain.Municipalities;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class MunicipalityIntegrationRepository(SosyoBelDbContext dbContext)
    : IMunicipalityIntegrationRepository
{
    public Task<MunicipalityIntegration?> GetActiveAsync(
        int municipalityId,
        MunicipalityIntegrationType type,
        CancellationToken cancellationToken)
    {
        if (municipalityId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        }

        // Belediye filtresi her sorguda repository sınırında zorunlu tutulur.
        return dbContext.MunicipalityIntegrations
            .AsNoTracking()
            .SingleOrDefaultAsync(
                integration =>
                    integration.MunicipalityId == municipalityId &&
                    integration.Type == type &&
                    integration.IsActive,
                cancellationToken);
    }
}
