using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Applications;

internal static class ApplicationEndpoints
{
    private const string IdempotencyHeader = "Idempotency-Key";

    public static IEndpointRouteBuilder MapApplicationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints
            .MapGroup("/api/v1/applications")
            .WithTags("Başvurular")
            .RequireAuthorization(AuthorizationPolicyNames.Personnel);

        group.MapPost("/drafts", CreateDraftAsync)
            .WithSummary("Yeni başvuru taslağı oluşturur")
            .WithDescription(
                "Personelin aktif belediyesi kapsamında yeni taslak oluşturur. Ağ tekrarlarında " +
                "ikinci kayıt açılmaması için 8-100 karakterlik Idempotency-Key zorunludur.");
        group.MapGet("/{applicationPublicId:guid}", GetAsync)
            .WithSummary("Başvuru ayrıntılarını getirir")
            .WithDescription(
                "Yalnız başvuruyu oluşturan personel ve aynı belediye kapsamı kaydı okuyabilir.");
        group.MapPut("/{applicationPublicId:guid}/draft", UpdateDraftAsync)
            .WithSummary("Başvuru taslağını günceller")
            .WithDescription(
                "Yalnız TASLAK durumundaki kayıt güncellenebilir. RowVersion eskiyse 409 döner; " +
                "kurula gönderilmiş kayıt hiçbir normal personel isteğiyle değiştirilemez.");
        group.MapPut("/{applicationPublicId:guid}/field-data", SaveFieldDataAsync)
            .WithSummary("Başvurunun aile ve hane saha verisini kaydeder")
            .WithDescription(
                "Manuel aile üyelerini ve yönetilebilir hane soru cevaplarını başvurunun değişmez anlık kopyası olarak kaydeder. " +
                "Yalnız TASLAK kayıt güncellenebilir ve güncel RowVersion zorunludur.");
        group.MapPost("/{applicationPublicId:guid}/photos", UploadPhotosAsync)
            .WithSummary("Başvurunun hane fotoğraflarını yükler")
            .WithDescription(
                "1-15 JPEG, PNG, HEIC veya HEIF fotoğrafını özel dosya deposuna aktarır; " +
                "SQL Server yalnız metadata ve SHA-256 özetini saklar. Her dosya en fazla 10 MB olabilir. " +
                "Idempotency-Key ve güncel RowVersion zorunludur.")
            .WithMetadata(new Microsoft.AspNetCore.Mvc.RequestSizeLimitAttribute(
                160L * 1024 * 1024))
            .DisableAntiforgery();
        group.MapPost("/{applicationPublicId:guid}/submit", SubmitAsync)
            .WithSummary("Başvuruyu kurula gönderir ve kilitler")
            .WithDescription(
                "TASLAK kaydını atomik olarak KURUL_BEKLIYOR durumuna taşır. İşlemden sonra " +
                "başvuru düzenlenemez. Idempotency-Key ve güncel RowVersion zorunludur.");

