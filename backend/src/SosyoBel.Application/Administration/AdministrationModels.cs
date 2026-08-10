namespace SosyoBel.Application.Administration;

public enum AdministrationStatus
{
    Succeeded,
    InvalidInput,
    NotFound,
    Conflict,
    AccessDenied,
    IdempotencyConflict,
}

/// <summary>
/// Kimliği doğrulanmış sistem yöneticisinin istek bağlamıdır. ActorUserId
/// istek gövdesinden değil token'dan üretilmelidir.
/// </summary>
public sealed record SystemActorContext(
    string ActorUserId,
    string? IpAddress,
    string? DeviceId,
    Guid CorrelationId);

/// <summary>
/// Belediye kapsamı ve üyelik kimliği yalnız doğrulanmış JWT claim'lerinden
/// gelir; hiçbir belediye yönetim isteği body'den tenant seçemez.
/// </summary>
public sealed record MunicipalityActorContext(
    string ActorUserId,
    int MunicipalityId,
    long MunicipalityMembershipId,
    string? IpAddress,
    string? DeviceId,
    Guid CorrelationId);

public sealed record CreateMunicipalityWithAdministratorCommand(
    SystemActorContext Actor,
    string IdempotencyKey,
    string MunicipalityCode,
    string MunicipalityName,
    string AdministratorEmail,
    string AdministratorFirstName,
    string AdministratorLastName,
    string InitialPassword);

public sealed record CreatePersonnelCommand(
    MunicipalityActorContext Actor,
    string IdempotencyKey,
    string Email,
    string FirstName,
    string LastName,
    string InitialPassword);

public sealed record DeactivatePersonnelCommand(
    MunicipalityActorContext Actor,
    string IdempotencyKey,
    string TargetUserId,
    string Reason);

public sealed record ResetPersonnelPasswordCommand(
    MunicipalityActorContext Actor,
    string IdempotencyKey,
    string TargetUserId,
    string NewPassword);

public sealed record SetLockedApplicationEditPermissionCommand(
    SystemActorContext Actor,
    string IdempotencyKey,
    string MunicipalityCode,
    string TargetUserId,
    bool Enabled,
    string Reason);

public sealed record ManagedUserSummary(
    string UserId,
    string Email,
    string DisplayName,
    string RoleCode,
    bool IsActive);

public sealed record ProvisionedMunicipalitySummary(
    Guid MunicipalityPublicId,
    string MunicipalityCode,
    string MunicipalityName,
    ManagedUserSummary Administrator);

public sealed record PermissionChangeSummary(
    string TargetUserId,
    string MunicipalityCode,
    string PermissionCode,
    bool Enabled);

public sealed record AdministrationResult<T>(
    AdministrationStatus Status,
    T? Value = default,
    string? Code = null,
    string? Detail = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);
