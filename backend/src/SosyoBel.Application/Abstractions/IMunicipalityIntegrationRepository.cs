using SosyoBel.Domain.Municipalities;

namespace SosyoBel.Application.Abstractions;

public interface IMunicipalityIntegrationRepository
{
    Task<MunicipalityIntegration?> GetActiveAsync(
        int municipalityId,
        MunicipalityIntegrationType type,
        CancellationToken cancellationToken);
}