        return endpoints;
    }

    private static async Task<IResult> CreateDraftAsync(
        CreateApplicationDraftRequest request,
        HttpContext httpContext,
        IApplicationLifecycleService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(httpContext.User, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        var draft = ReadDraft(request.Draft, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        var result = await service.CreateDraftAsync(
            new CreateApplicationDraftCommand(actor!, idempotencyKey!, draft!),
            cancellationToken);
        return result.Status == ApplicationLifecycleStatus.Succeeded && result.Value is not null
            ? Results.Created($"/api/v1/applications/{result.Value.ApplicationPublicId}", result.Value)
            : ToHttpResult(result);
    }

    private static async Task<IResult> GetAsync(
        Guid applicationPublicId,
        ClaimsPrincipal principal,
        IApplicationLifecycleService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        return ToHttpResult(await service.GetAsync(
            actor!,
            applicationPublicId,
            cancellationToken));
    }

    private static async Task<IResult> UpdateDraftAsync(
        Guid applicationPublicId,
        UpdateApplicationDraftRequest request,
        ClaimsPrincipal principal,
        IApplicationLifecycleService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        var draft = ReadDraft(request.Draft, errors);
        ValidateRowVersion(request.ExpectedRowVersion, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        return ToHttpResult(await service.UpdateDraftAsync(
            new UpdateApplicationDraftCommand(
                actor!,
                applicationPublicId,
                request.ExpectedRowVersion!,
                draft!),
            cancellationToken));
    }

    private static async Task<IResult> SubmitAsync(
        Guid applicationPublicId,
        SubmitApplicationRequest request,
        HttpContext httpContext,
        IApplicationLifecycleService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(httpContext.User, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        ValidateRowVersion(request.ExpectedRowVersion, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        return ToHttpResult(await service.SubmitToBoardAsync(
            new SubmitApplicationToBoardCommand(
                actor!,
                applicationPublicId,
                request.ExpectedRowVersion!,
                idempotencyKey!),
                cancellationToken));
    }

    private static async Task<IResult> SaveFieldDataAsync(
        Guid applicationPublicId,
        SaveApplicationFieldDataRequest request,
        ClaimsPrincipal principal,
        IApplicationLifecycleService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        ValidateRowVersion(request.ExpectedRowVersion, errors);
        var familyMembers = ReadFamilyMembers(request.FamilyMembers, errors);
        var householdAnswers = ReadHouseholdAnswers(request.HouseholdAnswers, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        return ToHttpResult(await service.SaveFieldDataAsync(
            new SaveApplicationFieldDataCommand(
                actor!,
                applicationPublicId,
                request.ExpectedRowVersion!,
                familyMembers,
                householdAnswers,
                request.SaveToBeneficiaryDirectory),
            cancellationToken));
    }

    private static async Task<IResult> UploadPhotosAsync(
        Guid applicationPublicId,
        HttpRequest request,
        HttpContext httpContext,
        IApplicationPhotoService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(httpContext.User, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        if (!request.HasFormContentType)
        {
            errors["photos"] = ["multipart/form-data isteği zorunludur."];
            return Results.ValidationProblem(errors);
        }

        var form = await request.ReadFormAsync(cancellationToken);
        var expectedRowVersion = form["expectedRowVersion"].Count == 1
            ? form["expectedRowVersion"][0]
            : null;
        ValidateRowVersion(expectedRowVersion, errors);
        var files = form.Files.GetFiles("photos");
        if (files.Count == 0)
            errors["photos"] = ["En az bir fotoğraf zorunludur."];
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        var streams = new List<Stream>(files.Count);
        try
        {
            var uploads = new List<ApplicationPhotoUpload>(files.Count);
            for (var index = 0; index < files.Count; index++)
            {
                var file = files[index];
                var stream = file.OpenReadStream();
                streams.Add(stream);
                uploads.Add(new(
                    file.FileName,
                    file.ContentType,
                    file.Length,
                    checked((byte)(index + 1)),
                    stream));
            }

            return ToHttpResult(await service.UploadBatchAsync(
                new UploadApplicationPhotosCommand(
                    actor!,
                    applicationPublicId,
                    expectedRowVersion!,
                    idempotencyKey!,
                    uploads),
                cancellationToken));
        }
        finally
        {
            foreach (var stream in streams) await stream.DisposeAsync();
        }
    }

    private static IResult ToHttpResult(
        ApplicationLifecycleResult<ApplicationDetails> result) =>
        result.Status switch
        {
            ApplicationLifecycleStatus.Succeeded => Results.Ok(result.Value),
            ApplicationLifecycleStatus.InvalidInput => Results.ValidationProblem(
                result.Errors ?? new Dictionary<string, string[]>
                {
                    ["request"] = [result.Detail ?? "İstek doğrulanamadı."],
                }),
            ApplicationLifecycleStatus.NotFound => Problem(
                StatusCodes.Status404NotFound,
                result.Code ?? "application_not_found",
                result.Detail ?? "Başvuru bulunamadı."),
            ApplicationLifecycleStatus.Conflict => Problem(
                StatusCodes.Status409Conflict,
                result.Code ?? "application_conflict",
                result.Detail ?? "Başvuru işlemi mevcut kayıtla çakıştı."),
            ApplicationLifecycleStatus.IdempotencyConflict => Problem(
                StatusCodes.Status409Conflict,
                result.Code ?? "idempotency_conflict",
                result.Detail ?? "İstek anahtarı tekrar kullanılamadı."),
            _ => Problem(
                StatusCodes.Status500InternalServerError,
                "application_error",
                "Başvuru işlemi tamamlanamadı."),
        };

    private static IResult Problem(int status, string code, string title) =>
        Results.Problem(
            statusCode: status,
            title: title,
            extensions: new Dictionary<string, object?> { ["code"] = code });

    private static ApplicationActorContext? ReadActor(
        ClaimsPrincipal principal,
        IDictionary<string, string[]> errors)
    {
        var userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var municipalityValue = principal.FindFirstValue(CustomClaimTypes.MunicipalityId);
        var membershipValue = principal.FindFirstValue(
            CustomClaimTypes.MunicipalityMembershipId);
        if (string.IsNullOrWhiteSpace(userId) ||
            !int.TryParse(municipalityValue, NumberStyles.None, CultureInfo.InvariantCulture,
                out var municipalityId) || municipalityId <= 0 ||
            !long.TryParse(membershipValue, NumberStyles.None, CultureInfo.InvariantCulture,
                out var membershipId) || membershipId <= 0)
        {
            errors["actor"] = ["Doğrulanmış belediye personeli bulunamadı."];
            return null;
        }

        return new ApplicationActorContext(userId, municipalityId, membershipId);
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

    private static void ValidateRowVersion(
        string? value,
        IDictionary<string, string[]> errors)
    {
        if (!ApplicationDraftValidation.TryDecodeRowVersion(value, out _))
        {
            errors["expectedRowVersion"] = ["Geçerli RowVersion gönderilmelidir."];
        }
    }

    private static ApplicationDraftData? ReadDraft(
        ApplicationDraftRequest? request,
        IDictionary<string, string[]> errors)
    {
        if (request is null)
        {
            errors["draft"] = ["Taslak bilgileri zorunludur."];
            return null;
        }
        if (request.BirthDate is null)
        {
            errors["draft.birthDate"] = ["Doğum tarihi zorunludur."];
        }
        if (request.HasDisability is null)
        {
            errors["draft.hasDisability"] = ["Engel durumu zorunludur."];
        }
        if (errors.Count > 0) return null;

        return new ApplicationDraftData(
            request.IdentityNumber ?? string.Empty,
            request.BirthDate!.Value,
            request.PhoneNumber ?? string.Empty,
            request.HelpTypeCode ?? string.Empty,
            request.HasDisability!.Value,
            request.DisabilityTypeCode,
            request.DisabilityRate,
            request.Description,
            request.ApplicantFirstName,
            request.ApplicantLastName,
            request.Address,
            request.FieldInspectionNote);
    }

    private static IReadOnlyCollection<ApplicationFamilyMemberData> ReadFamilyMembers(
        IReadOnlyCollection<ApplicationFamilyMemberRequest>? requests,
        IDictionary<string, string[]> errors)
    {
        if (requests is null) return [];
        var result = new List<ApplicationFamilyMemberData>(requests.Count);
        var index = 0;
        foreach (var request in requests)
        {
            if (request.Age is null)
                errors[$"familyMembers[{index}].age"] = ["Yaş zorunludur."];
            if (request.HasDisability is null)
                errors[$"familyMembers[{index}].hasDisability"] = ["Engel durumu zorunludur."];
            if (request.Age is not null && request.HasDisability is not null)
            {
                result.Add(new(
                    request.FullName ?? string.Empty,
                    request.Age.Value,
                    request.RelationshipCode ?? string.Empty,
                    request.OtherRelationshipDescription,
                    request.HasDisability.Value,
                    request.DisabilityTypeCode,
                    request.DisabilityDescription,
                    request.EmploymentStatusCode ?? string.Empty,
                    request.EducationStatusCode ?? string.Empty,
                    request.VitalStatusCode ?? string.Empty));
            }
            index++;
        }
        return result;
    }

    private static IReadOnlyCollection<ApplicationHouseholdAnswerData> ReadHouseholdAnswers(
        IReadOnlyCollection<ApplicationHouseholdAnswerRequest>? requests,
        IDictionary<string, string[]> errors)
    {
        if (requests is null) return [];
        return requests
            .Select(value => new ApplicationHouseholdAnswerData(
                value.QuestionCode ?? string.Empty,
                value.OptionCode ?? string.Empty))
            .ToArray();
    }

    private sealed record CreateApplicationDraftRequest(ApplicationDraftRequest? Draft);

    private sealed record UpdateApplicationDraftRequest(
        string? ExpectedRowVersion,
        ApplicationDraftRequest? Draft);

    private sealed record SubmitApplicationRequest(string? ExpectedRowVersion);

    private sealed record SaveApplicationFieldDataRequest(
        string? ExpectedRowVersion,
        IReadOnlyCollection<ApplicationFamilyMemberRequest>? FamilyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerRequest>? HouseholdAnswers,
        bool SaveToBeneficiaryDirectory);

    private sealed record ApplicationFamilyMemberRequest(
        string? FullName,
        short? Age,
        string? RelationshipCode,
        string? OtherRelationshipDescription,
        bool? HasDisability,
        string? DisabilityTypeCode,
        string? DisabilityDescription,
        string? EmploymentStatusCode,
        string? EducationStatusCode,
        string? VitalStatusCode);

    private sealed record ApplicationHouseholdAnswerRequest(
        string? QuestionCode,
        string? OptionCode);

    private sealed record ApplicationDraftRequest(
        string? IdentityNumber,
        DateOnly? BirthDate,
        string? PhoneNumber,
        string? HelpTypeCode,
        bool? HasDisability,
        string? DisabilityTypeCode,
        byte? DisabilityRate,
        string? Description,
        string? ApplicantFirstName,
        string? ApplicantLastName,
        string? Address,
        string? FieldInspectionNote);
}
