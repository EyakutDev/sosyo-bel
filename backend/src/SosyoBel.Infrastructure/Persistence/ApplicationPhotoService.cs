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

        var storedPhotos = new List<StoredApplicationPhoto>(command.Photos.Count);
        var obsoleteStorageKeys = new HashSet<string>(StringComparer.Ordinal);
        try
        {
            // Dosya deposu da ayni hata sinirinin icindedir; boylece disk/IIS klasor
            // sorunlari genel 500 yerine istemcinin anlayabilecegi kontrollu cevaba doner.
            foreach (var photo in command.Photos.OrderBy(value => value.Order))
            {
                storedPhotos.Add(await storage.SaveAsync(
                    command.ApplicationPublicId,
                    photo,
                    cancellationToken));
            }

            var requestHash = SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(
                new
                {
                    command.ApplicationPublicId,
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
            var result = await strategy.ExecuteAsync(async () =>
            {
                await using var transaction = await dbContext.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);
                var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
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

                var normalizedKey = command.IdempotencyKey.Trim();
                var idempotencyRecords = dbContext.Set<IdempotencyRecord>();
                var existingRequest = await idempotencyRecords.SingleOrDefaultAsync(
                    value => value.ActorUserId == command.Actor.ActorUserId &&
                             value.EndpointCode == UploadEndpoint &&
                             value.IdempotencyKey == normalizedKey,
                    cancellationToken);
                if (existingRequest is not null)
                {
                    var replayError = ValidateReplay(existingRequest, requestHash, nowUtc);
                    if (replayError is not null)
                    {
                        await transaction.CommitAsync(cancellationToken);
                        return replayError;
                    }

                    // RowVersion baska bir taslak yazimiyla ilerlemis olabilir.
                    // Ayni fotograf icerigi replay edildiginde guncel temsil donulur.
                    var currentDetails = await ToDetailsAsync(application, cancellationToken);
                    await transaction.CommitAsync(cancellationToken);
                    return Succeeded(currentDetails);
                }

                if (!RowVersionsMatch(application.RowVersion, expectedRowVersion))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return ConcurrentConflict();
                }

                var activePhotos = await dbContext.Set<ApplicationPhotoRecord>()
                    .Where(
                        value => value.ApplicationId == application.Id &&
                                 !value.IsDeleted)
                    .ToArrayAsync(cancellationToken);
                foreach (var activePhoto in activePhotos)
                {
                    activePhoto.MarkDeleted(command.Actor.ActorUserId, nowUtc);
                    obsoleteStorageKeys.Add(activePhoto.StorageKey);
                }
                if (activePhotos.Length > 0)
                {
                    // Filtreli benzersiz indeksleri yeni anlik kopyadan once bosalt.
                    await dbContext.SaveChangesAsync(cancellationToken);
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

            if (result.Status == ApplicationLifecycleStatus.Succeeded)
            {
                var currentKeys = storedPhotos
                    .Select(value => value.StorageKey)
                    .ToHashSet(StringComparer.Ordinal);
                await DeleteStorageKeysBestEffortAsync(
                    obsoleteStorageKeys.Where(value => !currentKeys.Contains(value)));
                return result;
            }

            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
            return result;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
            throw;
        }
        catch (DbUpdateConcurrencyException)
        {
            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
            return ConcurrentConflict();
        }
        catch (DbUpdateException exception)
        {
            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
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
            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
            return Conflict(
                "photo_storage_error",
                "Fotoğraf özel dosya deposuna yazılamadı.");
        }
        catch (InvalidDataException)
        {
            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
            return Conflict(
                "photo_storage_error",
                "Fotoğraf içeriği aktarım sırasında doğrulanamadı.");
        }
        catch
        {
            await DeleteCreatedPhotosBestEffortAsync(storedPhotos);
            throw;
        }
    }

    public async Task<ApplicationLifecycleResult<ApplicationPhotoContent>> OpenReadAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        int photoId,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(actor.ActorUserId))
            errors["actor"] = ["Doğrulanmış kullanıcı bulunamadı."];
        if (applicationPublicId == Guid.Empty)
            errors["applicationPublicId"] = ["Başvuru kimliği zorunludur."];
        if (photoId <= 0)
            errors["photoId"] = ["Fotoğraf kimliği zorunludur."];
        if (errors.Count > 0)
            return new(ApplicationLifecycleStatus.InvalidInput, Errors: errors);

        var application = await FindScopedApplicationAsync(
            actor,
            applicationPublicId,
            tracking: false,
            cancellationToken);
        if (application is null)
            return PhotoNotFound();

        var photo = await dbContext.Set<ApplicationPhotoRecord>()
            .AsNoTracking()
            .SingleOrDefaultAsync(
                value => value.Id == photoId &&
                         value.ApplicationId == application.Id &&
                         !value.IsDeleted,
                cancellationToken);
        if (photo is null) return PhotoNotFound();

        try
        {
            var stream = await storage.OpenReadAsync(photo.StorageKey, cancellationToken);
            return new(
                ApplicationLifecycleStatus.Succeeded,
                new ApplicationPhotoContent(
                    stream,
                    photo.ContentType,
                    string.IsNullOrWhiteSpace(photo.OriginalFileName)
                        ? $"photo-{photo.Order}"
                        : photo.OriginalFileName));
        }
        catch (IOException exception)
        {
            logger.LogError(
                exception,
                "Application photo content is missing for {PhotoId}.",
                photoId);
            return new(
                ApplicationLifecycleStatus.Conflict,
                Code: "photo_content_missing",
                Detail: "Fotoğraf kaydı bulundu ancak dosya içeriğine ulaşılamadı.");
        }
    }

    private static IReadOnlyDictionary<string, string[]> Validate(
        UploadApplicationPhotosCommand command)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(command.Actor.ActorUserId))
            errors["actor"] = ["Doğrulanmış kullanıcı bulunamadı."];
        if (command.ApplicationPublicId == Guid.Empty)
            errors["applicationPublicId"] = ["Başvuru kimliği zorunludur."];
        if (!ApplicationDraftValidation.TryDecodeRowVersion(
                command.ExpectedRowVersion,
                out _))
            errors["expectedRowVersion"] = ["Geçerli RowVersion zorunludur."];
        if (string.IsNullOrWhiteSpace(command.IdempotencyKey) ||
            command.IdempotencyKey.Trim().Length is < 8 or > 100)
            errors["Idempotency-Key"] = ["8-100 karakterlik istek anahtarı zorunludur."];
        foreach (var error in ApplicationPhotoPolicy.Validate(command.Photos))
        {
            errors[error.Key] = error.Value;
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
                     value.CreatedByUserId == actor.ActorUserId,
            cancellationToken);
    }

    private Task<string?> FindStatusCodeAsync(
        int statusId,
        CancellationToken cancellationToken) =>
        CompanyApplicationStatusResolver.FindCodeAsync(
            dbContext,
            statusId,
            cancellationToken);

    private async Task<ApplicationDetails> ToDetailsAsync(
        ApplicationRecord application,
        CancellationToken cancellationToken)
    {
        var statusCode = await FindStatusCodeAsync(application.StatusId, cancellationToken)
            ?? throw new InvalidOperationException("Başvuru durum kodu bulunamadı.");
        var helpTypeCode = CompanyReferenceCode.Encode(
            ApplicationReferenceCodeQueries.HelpType,
            application.HelpTypeId);
        var disabilityTypeCode = application.DisabilityTypeId is null
            ? null
            : CompanyReferenceCode.Encode(
                ApplicationReferenceCodeQueries.DisabilityType,
                application.DisabilityTypeId.Value);
        return new(
            application.PublicId,
            application.ApplicationNumber ??
                application.Id.ToString(
                    System.Globalization.CultureInfo.InvariantCulture),
            statusCode,
            ApplicationStatusRules.IsEditable(statusCode),
            application.IdentityNumber,
            application.BirthDate,
            application.PhoneNumber,
            helpTypeCode,
            application.HasDisability,
            disabilityTypeCode,
            application.DisabilityRate is null
                ? null
                : checked((byte)application.DisabilityRate.Value),
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

    private static ApplicationLifecycleResult<ApplicationDetails>? ValidateReplay(
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
        return null;
    }

    private Task DeleteCreatedPhotosBestEffortAsync(
        IEnumerable<StoredApplicationPhoto> photos) =>
        DeleteStorageKeysBestEffortAsync(
            photos
                .Where(value => value.WasCreated)
                .Select(value => value.StorageKey));

    private async Task DeleteStorageKeysBestEffortAsync(IEnumerable<string> storageKeys)
    {
        foreach (var storageKey in storageKeys.Distinct(StringComparer.Ordinal))
        {
            try
            {
                await storage.DeleteAsync(storageKey, CancellationToken.None);
            }
            catch (Exception exception)
            {
                // Veritabani sonucu geri alinamayacagi icin temizlik hatasi ana
                // istegi bozmaz; operasyon ekibi logdan yetki/disk sorununu gorur.
                logger.LogWarning(
                    exception,
                    "Application photo storage cleanup failed for {StorageKey}.",
                    storageKey);
            }
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

    private static ApplicationLifecycleResult<ApplicationPhotoContent> PhotoNotFound() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "photo_not_found",
            Detail: "Fotoğraf bulunamadı.");

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
