using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Net.Mail;
using System.Security.Claims;
using SosyoBel.Application.Administration;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Administration;

internal static class AdministrationEndpoints
{
    private const string IdempotencyHeader = "Idempotency-Key";
    private const string DeviceHeader = "X-Device-Id";
    private const string CorrelationHeader = "X-Correlation-Id";

    public static IEndpointRouteBuilder MapAdministrationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var systemGroup = endpoints
            .MapGroup("/api/v1/system")
            .WithTags("Sistem Yönetimi")
            .RequireAuthorization(AuthorizationPolicyNames.SystemAdministrator);

        systemGroup.MapPost(
            "/municipalities",
            CreateMunicipalityWithAdministratorAsync)
            .WithSummary("Belediye ve ilk yöneticisini oluşturur")
            .WithDescription(
                "Yalnızca sistem yöneticisi kullanabilir. Belediye kaydını ve belediyenin ilk " +
                "yönetici hesabını tek işlemde oluşturur. Tekrarlanan istekleri güvenle yönetmek " +
                "için 8-100 karakterlik Idempotency-Key başlığı zorunludur.");
        systemGroup.MapPut(
            "/municipalities/{municipalityCode}/personnel/{targetUserId}/permissions/locked-application-edit",
            SetLockedApplicationEditPermissionAsync)
            .WithSummary("Kilitli başvuru düzenleme yetkisini değiştirir")
            .WithDescription(
                "Yalnızca sistem yöneticisi kullanabilir. Belirtilen belediyedeki personele, " +
                "kurula gönderildikten sonra kilitlenmiş başvuruları düzenleme istisnası verir " +
                "veya bu istisnayı kaldırır. Gerekçe ve Idempotency-Key zorunludur.");

        var municipalityGroup = endpoints
            .MapGroup("/api/v1/municipality/personnel")
            .WithTags("Belediye Personel Yönetimi")
            .RequireAuthorization(AuthorizationPolicyNames.MunicipalityAdministrator);

        municipalityGroup.MapPost("/", CreatePersonnelAsync)
            .WithSummary("Belediye personeli oluşturur")
            .WithDescription(
                "Belediye yöneticisinin kendi belediyesine yeni personel hesabı eklemesini sağlar. " +
                "Başka belediyeye kayıt açılamaz ve Idempotency-Key başlığı zorunludur.");
        municipalityGroup.MapPost("/{targetUserId}/deactivate", DeactivatePersonnelAsync)
            .WithSummary("Belediye personelini pasifleştirir")
            .WithDescription(
                "Belediye yöneticisinin kendi belediyesindeki personelin erişimini kapatmasını sağlar. " +
                "İşlem gerekçesi ve Idempotency-Key başlığı zorunludur.");
        municipalityGroup.MapPost("/{targetUserId}/reset-password", ResetPersonnelPasswordAsync)
            .WithSummary("Belediye personelinin şifresini sıfırlar")
            .WithDescription(
                "Belediye yöneticisinin kendi belediyesindeki personele yeni bir şifre belirlemesini " +
                "sağlar. Yeni şifre 10-256 karakter olmalı ve Idempotency-Key başlığı gönderilmelidir.");

