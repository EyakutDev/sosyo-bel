namespace SosyoBel.Application.Administration;

public interface IAccountAdministrationService
{
    Task<AdministrationResult<ProvisionedMunicipalitySummary>>
        CreateMunicipalityWithAdministratorAsync(
            CreateMunicipalityWithAdministratorCommand command,
            CancellationToken cancellationToken);

    Task<AdministrationResult<ManagedUserSummary>> CreatePersonnelAsync(
        CreatePersonnelCommand command,
        CancellationToken cancellationToken);

    Task<AdministrationResult<ManagedUserSummary>> DeactivatePersonnelAsync(
        DeactivatePersonnelCommand command,
        CancellationToken cancellationToken);

    Task<AdministrationResult<ManagedUserSummary>> ResetPersonnelPasswordAsync(
        ResetPersonnelPasswordCommand command,
        CancellationToken cancellationToken);

    Task<AdministrationResult<PermissionChangeSummary>>
        SetLockedApplicationEditPermissionAsync(
            SetLockedApplicationEditPermissionCommand command,
            CancellationToken cancellationToken);

    Task<AdministrationResult<PermissionChangeSummary>> SetKpsLookupPermissionAsync(
        SetKpsLookupPermissionCommand command,
        CancellationToken cancellationToken);
}
