using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SosyoBel.Application.Applications;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class ApplicationPhotoService(
    SosyoBelDbContext dbContext,
    IApplicationPhotoStorage storage,
    TimeProvider timeProvider,
    ILogger<ApplicationPhotoService> logger) : IApplicationPhotoService
{
    private const string UploadEndpoint = "APPLICATION_UPLOAD_PHOTOS";
    private const long MaxPhotoBytes = 10 * 1024 * 1024;
    private static readonly HashSet<string> AllowedContentTypes =
        ["image/jpeg", "image/png", "image/heic", "image/heif"];
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    public async Task<ApplicationLifecycleResult<ApplicationDetails>> UploadBatchAsync(
        UploadApplicationPhotosCommand command,
        CancellationToken cancellationToken)
    {
        var validation = Validate(command);
        if (validation.Count > 0) return Invalid(validation);
        var expectedRowVersion = Convert.FromBase64String(command.ExpectedRowVersion.Trim());

        var scopedApplication = await FindScopedApplicationAsync(
            command.Actor,
            command.ApplicationPublicId,
            tracking: false,
            cancellationToken);
        if (scopedApplication is null) return NotFound();
        var currentStatus = await FindStatusCodeAsync(
            scopedApplication.StatusId,
            cancellationToken);
        if (!ApplicationStatusRules.IsEditable(currentStatus)) return Locked();

        try
        {
            // Dosya deposu da ayni hata sinirinin icindedir; boylece disk/IIS klasor
            // sorunlari genel 500 yerine istemcinin anlayabilecegi kontrollu cevaba doner.
            var storedPhotos = new List<StoredApplicationPhoto>(command.Photos.Count);
            foreach (var photo in command.Photos.OrderBy(value => value.Order))
            {
                storedPhotos.Add(await storage.SaveAsync(
                    command.Actor.MunicipalityId,
                    command.ApplicationPublicId,
                    photo,
                    cancellationToken));
            }

            var requestHash = SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(
                new
                {
                    command.ApplicationPublicId,
                    command.ExpectedRowVersion,
                    Photos = storedPhotos.Select(value => new
                    {
                        value.Order,
                        value.ContentType,
                        value.Length,
                        Sha256 = Convert.ToHexString(value.Sha256),
                    }),
                },
                JsonOptions));

            var strategy = dbContext.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                await using var transaction = await dbContext.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);
                var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
                var normalizedKey = command.IdempotencyKey.Trim();
                var idempotencyRecords = dbContext.Set<IdempotencyRecord>();
                var existingRequest = await idempotencyRecords.SingleOrDefaultAsync(
                    value => value.ActorUserId == command.Actor.ActorUserId &&
                             value.EndpointCode == UploadEndpoint &&
                             value.IdempotencyKey == normalizedKey,
                    cancellationToken);
                if (existingRequest is not null)
                {
                    var replay = Replay(existingRequest, requestHash, nowUtc);
                    await transaction.CommitAsync(cancellationToken);
                    return replay;
                }

                var application = await FindScopedApplicationAsync(
                    command.Actor,
                    command.ApplicationPublicId,
                    tracking: true,
                    cancellationToken);
                if (application is null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return NotFound();
                }
                currentStatus = await FindStatusCodeAsync(
                    application.StatusId,
                    cancellationToken);
                if (!ApplicationStatusRules.IsEditable(currentStatus))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return Locked();
                }
                if (!RowVersionsMatch(application.RowVersion, expectedRowVersion))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return ConcurrentConflict();
                }

                var hasActivePhotos = await dbContext.Set<ApplicationPhotoRecord>()
                    .AnyAsync(
                        value => value.MunicipalityId == command.Actor.MunicipalityId &&
                                 value.ApplicationId == application.Id &&
                                 !value.IsDeleted,
                        cancellationToken);
                if (hasActivePhotos)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return Conflict(
                        "photos_already_uploaded",
                        "Bu başvurunun fotoğrafları daha önce yüklenmiş.");
                }

                var reservation = IdempotencyRecord.Create(
                    command.Actor.ActorUserId,
                    UploadEndpoint,
                    normalizedKey,
                    requestHash,
                    nowUtc,
                    nowUtc.AddHours(24));
                idempotencyRecords.Add(reservation);
                foreach (var photo in storedPhotos)
                {
                    dbContext.Set<ApplicationPhotoRecord>().Add(
                        ApplicationPhotoRecord.Create(
                            command.Actor.MunicipalityId,
                            application.Id,
                            command.Actor.ActorUserId,
                            nowUtc,
                            photo));
                }
                application.Touch(command.Actor.ActorUserId, nowUtc);
                await dbContext.SaveChangesAsync(cancellationToken);

                var details = await ToDetailsAsync(application, cancellationToken);
                reservation.Complete(200, JsonSerializer.Serialize(details, JsonOptions));
                await dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return Succeeded(details);
            });
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (DbUpdateConcurrencyException)
        {
            return ConcurrentConflict();
        }
        catch (DbUpdateException exception)
        {
            logger.LogError(
                exception,
                "Application photo metadata persistence failed for {ApplicationPublicId}.",
                command.ApplicationPublicId);
            return Conflict(
                "photo_database_conflict",
                "Fotoğraf kaydı başka bir işlemle çakıştı.");
        }
        catch (IOException)
        {
            return Conflict(
                "photo_storage_error",
                "Fotoğraf özel dosya deposuna yazılamadı.");
        }
        catch (InvalidDataException)
        {
            return Conflict(
                "photo_storage_error",
                "Fotoğraf içeriği aktarım sırasında doğrulanamadı.");
        }
    }

    private static IReadOnlyDictionary<string, string[]> Validate(
        UploadApplicationPhotosCommand command)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(command.Actor.ActorUserId) ||
            command.Actor.MunicipalityId <= 0 ||
            command.Actor.MunicipalityMembershipId <= 0)
            errors["actor"] = ["Doğrulanmış belediye personeli bulunamadı."];
        if (command.ApplicationPublicId == Guid.Empty)
            errors["applicationPublicId"] = ["Başvuru kimliği zorunludur."];
        if (!ApplicationDraftValidation.TryDecodeRowVersion(
                command.ExpectedRowVersion,
                out _))
            errors["expectedRowVersion"] = ["Geçerli RowVersion zorunludur."];
        if (string.IsNullOrWhiteSpace(command.IdempotencyKey) ||
            command.IdempotencyKey.Trim().Length is < 8 or > 100)
            errors["Idempotency-Key"] = ["8-100 karakterlik istek anahtarı zorunludur."];
        if (command.Photos.Count is < 1 or > 15)
            errors["photos"] = ["Bir defada 1-15 fotoğraf yüklenmelidir."];

        var orders = new HashSet<byte>();
        var index = 0;
        foreach (var photo in command.Photos)
        {
            if (photo.Order is < 1 or > 15 || !orders.Add(photo.Order))
                errors[$"photos[{index}].order"] = ["Fotoğraf sırası 1-15 arasında ve benzersiz olmalıdır."];
            if (photo.Length is < 1 or > MaxPhotoBytes)
                errors[$"photos[{index}].length"] = ["Her fotoğraf en fazla 10 MB olabilir."];
            if (!AllowedContentTypes.Contains(photo.ContentType.ToLowerInvariant()))
                errors[$"photos[{index}].contentType"] = ["Yalnız JPEG, PNG, HEIC veya HEIF kabul edilir."];
            if (string.IsNullOrWhiteSpace(photo.FileName) || photo.FileName.Length > 255)
                errors[$"photos[{index}].fileName"] = ["Geçerli dosya adı zorunludur."];
            index++;
        }
        return errors;
    }

    private Task<ApplicationRecord?> FindScopedApplicationAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        bool tracking,
        CancellationToken cancellationToken)
    {
        IQueryable<ApplicationRecord> query = dbContext.Set<ApplicationRecord>();
        if (!tracking) query = query.AsNoTracking();
        return query.SingleOrDefaultAsync(
            value => value.PublicId == applicationPublicId &&
                     value.MunicipalityId == actor.MunicipalityId &&
                     value.CreatedByUserId == actor.ActorUserId,
            cancellationToken);
    }

    private Task<string?> FindStatusCodeAsync(
        int statusId,
        CancellationToken cancellationToken) =>
        dbContext.Set<ApplicationStatusReference>()
            .AsNoTracking()
            .Where(value => value.Id == statusId)
            .Select(value => value.Code)
            .SingleOrDefaultAsync(cancellationToken);

    private async Task<ApplicationDetails> ToDetailsAsync(
        ApplicationRecord application,
        CancellationToken cancellationToken)
    {
        var statusCode = await FindStatusCodeAsync(application.StatusId, cancellationToken)
            ?? throw new InvalidOperationException("Başvuru durum kodu bulunamadı.");
        var helpTypeCode = await dbContext.Set<HelpTypeReference>()
            .AsNoTracking()
            .Where(value => value.Id == application.HelpTypeId)
            .Select(value => value.Code)
            .SingleAsync(cancellationToken);
        var disabilityTypeCode = application.DisabilityTypeId is null
            ? null
            : await dbContext.Set<DisabilityTypeReference>()
                .AsNoTracking()
                .Where(value => value.Id == application.DisabilityTypeId)
                .Select(value => value.Code)
                .SingleAsync(cancellationToken);
        return new(
            application.PublicId,
            application.ApplicationNumber,
            statusCode,
            ApplicationStatusRules.IsEditable(statusCode),
            application.IdentityNumber,
            application.BirthDate,
            application.PhoneNumber,
            helpTypeCode,
            application.HasDisability,
            disabilityTypeCode,
            application.DisabilityRate,
            application.Description,
            application.ApplicantFirstName,
            application.ApplicantLastName,
            application.Address,
            application.FieldInspectionNote,
            application.CreatedAtUtc,
            application.UpdatedAtUtc,
            application.SubmittedAtUtc,
            Convert.ToBase64String(application.RowVersion));
    }

    private static ApplicationLifecycleResult<ApplicationDetails> Replay(
        IdempotencyRecord existing,
        byte[] requestHash,
        DateTime nowUtc)
    {
        if (existing.ExpiresAtUtc <= nowUtc ||
            existing.RequestHash.Length != requestHash.Length ||
            !CryptographicOperations.FixedTimeEquals(existing.RequestHash, requestHash) ||
            !existing.IsCompleted ||
            string.IsNullOrWhiteSpace(existing.ResultJson))
        {
            return new(
                ApplicationLifecycleStatus.IdempotencyConflict,
                Code: "photo_idempotency_conflict",
                Detail: "Fotoğraf yükleme anahtarı yeniden kullanılamadı.");
        }
        try
        {
            var value = JsonSerializer.Deserialize<ApplicationDetails>(
                existing.ResultJson,
                JsonOptions);
            return value is null
                ? new(
                    ApplicationLifecycleStatus.IdempotencyConflict,
                    Code: "photo_idempotency_result_invalid",
                    Detail: "Önceki fotoğraf yükleme sonucu okunamadı.")
                : Succeeded(value);
        }
        catch (JsonException)
        {
            return new(
                ApplicationLifecycleStatus.IdempotencyConflict,
                Code: "photo_idempotency_result_invalid",
                Detail: "Önceki fotoğraf yükleme sonucu okunamadı.");
        }
    }

    private static bool RowVersionsMatch(byte[] current, byte[] expected) =>
        current.Length == expected.Length &&
        CryptographicOperations.FixedTimeEquals(current, expected);

    private static ApplicationLifecycleResult<ApplicationDetails> Succeeded(
        ApplicationDetails value) =>
        new(ApplicationLifecycleStatus.Succeeded, value);

    private static ApplicationLifecycleResult<ApplicationDetails> Invalid(
        IReadOnlyDictionary<string, string[]> errors) =>
        new(ApplicationLifecycleStatus.InvalidInput, Errors: errors);

    private static ApplicationLifecycleResult<ApplicationDetails> NotFound() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "application_not_found",
            Detail: "Başvuru bulunamadı.");

    private static ApplicationLifecycleResult<ApplicationDetails> Locked() =>
        new(
            ApplicationLifecycleStatus.Conflict,
            Code: "application_locked",
            Detail: "Kurula gönderilen başvuru artık düzenlenemez.");

    private static ApplicationLifecycleResult<ApplicationDetails> ConcurrentConflict() =>
        Conflict(
            "application_version_conflict",
            "Başvuru başka bir işlemde değişti; güncel kaydı tekrar açın.");

    private static ApplicationLifecycleResult<ApplicationDetails> Conflict(
        string code,
        string detail) =>
        new(ApplicationLifecycleStatus.Conflict, Code: code, Detail: detail);
}
