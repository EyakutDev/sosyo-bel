namespace SosyoBel.Application.Authorization;

public interface IActiveMunicipalityMembershipChecker
{
    Task<bool> HasActiveRoleAsync(
        string userId,
        long municipalityMembershipId,
        int municipalityId,
        string requiredRoleCode,
        CancellationToken cancellationToken);
}
