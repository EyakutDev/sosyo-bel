namespace SosyoBel.Application.Auditing;

public interface IAuditEventQuery
{
    Task<IReadOnlyCollection<AuditEventSummary>> GetAllAsync(
        string? municipalityCode,
        int limit,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AuditEventSummary>> GetMunicipalityAsync(
        int municipalityId,
        int limit,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<AuditEventSummary>> GetOwnAsync(
        int municipalityId,
        string userId,
        int limit,
        CancellationToken cancellationToken);
}
