namespace SosyoBel.Application.Administration;

public enum SystemAdministratorBootstrapStatus
{
    Created,
    AlreadyExists,
    InvalidInput,
    Conflict,
}

public sealed record SystemAdministratorBootstrapInput(
    string Email,
    string FirstName,
    string LastName,
    string Password);

/// <summary>
/// Sonuç modeli parola veya parola türevi hiçbir değer içermez.
/// </summary>
public sealed record SystemAdministratorBootstrapResult(
    SystemAdministratorBootstrapStatus Status,
    string? UserId,
    string Message,
    IReadOnlyCollection<string>? Errors = null);

public interface ISystemAdministratorBootstrapper
{
    Task<SystemAdministratorBootstrapResult> BootstrapAsync(
        SystemAdministratorBootstrapInput input,
        CancellationToken cancellationToken);
}
