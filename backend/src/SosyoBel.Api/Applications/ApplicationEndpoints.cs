using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text.Json;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Authorization;
using SosyoBel.Infrastructure.Logging;

namespace SosyoBel.Api.Applications;

/// <summary>
/// Başvuru kullanım senaryolarının HTTP sınırıdır. Claim, header ve request
/// doğrulamasını yapar; transaction ve kalıcı iş kurallarını lifecycle servislerine bırakır.
/// </summary>
internal static class ApplicationEndpoints
{
    private const string IdempotencyHeader = "Idempotency-Key";
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    public static IEndpointRouteBuilder MapApplicationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints
            .MapGroup("/api/v1/applications")
            .WithTags("Başvurular")
            .RequireAuthorization(AuthorizationPolicyNames.MobileFieldOperations);

        group.MapGet("/{applicationId:int}", GetSubmittedApplicationDetailAsync)
            .WithSummary("Başvuru detayını getirir")
            .WithDescription(
                "Yetkili personelin kendi başvurusunu veya başka kullanıcıya ait Beklemede başvuruyu; " +
                "aile fertleri, hane cevapları ve mobil fotoğraf yollarıyla getirir. Başkasına ait " +
                "sonuçlanmış kayıt açılmaz ve KPS servisine istek gönderilmez. " +
                "Başvuruyu oluşturan kullanıcı yalnız Beklemede durumunda düzenleme yetkisi alır.")
            .Produces<SubmittedApplicationDetails>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status500InternalServerError);

        group.MapGet(
                "/{applicationId:int}/photos/{photoId:int}",
                GetSubmittedApplicationPhotoAsync)
            .WithSummary("Başvuru fotoğrafını getirir")
            .WithDescription(
                "Detay erişimi bulunan kullanıcının dbo.HaneFotograflari kaydındaki " +
                "fotoğrafı yetkili olarak indirir.")
            .Produces(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapPut("/{applicationId:int}", UpdateSubmittedApplicationAsync)
            .WithSummary("Bekleyen başvuruyu günceller")
            .WithDescription(
                "Başvuruyu yalnız oluşturan kullanıcı ve yalnız Beklemede durumundayken güncelleyebilir. " +
                "Telefon, yardım/engel bilgileri, açıklamalar, aile fertleri ve hane cevapları tek SQL " +
                "transactionında değiştirilir. JSON isteği fotoğrafları korur; multipart isteği " +
                "korunacak fotoğraf kimliklerini ve yeni fotoğrafları birlikte günceller.")
            .WithMetadata(new Microsoft.AspNetCore.Mvc.RequestSizeLimitAttribute(
                160L * 1024 * 1024))
            .Accepts<UpdateSubmittedApplicationRequest>(
                "application/json",
                "multipart/form-data")
            .Produces<UpdatedSubmittedApplication>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status500InternalServerError)
            .DisableAntiforgery();

        group.MapPost("/submit", SubmitCompletedAsync)
            .WithSummary("Tamamlanmış mobil başvuruyu tek işlemde kurula gönderir")
            .WithDescription(
                "multipart/form-data içindeki payload JSON alanından kişi/talep, aile ve hane verilerini; " +
                "photos alanlarından en fazla 15 fotoğrafı alır. KPS sunucuda yeniden doğrulanır. " +
                "dbo.Basvurular, dbo.BasvuruAileFertleri, dbo.BasvuruHaneCevaplari ve " +
                "dbo.HaneFotograflari kayıtları tek SQL transactionında yazılır. " +
                "Herhangi bir adım başarısız olursa veritabanı kayıtları geri alınır ve yeni dosyalar temizlenir.")
            .WithMetadata(new Microsoft.AspNetCore.Mvc.RequestSizeLimitAttribute(
                160L * 1024 * 1024))
            // Handler formu doğrudan HttpRequest üzerinden okuduğu için response
            // tipleri Swagger sözleşmesine burada açıkça eklenir.
            .Produces<CompletedApplicationSubmission>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status500InternalServerError)
            .DisableAntiforgery();

        return endpoints;
    }

    private static async Task<IResult> GetSubmittedApplicationDetailAsync(
        int applicationId,
        ClaimsPrincipal principal,
        ISubmittedApplicationDetailQuery query,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        if (applicationId <= 0)
        {
            errors["applicationId"] =
                ["Başvuru kimliği sıfırdan büyük olmalıdır."];
        }
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        return ToHttpResult(await query.GetAsync(
            actor!,
            applicationId,
            cancellationToken));
    }

    private static async Task<IResult> GetSubmittedApplicationPhotoAsync(
        int applicationId,
        int photoId,
        ClaimsPrincipal principal,
        ISubmittedApplicationPhotoQuery query,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        if (applicationId <= 0)
            errors["applicationId"] = ["Başvuru kimliği sıfırdan büyük olmalıdır."];
        if (photoId <= 0)
            errors["photoId"] = ["Fotoğraf kimliği sıfırdan büyük olmalıdır."];
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        var result = await query.OpenReadAsync(
            actor!,
            applicationId,
            photoId,
            cancellationToken);
        return result.Status == ApplicationLifecycleStatus.Succeeded &&
               result.Value is not null
            ? Results.Stream(
                result.Value.Content,
                result.Value.ContentType,
                result.Value.DownloadFileName,
                enableRangeProcessing: false)
            : ToHttpResult(result);
    }

    private static async Task<IResult> UpdateSubmittedApplicationAsync(
        int applicationId,
        HttpRequest httpRequest,
        ClaimsPrincipal principal,
        IUpdateSubmittedApplicationService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        if (applicationId <= 0)
        {
            errors["applicationId"] =
                ["Başvuru kimliği sıfırdan büyük olmalıdır."];
        }
        UpdateSubmittedApplicationRequest? request = null;
        SubmittedApplicationPhotoUpdateData? photoUpdate = null;
        var streams = new List<Stream>();
        try
        {
            if (httpRequest.HasFormContentType)
            {
                var form = await httpRequest.ReadFormAsync(cancellationToken);
                var payloadText = form["payload"].Count == 1
                    ? form["payload"][0]
                    : null;
                if (string.IsNullOrWhiteSpace(payloadText))
                {
                    errors["payload"] = ["Tek bir payload JSON alanı zorunludur."];
                }
                else
                {
                    try
                    {
                        request = JsonSerializer.Deserialize<
                            UpdateSubmittedApplicationRequest>(
                            payloadText,
                            JsonOptions);
                    }
                    catch (JsonException)
                    {
                        errors["payload"] = ["Payload geçerli JSON biçiminde olmalıdır."];
                    }
                }

                if (request?.RetainedPhotoIds is null)
                {
                    errors["retainedPhotoIds"] =
                        ["Korunacak fotoğraf kimlikleri alanı zorunludur."];
                }
                else
                {
                    var files = form.Files.GetFiles("photos");
                    var newPhotos = new List<ApplicationPhotoUpload>(files.Count);
                    if (request.RetainedPhotoIds.Count + files.Count <=
                        ApplicationPhotoPolicy.MaximumPhotoCount)
                    {
                        for (var index = 0; index < files.Count; index++)
                        {
                            var file = files[index];
                            var stream = file.OpenReadStream();
                            streams.Add(stream);
                            newPhotos.Add(new(
                                file.FileName,
                                file.ContentType,
                                file.Length,
                                checked((byte)(
                                    request.RetainedPhotoIds.Count + index + 1)),
                                stream));
                        }
                    }
                    else
                    {
                        errors["photos"] =
                            [$"Toplam en fazla {ApplicationPhotoPolicy.MaximumPhotoCount} fotoğraf bulunabilir."];
                    }
                    photoUpdate = new(
                        request.RetainedPhotoIds,
                        newPhotos);
                }
            }
            else
            {
                try
                {
                    request = await httpRequest.ReadFromJsonAsync<
                        UpdateSubmittedApplicationRequest>(
                        JsonOptions,
                        cancellationToken);
                }
                catch (JsonException)
                {
                    errors["request"] = ["İstek geçerli JSON biçiminde olmalıdır."];
                }
            }

            if (request is null)
                errors["request"] = ["Başvuru güncelleme içeriği zorunludur."];
            if (errors.Count > 0) return Results.ValidationProblem(errors);

            var editable = ReadSubmittedApplicationEditable(
                request!.Application,
                errors);
            if (request.FamilyMembers is null)
            {
                errors["familyMembers"] =
                    ["Aile fertleri alanı zorunludur; kayıt yoksa boş dizi gönderilmelidir."];
            }
            if (request.HouseholdAnswers is null)
            {
                errors["householdAnswers"] =
                    ["Hane cevapları alanı zorunludur."];
            }
            var familyMembers = ReadFamilyMembers(request.FamilyMembers, errors);
            var householdAnswers = ReadHouseholdAnswers(
                request.HouseholdAnswers,
                errors);
            if (errors.Count > 0) return Results.ValidationProblem(errors);

            return ToHttpResult(await service.UpdateAsync(
                new UpdateSubmittedApplicationCommand(
                    actor!,
                    applicationId,
                    editable!,
                    familyMembers,
                    householdAnswers,
                    photoUpdate),
                cancellationToken));
        }
        finally
        {
            foreach (var stream in streams) await stream.DisposeAsync();
        }
    }

    private static async Task<IResult> SubmitCompletedAsync(
        HttpRequest request,
        HttpContext httpContext,
        ICompletedApplicationSubmissionService service,
        CancellationToken cancellationToken)
    {
        httpContext.RequestServices.GetRequiredService<RequestLogContext>().Stage =
            RequestLogStage.ReadSubmission;
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(httpContext.User, errors);
        var idempotencyKey = ReadIdempotencyKey(httpContext, errors);
        if (!request.HasFormContentType)
        {
            errors["request"] = ["multipart/form-data isteği zorunludur."];
            return Results.ValidationProblem(errors);
        }

        var form = await request.ReadFormAsync(cancellationToken);
        var payloadText = form["payload"].Count == 1
            ? form["payload"][0]
            : null;
        CompletedApplicationSubmissionRequest? payload = null;
        if (string.IsNullOrWhiteSpace(payloadText))
        {
            errors["payload"] = ["Tek bir payload JSON alanı zorunludur."];
        }
        else
        {
            try
            {
                payload = JsonSerializer.Deserialize<
                    CompletedApplicationSubmissionRequest>(
                    payloadText,
                    JsonOptions);
                if (payload is null)
                    errors["payload"] = ["Payload JSON içeriği boş olamaz."];
            }
            catch (JsonException)
            {
                errors["payload"] = ["Payload geçerli JSON biçiminde olmalıdır."];
            }
        }

        ApplicationDraftData? draft = null;
        IReadOnlyCollection<ApplicationFamilyMemberData> familyMembers = [];
        IReadOnlyCollection<ApplicationHouseholdAnswerData> householdAnswers = [];
        if (payload is not null)
        {
            draft = ReadDraft(payload.Draft, errors);
            familyMembers = ReadFamilyMembers(payload.FamilyMembers, errors);
            householdAnswers = ReadHouseholdAnswers(
                payload.HouseholdAnswers,
                errors);
        }
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        var files = form.Files.GetFiles("photos");
        var streams = new List<Stream>(files.Count);
        try
        {
            var photos = new List<ApplicationPhotoUpload>(files.Count);
            for (var index = 0; index < files.Count; index++)
            {
                var file = files[index];
                var stream = file.OpenReadStream();
                streams.Add(stream);
                photos.Add(new(
                    file.FileName,
                    file.ContentType,
                    file.Length,
                    checked((byte)(index + 1)),
                    stream));
            }

            return ToHttpResult(await service.SubmitAsync(
                new SubmitCompletedApplicationCommand(
                    actor!,
                    idempotencyKey!,
                    draft!,
                    familyMembers,
                    householdAnswers,
                    photos),
                cancellationToken));
        }
        finally
        {
            foreach (var stream in streams) await stream.DisposeAsync();
        }
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

    private static async Task<IResult> GetDraftSnapshotAsync(
        Guid applicationPublicId,
        ClaimsPrincipal principal,
        IApplicationLifecycleService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        return ToHttpResult(await service.GetDraftSnapshotAsync(
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

    private static async Task<IResult> DownloadPhotoAsync(
        Guid applicationPublicId,
        int photoId,
        ClaimsPrincipal principal,
        IApplicationPhotoService service,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var actor = ReadActor(principal, errors);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        var result = await service.OpenReadAsync(
            actor!,
            applicationPublicId,
            photoId,
            cancellationToken);
        if (result.Status != ApplicationLifecycleStatus.Succeeded || result.Value is null)
            return ToHttpResult(result);

        return Results.File(
            result.Value.Content,
            result.Value.ContentType,
            fileDownloadName: result.Value.DownloadFileName,
            enableRangeProcessing: true);
    }

    private static IResult ToHttpResult<T>(
        ApplicationLifecycleResult<T> result) =>
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
            ApplicationLifecycleStatus.Forbidden => Problem(
                StatusCodes.Status403Forbidden,
                result.Code ?? "application_forbidden",
                result.Detail ?? "Bu işlem için yetkiniz bulunmuyor."),
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
        if (string.IsNullOrWhiteSpace(userId))
        {
            errors["actor"] = ["Doğrulanmış kullanıcı bulunamadı."];
            return null;
        }

        return new ApplicationActorContext(userId);
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

    private static SubmittedApplicationEditableData?
        ReadSubmittedApplicationEditable(
            SubmittedApplicationEditableRequest? request,
            IDictionary<string, string[]> errors)
    {
        if (request is null)
        {
            errors["application"] =
                ["Güncellenecek başvuru bilgileri zorunludur."];
            return null;
        }
        if (request.HasDisability is null)
        {
            errors["application.hasDisability"] =
                ["Engel durumu zorunludur."];
            return null;
        }

        return new SubmittedApplicationEditableData(
            request.PhoneNumber ?? string.Empty,
            request.HelpTypeCode ?? string.Empty,
            request.HasDisability.Value,
            request.DisabilityTypeCode,
            request.DisabilityRate,
            request.Description,
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

    private sealed record CompletedApplicationSubmissionRequest(
        ApplicationDraftRequest? Draft,
        IReadOnlyCollection<ApplicationFamilyMemberRequest>? FamilyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerRequest>? HouseholdAnswers);

    private sealed record UpdateSubmittedApplicationRequest(
        SubmittedApplicationEditableRequest? Application,
        IReadOnlyCollection<ApplicationFamilyMemberRequest>? FamilyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerRequest>? HouseholdAnswers,
        IReadOnlyCollection<int>? RetainedPhotoIds = null);

    private sealed record SubmittedApplicationEditableRequest(
        string? PhoneNumber,
        string? HelpTypeCode,
        bool? HasDisability,
        string? DisabilityTypeCode,
        byte? DisabilityRate,
        string? Description,
        string? FieldInspectionNote);

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
