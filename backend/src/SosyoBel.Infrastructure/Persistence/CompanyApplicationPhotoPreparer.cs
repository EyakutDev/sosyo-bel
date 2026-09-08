using SosyoBel.Application.Applications;
using Microsoft.Extensions.Logging;

namespace SosyoBel.Infrastructure.Persistence;

internal enum CompanyApplicationPhotoPreparationStatus
{
    Prepared,
    InvalidInput,
    StorageFailure,
}

internal sealed record CompanyApplicationPhotoPreparationResult(
    CompanyApplicationPhotoPreparationStatus Status,
    IReadOnlyCollection<CompanyHouseholdPhotoRecord>? Records = null,
    IReadOnlyCollection<StoredApplicationPhoto>? StoredPhotos = null,
    string? Code = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);

/// <summary>
/// Doğrulanmış mobil fotoğrafları fiziksel depoya yazar ve şirketin mevcut
/// dbo.HaneFotograflari satırlarını hazırlar. SaveChanges çağırmaz; başvuru,
/// aile ve fotoğraf satırları üst seviye serviste tek transaction ile yazılacaktır.
/// </summary>
internal sealed class CompanyApplicationPhotoPreparer(
    IApplicationPhotoStorage storage,
    TimeProvider timeProvider,
    ILogger<CompanyApplicationPhotoPreparer> logger)
{
    private const string CompanyWebUploadPrefix = "/uploads/hanefotograflari/";
    private const string CompanyPhotoDescription = "Başvuru Formundan Yüklendi";

    public async Task<CompanyApplicationPhotoPreparationResult> PrepareAsync(
        int citizenId,
        Guid applicationPublicId,
        IReadOnlyCollection<ApplicationPhotoUpload> photos,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        if (citizenId <= 0)
            errors["citizenId"] = ["Mevcut vatandaş kimliği zorunludur."];
        if (applicationPublicId == Guid.Empty)
            errors["applicationPublicId"] = ["Başvuru kimliği zorunludur."];
        foreach (var error in ApplicationPhotoPolicy.Validate(photos))
            errors[error.Key] = error.Value;
        if (errors.Count > 0)
        {
            return new(
                CompanyApplicationPhotoPreparationStatus.InvalidInput,
                Code: "invalid_application_photos",
                Errors: errors);
        }

        var storedPhotos = new List<StoredApplicationPhoto>(photos.Count);
        try
        {
            foreach (var photo in photos.OrderBy(value => value.Order))
            {
                storedPhotos.Add(await storage.SaveAsync(
                    applicationPublicId,
                    photo,
                    cancellationToken));
            }

            var uploadedAt = timeProvider.GetLocalNow().DateTime;
            var records = storedPhotos
                .Select(photo => CompanyHouseholdPhotoRecord.Create(
                    citizenId,
                    ToCompanyWebPath(photo.StorageKey),
                    CompanyPhotoDescription,
                    uploadedAt))
                .ToArray();
            return new(
                CompanyApplicationPhotoPreparationStatus.Prepared,
                records,
                storedPhotos);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            await DiscardAsync(storedPhotos);
            throw;
        }
        catch (IOException exception)
        {
            logger.LogWarning(new EventId(1001), exception, "Photo storage failed.");
            await DiscardAsync(storedPhotos);
            return new(
                CompanyApplicationPhotoPreparationStatus.StorageFailure,
                Code: "photo_storage_error");
        }
        catch (InvalidDataException exception)
        {
            logger.LogWarning(new EventId(1001), exception, "Photo storage failed.");
            await DiscardAsync(storedPhotos);
            return new(
                CompanyApplicationPhotoPreparationStatus.StorageFailure,
                Code: "photo_storage_error");
        }
        catch
        {
            await DiscardAsync(storedPhotos);
            throw;
        }
    }

    /// <summary>
    /// Üst seviye veritabanı transactionı başarısız olursa yalnız bu isteğin
    /// gerçekten oluşturduğu dosyaları geri alır.
    /// </summary>
    public async Task DiscardAsync(IEnumerable<StoredApplicationPhoto> photos)
    {
        foreach (var photo in photos
                     .Where(value => value.WasCreated)
                     .DistinctBy(value => value.StorageKey))
        {
            try
            {
                await storage.DeleteAsync(photo.StorageKey, CancellationToken.None);
            }
            catch (Exception exception)
            {
                logger.LogWarning(new EventId(1003), exception, "Photo cleanup failed.");
                // Asıl transaction hatasını gölgelememek için temizlik best-effort yapılır.
            }
        }
    }

    public Task<Stream> OpenReadAsync(
        string companyWebPath,
        CancellationToken cancellationToken) =>
        storage.OpenReadAsync(ToStorageKey(companyWebPath), cancellationToken);

    public async Task DeleteCompanyPathsAsync(
        IEnumerable<string> companyWebPaths,
        IEnumerable<string>? protectedCompanyWebPaths = null)
    {
        var protectedPaths = (protectedCompanyWebPaths ?? [])
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var companyWebPath in companyWebPaths
                     .Where(value => !protectedPaths.Contains(value))
                     .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                await storage.DeleteAsync(
                    ToStorageKey(companyWebPath),
                    CancellationToken.None);
            }
            catch (Exception exception)
            {
                logger.LogWarning(
                    new EventId(1003),
                    exception,
                    "Photo cleanup failed.");
            }
        }
    }

    internal static string ToCompanyWebPath(string storageKey)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(storageKey);
        var normalized = storageKey.Replace('\\', '/').Trim('/');
        var segments = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length == 0 ||
            segments.Any(segment => segment is "." or ".."))
        {
            throw new InvalidDataException("Geçersiz fotoğraf depolama anahtarı.");
        }

        // StorageKey, ApplicationPhotos:RootPath altındaki göreli dosya yoludur.
        // IIS'te RootPath fiziksel uploads/hanefotograflari klasörünü göstermelidir;
        // veritabanına fiziksel disk yolu değil, web uygulamasının URL yolu yazılır.
        return CompanyWebUploadPrefix + string.Join('/', segments);
    }

    internal static string ToStorageKey(string companyWebPath)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(companyWebPath);
        var normalized = companyWebPath.Replace('\\', '/');
        if (!normalized.StartsWith(
                CompanyWebUploadPrefix,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Geçersiz şirket fotoğraf yolu.");
        }

        var storageKey = normalized[CompanyWebUploadPrefix.Length..].Trim('/');
        var segments = storageKey.Split(
            '/',
            StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length != 2 ||
            segments.Any(segment => segment is "." or ".."))
        {
            throw new InvalidDataException("Geçersiz şirket fotoğraf yolu.");
        }
        return string.Join('/', segments);
    }

    internal static string ContentTypeForPath(string companyWebPath) =>
        Path.GetExtension(companyWebPath).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png" => "image/png",
            ".heic" => "image/heic",
            ".heif" => "image/heif",
            _ => "application/octet-stream",
        };
}