        return endpoints;
    }

    private static async Task<IResult> CreateMunicipalityWithAdministratorAsync(
        CreateMunicipalityRequest request,
        HttpContext httpContext,
        IAccountAdministrationService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadSystemActor(httpContext, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        ValidateMunicipality(request, errors);
        ValidateNewUser(request.Administrator, "administrator", errors);

        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await service.CreateMunicipalityWithAdministratorAsync(
            new CreateMunicipalityWithAdministratorCommand(
                actor!,
                idempotencyKey!,
                request.Code!.Trim(),
                request.Name!.Trim(),
                request.Administrator!.Email!.Trim(),
                request.Administrator.FirstName!.Trim(),
                request.Administrator.LastName!.Trim(),
                request.Administrator.InitialPassword!),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> CreatePersonnelAsync(
        NewUserRequest request,
        HttpContext httpContext,
        IAccountAdministrationService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadMunicipalityActor(httpContext, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        ValidateNewUser(request, "personnel", errors);

        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await service.CreatePersonnelAsync(
            new CreatePersonnelCommand(
                actor!,
                idempotencyKey!,
                request.Email!.Trim(),
                request.FirstName!.Trim(),
                request.LastName!.Trim(),
                request.InitialPassword!),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> DeactivatePersonnelAsync(
        string targetUserId,
        DeactivatePersonnelRequest request,
        HttpContext httpContext,
        IAccountAdministrationService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadMunicipalityActor(httpContext, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        ValidateTargetUserId(targetUserId, errors);
        ValidateReason(request.Reason, errors);

        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await service.DeactivatePersonnelAsync(
            new DeactivatePersonnelCommand(
                actor!,
                idempotencyKey!,
                targetUserId.Trim(),
                request.Reason!.Trim()),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> ResetPersonnelPasswordAsync(
        string targetUserId,
        ResetPasswordRequest request,
        HttpContext httpContext,
        IAccountAdministrationService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadMunicipalityActor(httpContext, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        ValidateTargetUserId(targetUserId, errors);
        ValidatePassword(request.NewPassword, "newPassword", errors);

        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await service.ResetPersonnelPasswordAsync(
            new ResetPersonnelPasswordCommand(
                actor!,
                idempotencyKey!,
                targetUserId.Trim(),
                request.NewPassword!),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> SetLockedApplicationEditPermissionAsync(
        string municipalityCode,
        string targetUserId,
        SetPermissionRequest request,
        HttpContext httpContext,
        IAccountAdministrationService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadSystemActor(httpContext, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        ValidateMunicipalityCode(municipalityCode, errors);
        ValidateTargetUserId(targetUserId, errors);
        ValidateReason(request.Reason, errors);

        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await service.SetLockedApplicationEditPermissionAsync(
            new SetLockedApplicationEditPermissionCommand(
                actor!,
                idempotencyKey!,
                municipalityCode.Trim(),
                targetUserId.Trim(),
                request.Enabled,
                request.Reason!.Trim()),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static IResult ToHttpResult<T>(AdministrationResult<T> result) =>
        result.Status switch
        {
            AdministrationStatus.Succeeded => Results.Ok(result.Value),
            AdministrationStatus.InvalidInput => Results.ValidationProblem(
                result.Errors ?? new Dictionary<string, string[]>
                {
                    ["request"] = [result.Detail ?? "İstek doğrulanamadı."],
                }),
            AdministrationStatus.NotFound => Problem(
                StatusCodes.Status404NotFound,
                result.Code ?? "not_found",
                result.Detail ?? "Kayıt bulunamadı."),
            AdministrationStatus.Conflict => Problem(
                StatusCodes.Status409Conflict,
                result.Code ?? "conflict",
                result.Detail ?? "İşlem mevcut kayıtla çakışıyor."),
            AdministrationStatus.IdempotencyConflict => Problem(
                StatusCodes.Status409Conflict,
                result.Code ?? "idempotency_conflict",
                result.Detail ?? "Idempotency anahtarı farklı bir istek için kullanılmış."),
            AdministrationStatus.AccessDenied => Problem(
                StatusCodes.Status403Forbidden,
                result.Code ?? "access_denied",
                result.Detail ?? "Bu işlem için yetkiniz yok."),
            _ => Problem(
                StatusCodes.Status500InternalServerError,
                "administration_error",
                "Yönetim işlemi tamamlanamadı."),
        };

    private static IResult Problem(int status, string code, string title) =>
        Results.Problem(
            statusCode: status,
            title: title,
            extensions: new Dictionary<string, object?> { ["code"] = code });

    private static SystemActorContext? ReadSystemActor(
        HttpContext context,
        IDictionary<string, string[]> errors)
    {
        var userId = context.User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        if (string.IsNullOrWhiteSpace(userId))
        {
            errors["actor"] = ["Doğrulanmış kullanıcı kimliği bulunamadı."];
            return null;
        }

        return new SystemActorContext(
            userId,
            ReadRemoteIp(context),
            ReadDeviceId(context, errors),
            ReadCorrelationId(context, errors));
    }

    private static MunicipalityActorContext? ReadMunicipalityActor(
        HttpContext context,
        IDictionary<string, string[]> errors)
    {
        var userId = context.User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var municipalityValue = context.User.FindFirstValue(CustomClaimTypes.MunicipalityId);
        var membershipValue = context.User.FindFirstValue(
            CustomClaimTypes.MunicipalityMembershipId);

        if (string.IsNullOrWhiteSpace(userId) ||
            !int.TryParse(
                municipalityValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var municipalityId) || municipalityId <= 0 ||
            !long.TryParse(
                membershipValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var membershipId) || membershipId <= 0)
        {
            errors["actor"] = ["Doğrulanmış belediye üyeliği bulunamadı."];
            return null;
        }

        return new MunicipalityActorContext(
            userId,
            municipalityId,
            membershipId,
            ReadRemoteIp(context),
            ReadDeviceId(context, errors),
            ReadCorrelationId(context, errors));
    }

    private static string? ReadIdempotencyKey(
        HttpContext context,
        IDictionary<string, string[]> errors)
    {
        var values = context.Request.Headers[IdempotencyHeader];
        var value = values.Count == 1 ? values[0]?.Trim() : null;
        if (string.IsNullOrWhiteSpace(value) || value.Length is < 8 or > 100)
        {
            errors[IdempotencyHeader] =
                ["8-100 karakter uzunluğunda tek bir Idempotency-Key gönderilmelidir."];
            return null;
        }

        return value;
    }

    private static string? ReadDeviceId(
        HttpContext context,
        IDictionary<string, string[]> errors)
    {
        var values = context.Request.Headers[DeviceHeader];
        if (values.Count > 1)
        {
            errors[DeviceHeader] = ["Tek bir cihaz kimliği gönderilmelidir."];
            return null;
        }

        var value = values.Count == 1 ? values[0]?.Trim() : null;
        if (value?.Length > 200)
        {
            errors[DeviceHeader] = ["Cihaz kimliği en fazla 200 karakter olabilir."];
            return null;
        }

        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static Guid ReadCorrelationId(
        HttpContext context,
        IDictionary<string, string[]> errors)
    {
        var values = context.Request.Headers[CorrelationHeader];
        if (values.Count == 0)
        {
            return Guid.NewGuid();
        }

        if (values.Count != 1 || !Guid.TryParse(values[0], out var correlationId) ||
            correlationId == Guid.Empty)
        {
            errors[CorrelationHeader] = ["Correlation kimliği geçerli bir GUID olmalıdır."];
            return Guid.NewGuid();
        }

        return correlationId;
    }

    private static string? ReadRemoteIp(HttpContext context) =>
        context.Connection.RemoteIpAddress?.ToString();

    private static void ValidateMunicipality(
        CreateMunicipalityRequest request,
        IDictionary<string, string[]> errors)
    {
        ValidateMunicipalityCode(request.Code, errors);
        ValidateRequired(request.Name, "name", 200, errors);
    }

    private static void ValidateMunicipalityCode(
        string? code,
        IDictionary<string, string[]> errors)
    {
        ValidateRequired(code, "municipalityCode", 50, errors);
    }

    private static void ValidateNewUser(
        NewUserRequest? request,
        string prefix,
        IDictionary<string, string[]> errors)
    {
        if (request is null)
        {
            errors[prefix] = ["Kullanıcı bilgileri zorunludur."];
            return;
        }

        if (string.IsNullOrWhiteSpace(request.Email) || request.Email.Length > 256 ||
            !MailAddress.TryCreate(request.Email.Trim(), out _))
        {
            errors[$"{prefix}.email"] = ["Geçerli bir e-posta adresi girilmelidir."];
        }

        ValidateRequired(request.FirstName, $"{prefix}.firstName", 100, errors);
        ValidateRequired(request.LastName, $"{prefix}.lastName", 100, errors);
        ValidatePassword(request.InitialPassword, $"{prefix}.initialPassword", errors);
    }

    private static void ValidatePassword(
        string? password,
        string fieldName,
        IDictionary<string, string[]> errors)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length is < 10 or > 256)
        {
            errors[fieldName] = ["Şifre 10-256 karakter uzunluğunda olmalıdır."];
        }
    }

    private static void ValidateTargetUserId(
        string? targetUserId,
        IDictionary<string, string[]> errors)
    {
        ValidateRequired(targetUserId, "targetUserId", 128, errors);
    }

    private static void ValidateReason(
        string? reason,
        IDictionary<string, string[]> errors)
    {
        if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length is < 10 or > 1000)
        {
            errors["reason"] = ["Gerekçe 10-1000 karakter uzunluğunda olmalıdır."];
        }
    }

    private static void ValidateRequired(
        string? value,
        string fieldName,
        int maxLength,
        IDictionary<string, string[]> errors)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Trim().Length > maxLength)
        {
            errors[fieldName] = [$"Alan zorunludur ve en fazla {maxLength} karakter olabilir."];
        }
    }

    private sealed record CreateMunicipalityRequest(
        string? Code,
        string? Name,
        NewUserRequest? Administrator);

    private sealed record NewUserRequest(
        string? Email,
        string? FirstName,
        string? LastName,
        string? InitialPassword);

    private sealed record DeactivatePersonnelRequest(string? Reason);

    private sealed record ResetPasswordRequest(string? NewPassword);

    private sealed record SetPermissionRequest(bool Enabled, string? Reason);
}
