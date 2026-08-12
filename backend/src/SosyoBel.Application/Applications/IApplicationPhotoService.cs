namespace SosyoBel.Application.Applications;

public sealed record ApplicationPhotoUpload(
    string FileName,
    string ContentType,
    long Length,
    byte Order,
    Stream Content);

public sealed record UploadApplicationPhotosCommand(
    ApplicationActorContext Actor,
    Guid ApplicationPublicId,
    string ExpectedRowVersion,
    string IdempotencyKey,
    IReadOnlyCollection<ApplicationPhotoUpload> Photos);

public interface IApplicationPhotoService
{
    Task<ApplicationLifecycleResult<ApplicationDetails>> UploadBatchAsync(
        UploadApplicationPhotosCommand command,
        CancellationToken cancellationToken);

    Task<ApplicationLifecycleResult<ApplicationPhotoContent>> OpenReadAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        int photoId,
        CancellationToken cancellationToken);
}

public sealed record ApplicationPhotoContent(
    Stream Content,
    string ContentType,
    string DownloadFileName);

public sealed record StoredApplicationPhoto(
    string StorageKey,
    string OriginalFileName,
    string ContentType,
    long Length,
    byte[] Sha256,
    byte Order,
    bool WasCreated);

/// <summary>
/// Fiziksel dosya sistemini API ve veritabanı kodundan ayırır. Şirket object
/// storage kullanırsa yalnız bu sözleşmenin implementasyonu değiştirilir.
/// </summary>
public interface IApplicationPhotoStorage
{
    Task<StoredApplicationPhoto> SaveAsync(
        int municipalityId,
        Guid applicationPublicId,
        ApplicationPhotoUpload photo,
        CancellationToken cancellationToken);

    Task DeleteAsync(
        string storageKey,
        CancellationToken cancellationToken);

    Task<Stream> OpenReadAsync(
        string storageKey,
        CancellationToken cancellationToken);
}
