using System.Data;
using System.Globalization;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Administration;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

internal sealed class AccountAdministrationService(
    UserManager<ApplicationUser> userManager,
    AuthenticationDbContext dbContext,
    TimeProvider timeProvider) : IAccountAdministrationService
{
    private const string CreateMunicipalityEndpoint = "SYSTEM_CREATE_MUNICIPALITY";
    private const string CreatePersonnelEndpoint = "MUNICIPALITY_CREATE_PERSONNEL";
    private const string DeactivatePersonnelEndpoint = "MUNICIPALITY_DEACTIVATE_PERSONNEL";
    private const string ResetPersonnelPasswordEndpoint = "MUNICIPALITY_RESET_PERSONNEL_PASSWORD";
    private const string SetLockedEditPermissionEndpoint = "SYSTEM_SET_LOCKED_EDIT_PERMISSION";
    private const string SetKpsLookupPermissionEndpoint = "MUNICIPALITY_SET_KPS_LOOKUP_PERMISSION";

    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    public Task<AdministrationResult<ProvisionedMunicipalitySummary>>
        CreateMunicipalityWithAdministratorAsync(
            CreateMunicipalityWithAdministratorCommand command,
            CancellationToken cancellationToken)
    {
        if (!IsValid(command.Actor) ||
            !IsValidIdempotencyKey(command.IdempotencyKey) ||
            !IsValidText(command.MunicipalityCode, 50) ||
            !IsValidText(command.MunicipalityName, 200) ||
            !IsValidEmail(command.AdministratorEmail) ||
            !IsValidText(command.AdministratorFirstName, 100) ||
            !IsValidText(command.AdministratorLastName, 100) ||
            !IsValidPassword(command.InitialPassword))
        {
            return Task.FromResult(InvalidRequest<ProvisionedMunicipalitySummary>());
        }

        var normalizedCode = command.MunicipalityCode.Trim().ToUpperInvariant();
        var normalizedEmail = command.AdministratorEmail.Trim().ToLowerInvariant();
        var requestHash = HashSafeValues(
            normalizedCode,
            command.MunicipalityName.Trim(),
            normalizedEmail,
            command.AdministratorFirstName.Trim(),
            command.AdministratorLastName.Trim());

        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            CreateMunicipalityEndpoint,
            command.IdempotencyKey,
            requestHash,
            async (nowUtc, token) =>
            {
                if (!await IsSystemAdministratorAsync(command.Actor.ActorUserId))
                {
                    return AccessDenied<ProvisionedMunicipalitySummary>();
                }

                if (await dbContext.Municipalities.AnyAsync(
                        municipality => municipality.Code == normalizedCode,
                        token))
                {
                    return Conflict<ProvisionedMunicipalitySummary>(
                        "municipality_code_exists",
                        "Bu belediye kodu zaten kullanılıyor.");
                }

                if (await userManager.FindByEmailAsync(normalizedEmail) is not null)
                {
                    return Conflict<ProvisionedMunicipalitySummary>(
                        "email_exists",
                        "Bu e-posta adresi zaten kullanılıyor.");
                }

                var municipality = IdentityMunicipalityRecord.Create(
                    normalizedCode,
                    command.MunicipalityName,
                    nowUtc);
                dbContext.Municipalities.Add(municipality);
                await dbContext.SaveChangesAsync(token);

                var administrator = ApplicationUser.Create(
                    normalizedEmail,
                    command.AdministratorFirstName,
                    command.AdministratorLastName,
                    nowUtc,
                    command.Actor.ActorUserId);
                var identityResult = await userManager.CreateAsync(
                    administrator,
                    command.InitialPassword);
                if (!identityResult.Succeeded)
                {
                    return IdentityFailure<ProvisionedMunicipalitySummary>(identityResult);
                }

                dbContext.UserMunicipalities.Add(UserMunicipalityMembership.Create(
                    administrator.Id,
                    municipality.Id,
                    RoleCodes.MunicipalityAdministrator,
                    nowUtc));

                var administratorSummary = new ManagedUserSummary(
                    administrator.Id,
                    administrator.Email!,
                    administrator.DisplayName,
                    RoleCodes.MunicipalityAdministrator,
                    true);
                var summary = new ProvisionedMunicipalitySummary(
                    municipality.PublicId,
                    municipality.Code,
                    municipality.Name,
                    administratorSummary);

                dbContext.AdministrationAudit.Add(AdministrationAuditRecord.Create(
                    municipality.Id,
                    "BELEDIYE",
                    municipality.PublicId,
                    "BELEDIYE_VE_ILK_YONETICI_OLUSTUR",
                    command.Actor.ActorUserId,
                    nowUtc,
                    command.Actor.CorrelationId,
                    targetUserId: administrator.Id,
                    description: "Belediye ve ilk belediye yöneticisi oluşturuldu.",
                    changeSummaryJson: JsonSerializer.Serialize(new
                    {
                        municipalityCode = municipality.Code,
                        administratorEmail = administrator.Email,
                        roleCode = RoleCodes.MunicipalityAdministrator,
                    }, JsonOptions),
                    actorIp: command.Actor.IpAddress,
                    deviceId: command.Actor.DeviceId));
                await dbContext.SaveChangesAsync(token);

                return Success(summary);
            },
            cancellationToken);
    }

    public Task<AdministrationResult<ManagedUserSummary>> CreatePersonnelAsync(
        CreatePersonnelCommand command,
        CancellationToken cancellationToken)
    {
        if (!IsValid(command.Actor) ||
            !IsValidIdempotencyKey(command.IdempotencyKey) ||
            !IsValidEmail(command.Email) ||
            !IsValidText(command.FirstName, 100) ||
            !IsValidText(command.LastName, 100) ||
            !IsValidPassword(command.InitialPassword))
        {
            return Task.FromResult(InvalidRequest<ManagedUserSummary>());
        }

        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var requestHash = HashSafeValues(
            command.Actor.MunicipalityId.ToString(CultureInfo.InvariantCulture),
            command.Actor.MunicipalityMembershipId.ToString(CultureInfo.InvariantCulture),
            normalizedEmail,
            command.FirstName.Trim(),
            command.LastName.Trim());

        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            CreatePersonnelEndpoint,
            command.IdempotencyKey,
            requestHash,
            async (nowUtc, token) =>
            {
                if (!await IsMunicipalityAdministratorAsync(command.Actor, token))
                {
                    return AccessDenied<ManagedUserSummary>();
                }

                if (await userManager.FindByEmailAsync(normalizedEmail) is not null)
                {
                    return Conflict<ManagedUserSummary>(
                        "email_exists",
                        "Bu e-posta adresi zaten kullanılıyor.");
                }

                var personnel = ApplicationUser.Create(
                    normalizedEmail,
                    command.FirstName,
                    command.LastName,
                    nowUtc,
                    command.Actor.ActorUserId);
                var identityResult = await userManager.CreateAsync(
                    personnel,
                    command.InitialPassword);
                if (!identityResult.Succeeded)
                {
                    return IdentityFailure<ManagedUserSummary>(identityResult);
                }

                dbContext.UserMunicipalities.Add(UserMunicipalityMembership.Create(
                    personnel.Id,
                    command.Actor.MunicipalityId,
                    RoleCodes.Personnel,
                    nowUtc));

                var summary = new ManagedUserSummary(
                    personnel.Id,
                    personnel.Email!,
                    personnel.DisplayName,
                    RoleCodes.Personnel,
                    true);
                dbContext.AdministrationAudit.Add(AdministrationAuditRecord.Create(
                    command.Actor.MunicipalityId,
                    "KULLANICI",
                    null,
                    "PERSONEL_OLUSTUR",
                    command.Actor.ActorUserId,
                    nowUtc,
                    command.Actor.CorrelationId,
                    targetUserId: personnel.Id,
                    description: "Belediye personeli oluşturuldu.",
                    changeSummaryJson: JsonSerializer.Serialize(new
                    {
                        email = personnel.Email,
                        roleCode = RoleCodes.Personnel,
                        isActive = true,
                    }, JsonOptions),
                    actorIp: command.Actor.IpAddress,
                    deviceId: command.Actor.DeviceId));
                await dbContext.SaveChangesAsync(token);

                return Success(summary);
            },
            cancellationToken);
    }

    public Task<AdministrationResult<ManagedUserSummary>> DeactivatePersonnelAsync(
        DeactivatePersonnelCommand command,
        CancellationToken cancellationToken)
    {
        if (!IsValid(command.Actor) ||
            !IsValidIdempotencyKey(command.IdempotencyKey) ||
            !IsValidText(command.TargetUserId, 450) ||
            !IsValidReason(command.Reason))
        {
            return Task.FromResult(InvalidRequest<ManagedUserSummary>());
        }

        var targetUserId = command.TargetUserId.Trim();
        var requestHash = HashSafeValues(
            command.Actor.MunicipalityId.ToString(CultureInfo.InvariantCulture),
            targetUserId,
            command.Reason.Trim());

        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            DeactivatePersonnelEndpoint,
            command.IdempotencyKey,
            requestHash,
            async (nowUtc, token) =>
            {
                if (!await IsMunicipalityAdministratorAsync(command.Actor, token))
                {
                    return AccessDenied<ManagedUserSummary>();
                }

                var membership = await dbContext.UserMunicipalities
                    .SingleOrDefaultAsync(value =>
                        value.UserId == targetUserId &&
                        value.MunicipalityId == command.Actor.MunicipalityId &&
                        value.RoleCode == RoleCodes.Personnel,
                        token);
                var personnel = await userManager.FindByIdAsync(targetUserId);

                if (membership is null || personnel is null)
                {
                    return NotFound<ManagedUserSummary>(
                        "personnel_not_found",
                        "Personel kaydı bulunamadı.");
                }

                if (!membership.IsActive || !personnel.IsActive)
                {
                    return Conflict<ManagedUserSummary>(
                        "personnel_already_inactive",
                        "Personel hesabı zaten devre dışı.");
                }

                personnel.Deactivate(
                    command.Actor.ActorUserId,
                    command.Reason,
                    nowUtc);
                membership.Deactivate();

                // Security stamp ve bütün refresh tokenlar kapatılır; mevcut mobil
                // oturum bir sonraki yetkili istekte devam edemez.
                var stampResult = await userManager.UpdateSecurityStampAsync(personnel);
                if (!stampResult.Succeeded)
                {
                    return IdentityFailure<ManagedUserSummary>(stampResult);
                }

                var revokedSessionCount = await RevokeRefreshTokensAsync(
                    personnel.Id,
                    nowUtc,
                    command.Actor.IpAddress,
                    token);

                var summary = new ManagedUserSummary(
                    personnel.Id,
                    personnel.Email!,
                    personnel.DisplayName,
                    RoleCodes.Personnel,
                    false);
                dbContext.AdministrationAudit.Add(AdministrationAuditRecord.Create(
                    command.Actor.MunicipalityId,
                    "KULLANICI",
                    null,
                    "PERSONEL_DEVRE_DISI_BIRAK",
                    command.Actor.ActorUserId,
                    nowUtc,
                    command.Actor.CorrelationId,
                    targetUserId: personnel.Id,
                    description: "Belediye personeli devre dışı bırakıldı.",
                    changeSummaryJson: JsonSerializer.Serialize(new
                    {
                        before = new { isActive = true, membershipActive = true },
                        after = new { isActive = false, membershipActive = false },
                        revokedSessionCount,
                    }, JsonOptions),
                    reason: command.Reason,
                    actorIp: command.Actor.IpAddress,
                    deviceId: command.Actor.DeviceId));
                await dbContext.SaveChangesAsync(token);

                return Success(summary);
            },
            cancellationToken);
    }

    public Task<AdministrationResult<ManagedUserSummary>> ResetPersonnelPasswordAsync(
        ResetPersonnelPasswordCommand command,
        CancellationToken cancellationToken)
    {
        if (!IsValid(command.Actor) ||
            !IsValidIdempotencyKey(command.IdempotencyKey) ||
            !IsValidText(command.TargetUserId, 450) ||
            !IsValidPassword(command.NewPassword))
        {
            return Task.FromResult(InvalidRequest<ManagedUserSummary>());
        }

        var targetUserId = command.TargetUserId.Trim();
        // Parola bilinçli olarak kalıcı idempotency hashine dahil edilmez.
        var requestHash = HashSafeValues(
            command.Actor.MunicipalityId.ToString(CultureInfo.InvariantCulture),
            targetUserId);

        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            ResetPersonnelPasswordEndpoint,
            command.IdempotencyKey,
            requestHash,
            async (nowUtc, token) =>
            {
                if (!await IsMunicipalityAdministratorAsync(command.Actor, token))
                {
                    return AccessDenied<ManagedUserSummary>();
                }

                var hasActivePersonnelMembership = await dbContext.UserMunicipalities
                    .AsNoTracking()
                    .AnyAsync(value =>
                        value.UserId == targetUserId &&
                        value.MunicipalityId == command.Actor.MunicipalityId &&
                        value.RoleCode == RoleCodes.Personnel &&
                        value.IsActive,
                        token);
                var personnel = await userManager.FindByIdAsync(targetUserId);

                if (!hasActivePersonnelMembership || personnel is null || !personnel.IsActive)
                {
                    return NotFound<ManagedUserSummary>(
                        "active_personnel_not_found",
                        "Aktif personel kaydı bulunamadı.");
                }

                var resetToken = await userManager.GeneratePasswordResetTokenAsync(personnel);
                var resetResult = await userManager.ResetPasswordAsync(
                    personnel,
                    resetToken,
                    command.NewPassword);
                if (!resetResult.Succeeded)
                {
                    return IdentityFailure<ManagedUserSummary>(resetResult);
                }

                var stampResult = await userManager.UpdateSecurityStampAsync(personnel);
                if (!stampResult.Succeeded)
                {
                    return IdentityFailure<ManagedUserSummary>(stampResult);
                }

                var revokedSessionCount = await RevokeRefreshTokensAsync(
                    personnel.Id,
                    nowUtc,
                    command.Actor.IpAddress,
                    token);
                var summary = new ManagedUserSummary(
                    personnel.Id,
                    personnel.Email!,
                    personnel.DisplayName,
                    RoleCodes.Personnel,
                    true);

                // Audit yalnız işlemin gerçekleştiğini kaydeder; parola ve reset
                // tokenı hiçbir koşulda JSON'a veya loga yazılmaz.
                dbContext.AdministrationAudit.Add(AdministrationAuditRecord.Create(
                    command.Actor.MunicipalityId,
                    "KULLANICI",
                    null,
                    "PERSONEL_SIFRE_SIFIRLA",
                    command.Actor.ActorUserId,
                    nowUtc,
                    command.Actor.CorrelationId,
                    targetUserId: personnel.Id,
                    description: "Personel şifresi yönetici tarafından sıfırlandı.",
                    changeSummaryJson: JsonSerializer.Serialize(new
                    {
                        passwordChanged = true,
                        revokedSessionCount,
                    }, JsonOptions),
                    actorIp: command.Actor.IpAddress,
                    deviceId: command.Actor.DeviceId));
                await dbContext.SaveChangesAsync(token);

                return Success(summary);
            },
            cancellationToken);
    }

    public Task<AdministrationResult<PermissionChangeSummary>>
        SetLockedApplicationEditPermissionAsync(
            SetLockedApplicationEditPermissionCommand command,
            CancellationToken cancellationToken)
    {
        if (!IsValid(command.Actor) ||
            !IsValidIdempotencyKey(command.IdempotencyKey) ||
            !IsValidText(command.MunicipalityCode, 50) ||
            !IsValidText(command.TargetUserId, 450) ||
            !IsValidReason(command.Reason))
        {
            return Task.FromResult(InvalidRequest<PermissionChangeSummary>());
        }

        var municipalityCode = command.MunicipalityCode.Trim().ToUpperInvariant();
        var targetUserId = command.TargetUserId.Trim();
        var requestHash = HashSafeValues(
            municipalityCode,
            targetUserId,
            command.Enabled ? "1" : "0",
            command.Reason.Trim());

        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            SetLockedEditPermissionEndpoint,
            command.IdempotencyKey,
            requestHash,
            async (nowUtc, token) =>
            {
                if (!await IsSystemAdministratorAsync(command.Actor.ActorUserId))
                {
                    return AccessDenied<PermissionChangeSummary>();
                }

                var municipality = await dbContext.Municipalities
                    .SingleOrDefaultAsync(value =>
                        value.Code == municipalityCode && value.IsActive,
                        token);
                if (municipality is null)
                {
                    return NotFound<PermissionChangeSummary>(
                        "municipality_not_found",
                        "Aktif belediye bulunamadı.");
                }

                var membershipExists = await dbContext.UserMunicipalities
                    .AsNoTracking()
                    .AnyAsync(value =>
                        value.UserId == targetUserId &&
                        value.MunicipalityId == municipality.Id &&
                        value.IsActive,
                        token);
                var targetUserIsActive = await dbContext.UserApplicationInfos
                    .AsNoTracking()
                    .AnyAsync(
                        value => value.UserId == targetUserId && value.IsActive,
                        token);
                if (!membershipExists || !targetUserIsActive)
                {
                    return NotFound<PermissionChangeSummary>(
                        "active_membership_not_found",
                        "Hedef kullanıcının aktif belediye üyeliği bulunamadı.");
                }

                var permission = await dbContext.UserPermissions
                    .SingleOrDefaultAsync(value =>
                        value.UserId == targetUserId &&
                        value.MunicipalityId == municipality.Id &&
                        value.PermissionCode == PermissionCodes.LockedApplicationEdit,
                        token);
                var stateChanged = permission?.IsActive != command.Enabled;

                if (command.Enabled)
                {
                    if (permission is null)
                    {
                        permission = UserPermissionRecord.Create(
                            targetUserId,
                            municipality.Id,
                            PermissionCodes.LockedApplicationEdit,
                            command.Actor.ActorUserId,
                            nowUtc);
                        dbContext.UserPermissions.Add(permission);
                    }
                    else if (!permission.IsActive)
                    {
                        permission.Grant(command.Actor.ActorUserId, nowUtc);
                    }
                }
                else if (permission?.IsActive is true)
                {
                    permission.Revoke(command.Actor.ActorUserId, nowUtc);
                }

                var summary = new PermissionChangeSummary(
                    targetUserId,
                    municipality.Code,
                    PermissionCodes.LockedApplicationEdit,
                    command.Enabled);

                if (stateChanged)
                {
                    dbContext.AdministrationAudit.Add(AdministrationAuditRecord.Create(
                        municipality.Id,
                        "KULLANICI_YETKISI",
                        null,
                        command.Enabled
                            ? "KILITLI_BASVURU_YETKISI_VER"
                            : "KILITLI_BASVURU_YETKISI_IPTAL",
                        command.Actor.ActorUserId,
                        nowUtc,
                        command.Actor.CorrelationId,
                        targetUserId: targetUserId,
                        description: command.Enabled
                            ? "Kilitli başvuru düzenleme yetkisi verildi."
                            : "Kilitli başvuru düzenleme yetkisi iptal edildi.",
                        changeSummaryJson: JsonSerializer.Serialize(new
                        {
                            before = new { enabled = !command.Enabled },
                            after = new { enabled = command.Enabled },
                            permissionCode = PermissionCodes.LockedApplicationEdit,
                        }, JsonOptions),
                        reason: command.Reason,
                        actorIp: command.Actor.IpAddress,
                        deviceId: command.Actor.DeviceId));
                }

                await dbContext.SaveChangesAsync(token);
                return Success(summary);
            },
            cancellationToken);
    }

    public Task<AdministrationResult<PermissionChangeSummary>> SetKpsLookupPermissionAsync(
        SetKpsLookupPermissionCommand command,
        CancellationToken cancellationToken)
    {
        if (!IsValid(command.Actor) ||
            !IsValidIdempotencyKey(command.IdempotencyKey) ||
            !IsValidText(command.TargetUserId, 450) ||
            !IsValidReason(command.Reason))
        {
            return Task.FromResult(InvalidRequest<PermissionChangeSummary>());
        }

        var targetUserId = command.TargetUserId.Trim();
        var requestHash = HashSafeValues(
            command.Actor.MunicipalityId.ToString(CultureInfo.InvariantCulture),
            command.Actor.MunicipalityMembershipId.ToString(CultureInfo.InvariantCulture),
            targetUserId,
            PermissionCodes.KpsLookup,
            command.Enabled ? "1" : "0",
            command.Reason.Trim());

        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            SetKpsLookupPermissionEndpoint,
            command.IdempotencyKey,
            requestHash,
            async (nowUtc, token) =>
            {
                if (!await IsMunicipalityAdministratorAsync(command.Actor, token))
                {
                    return AccessDenied<PermissionChangeSummary>();
                }

                var municipalityCode = await dbContext.Municipalities
                    .AsNoTracking()
                    .Where(value =>
                        value.Id == command.Actor.MunicipalityId && value.IsActive)
                    .Select(value => value.Code)
                    .SingleAsync(token);
                var targetIsActivePersonnel = await (
                    from membership in dbContext.UserMunicipalities.AsNoTracking()
                    join userInfo in dbContext.UserApplicationInfos.AsNoTracking()
                        on membership.UserId equals userInfo.UserId
                    where membership.UserId == targetUserId &&
                          membership.MunicipalityId == command.Actor.MunicipalityId &&
                          membership.RoleCode == RoleCodes.Personnel &&
                          membership.IsActive &&
                          userInfo.IsActive
                    select membership.Id)
                    .AnyAsync(token);
                if (!targetIsActivePersonnel)
                {
                    return NotFound<PermissionChangeSummary>(
                        "active_personnel_not_found",
                        "Hedef aktif personel kaydı bulunamadı.");
                }

                var permission = await dbContext.UserPermissions
                    .SingleOrDefaultAsync(value =>
                        value.UserId == targetUserId &&
                        value.MunicipalityId == command.Actor.MunicipalityId &&
                        value.PermissionCode == PermissionCodes.KpsLookup,
                        token);
                var wasEnabled = permission?.IsActive == true;

                if (command.Enabled)
                {
                    if (permission is null)
                    {
                        permission = UserPermissionRecord.Create(
                            targetUserId,
                            command.Actor.MunicipalityId,
                            PermissionCodes.KpsLookup,
                            command.Actor.ActorUserId,
                            nowUtc);
                        dbContext.UserPermissions.Add(permission);
                    }
                    else if (!permission.IsActive)
                    {
                        permission.Grant(command.Actor.ActorUserId, nowUtc);
                    }
                }
                else if (permission?.IsActive is true)
                {
                    permission.Revoke(command.Actor.ActorUserId, nowUtc);
                }

                var summary = new PermissionChangeSummary(
                    targetUserId,
                    municipalityCode,
                    PermissionCodes.KpsLookup,
                    command.Enabled);
                if (wasEnabled != command.Enabled)
                {
                    dbContext.AdministrationAudit.Add(AdministrationAuditRecord.Create(
                        command.Actor.MunicipalityId,
                        "KULLANICI_YETKISI",
                        null,
                        command.Enabled
                            ? "KPS_SORGULAMA_YETKISI_VER"
                            : "KPS_SORGULAMA_YETKISI_IPTAL",
                        command.Actor.ActorUserId,
                        nowUtc,
                        command.Actor.CorrelationId,
                        targetUserId: targetUserId,
                        description: command.Enabled
                            ? "KPS sorgulama yetkisi verildi."
                            : "KPS sorgulama yetkisi iptal edildi.",
                        changeSummaryJson: JsonSerializer.Serialize(new
                        {
                            before = new { enabled = wasEnabled },
                            after = new { enabled = command.Enabled },
                            permissionCode = PermissionCodes.KpsLookup,
                        }, JsonOptions),
                        reason: command.Reason,
                        actorIp: command.Actor.IpAddress,
                        deviceId: command.Actor.DeviceId));
                }

                await dbContext.SaveChangesAsync(token);
                return Success(summary);
            },
            cancellationToken);
    }

    private async Task<AdministrationResult<T>> ExecuteIdempotentAsync<T>(
        string actorUserId,
        string endpointCode,
        string idempotencyKey,
        byte[] requestHash,
        Func<DateTime, CancellationToken, Task<AdministrationResult<T>>> operation,
        CancellationToken cancellationToken)
        where T : class
    {
        try
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);
            var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
            var normalizedKey = idempotencyKey.Trim();

            var existing = await dbContext.IdempotencyRecords.SingleOrDefaultAsync(
                value => value.ActorUserId == actorUserId &&
                         value.EndpointCode == endpointCode &&
                         value.IdempotencyKey == normalizedKey,
                cancellationToken);
            if (existing is not null)
            {
                var replay = Replay<T>(existing, requestHash, nowUtc);
                await transaction.CommitAsync(cancellationToken);
                return replay;
            }

            var reservation = IdempotencyRecord.Create(
                actorUserId,
                endpointCode,
                normalizedKey,
                requestHash,
                nowUtc,
                nowUtc.AddHours(24));
            dbContext.IdempotencyRecords.Add(reservation);
            await dbContext.SaveChangesAsync(cancellationToken);

            var result = await operation(nowUtc, cancellationToken);
            if (result.Status is not AdministrationStatus.Succeeded || result.Value is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return result;
            }

            // Yalnız güvenli response DTO'su kalıcılaştırılır; komut ve parola saklanmaz.
            reservation.Complete(200, JsonSerializer.Serialize(result.Value, JsonOptions));
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (DbUpdateException)
        {
            return Conflict<T>(
                "concurrent_conflict",
                "Kayıt başka bir işlemle aynı anda değişti. Yeni bir istek anahtarıyla tekrar deneyin.");
        }
        catch (ArgumentException)
        {
            return InvalidRequest<T>();
        }
    }

    private static AdministrationResult<T> Replay<T>(
        IdempotencyRecord existing,
        byte[] requestHash,
        DateTime nowUtc)
        where T : class
    {
        if (existing.ExpiresAtUtc <= nowUtc)
        {
            return IdempotencyConflict<T>(
                "idempotency_key_expired",
                "Bu istek anahtarının süresi doldu; yeni bir anahtar kullanın.");
        }

        if (existing.RequestHash.Length != requestHash.Length ||
            !CryptographicOperations.FixedTimeEquals(existing.RequestHash, requestHash))
        {
            return IdempotencyConflict<T>(
                "idempotency_payload_mismatch",
                "Aynı istek anahtarı farklı içerikle kullanılamaz.");
        }

        if (!existing.IsCompleted || string.IsNullOrWhiteSpace(existing.ResultJson))
        {
            return IdempotencyConflict<T>(
                "idempotency_request_in_progress",
                "Bu istek halen işleniyor.");
        }

        try
        {
            var value = JsonSerializer.Deserialize<T>(existing.ResultJson, JsonOptions);
            return value is null
                ? IdempotencyConflict<T>(
                    "idempotency_result_invalid",
                    "Önceki işlem sonucu okunamadı.")
                : Success(value);
        }
        catch (JsonException)
        {
            return IdempotencyConflict<T>(
                "idempotency_result_invalid",
                "Önceki işlem sonucu okunamadı.");
        }
    }

    private async Task<bool> IsSystemAdministratorAsync(string actorUserId)
    {
        var actor = await userManager.FindByIdAsync(actorUserId);
        return actor is not null &&
               actor.IsActive &&
               await userManager.IsInRoleAsync(actor, RoleCodes.SystemAdministrator);
    }

    private Task<bool> IsMunicipalityAdministratorAsync(
        MunicipalityActorContext actor,
        CancellationToken cancellationToken)
    {
        return (
            from membership in dbContext.UserMunicipalities.AsNoTracking()
            join municipality in dbContext.Municipalities.AsNoTracking()
                on membership.MunicipalityId equals municipality.Id
            join userInfo in dbContext.UserApplicationInfos.AsNoTracking()
                on membership.UserId equals userInfo.UserId
            where membership.Id == actor.MunicipalityMembershipId &&
                  membership.UserId == actor.ActorUserId &&
                  membership.MunicipalityId == actor.MunicipalityId &&
                  membership.RoleCode == RoleCodes.MunicipalityAdministrator &&
                  membership.IsActive &&
                  municipality.IsActive &&
                  userInfo.IsActive
            select membership.Id)
            .AnyAsync(cancellationToken);
    }

    private async Task<int> RevokeRefreshTokensAsync(
        string userId,
        DateTime nowUtc,
        string? actorIp,
        CancellationToken cancellationToken)
    {
        var tokens = await dbContext.RefreshTokens
            .Where(value => value.UserId == userId && value.RevokedAtUtc == null)
            .ToListAsync(cancellationToken);
        foreach (var refreshToken in tokens)
        {
            refreshToken.Revoke(nowUtc, actorIp);
        }

        return tokens.Count;
    }

    private static byte[] HashSafeValues(params string?[] values)
    {
        var canonical = string.Join(
            '\u001f',
            values.Select(value => value?.Trim() ?? "<null>"));
        return SHA256.HashData(Encoding.UTF8.GetBytes(canonical));
    }

    private static bool IsValid(SystemActorContext actor) =>
        IsValidActorMetadata(
            actor.ActorUserId,
            actor.IpAddress,
            actor.DeviceId,
            actor.CorrelationId);

    private static bool IsValid(MunicipalityActorContext actor) =>
        actor.MunicipalityId > 0 &&
        actor.MunicipalityMembershipId > 0 &&
        IsValidActorMetadata(
            actor.ActorUserId,
            actor.IpAddress,
            actor.DeviceId,
            actor.CorrelationId);

    private static bool IsValidActorMetadata(
        string actorUserId,
        string? ipAddress,
        string? deviceId,
        Guid correlationId) =>
        IsValidText(actorUserId, 450) &&
        (ipAddress is null || ipAddress.Length <= 45) &&
        (deviceId is null || deviceId.Length <= 200) &&
        correlationId != Guid.Empty;

    private static bool IsValidIdempotencyKey(string value) =>
        !string.IsNullOrWhiteSpace(value) && value.Trim().Length is >= 8 and <= 100;

    private static bool IsValidText(string value, int maxLength) =>
        !string.IsNullOrWhiteSpace(value) && value.Trim().Length <= maxLength;

    private static bool IsValidEmail(string value) =>
        IsValidText(value, 256) && MailAddress.TryCreate(value.Trim(), out _);
    private static bool IsValidPassword(string value) =>
        !string.IsNullOrWhiteSpace(value) && value.Length is >= 10 and <= 256;

    private static bool IsValidReason(string value) =>
        !string.IsNullOrWhiteSpace(value) && value.Trim().Length is >= 10 and <= 1000;

    private static AdministrationResult<T> Success<T>(T value) =>
        new(AdministrationStatus.Succeeded, value);

    private static AdministrationResult<T> InvalidRequest<T>() =>
        new(
            AdministrationStatus.InvalidInput,
            Errors: new Dictionary<string, string[]>
            {
                ["request"] = ["İstek alanları doğrulanamadı."],
            });

    private static AdministrationResult<T> IdentityFailure<T>(IdentityResult result) =>
        new(
            AdministrationStatus.InvalidInput,
            Errors: new Dictionary<string, string[]>
            {
                ["identity"] = result.Errors
                    .Select(error => error.Description)
                    .Distinct(StringComparer.Ordinal)
                    .ToArray(),
            });

    private static AdministrationResult<T> NotFound<T>(string code, string detail) =>
        new(AdministrationStatus.NotFound, Code: code, Detail: detail);

    private static AdministrationResult<T> Conflict<T>(string code, string detail) =>
        new(AdministrationStatus.Conflict, Code: code, Detail: detail);

    private static AdministrationResult<T> AccessDenied<T>() =>
        new(
            AdministrationStatus.AccessDenied,
            Code: "access_denied",
            Detail: "Bu işlem için güncel yetki bulunamadı.");

    private static AdministrationResult<T> IdempotencyConflict<T>(
        string code,
        string detail) =>
        new(AdministrationStatus.IdempotencyConflict, Code: code, Detail: detail);
}
