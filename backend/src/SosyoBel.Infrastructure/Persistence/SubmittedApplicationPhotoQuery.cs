using SosyoBel.Application.Applications;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirketin dbo.HaneFotograflari kaydını, başvuru detayıyla aynı erişim kuralını
/// uygulayarak fiziksel depodan açar. Eski SosyoBel fotoğraf tablolarını kullanmaz.
/// </summary>
internal sealed class SubmittedApplicationPhotoQuery(
    ISubmittedApplicationDetailQuery detailQuery,
    CompanyApplicationPhotoPreparer photoPreparer)
    : ISubmittedApplicationPhotoQuery
{
    public async Task<ApplicationLifecycleResult<ApplicationPhotoContent>>
        OpenReadAsync(
            ApplicationActorContext actor,
            int applicationId,
            int photoId,
            CancellationToken cancellationToken)
    {
        if (applicationId <= 0 || photoId <= 0)
        {
            return new(
                ApplicationLifecycleStatus.InvalidInput,
                Code: "invalid_application_photo_request",
                Errors: new Dictionary<string, string[]>
                {
                    [applicationId <= 0 ? "applicationId" : "photoId"] =
                        ["Kimlik değeri sıfırdan büyük olmalıdır."],
                });
        }

        var detail = await detailQuery.GetAsync(
            actor,
            applicationId,
            cancellationToken);
        if (detail.Status != ApplicationLifecycleStatus.Succeeded ||
            detail.Value is null)
        {
            return new(
                detail.Status,
                Code: detail.Code,
                Detail: detail.Detail,
                Errors: detail.Errors);
        }

        var photo = detail.Value.Photos.SingleOrDefault(
            value => value.PhotoId == photoId);
        if (photo is null)
        {
            return new(
                ApplicationLifecycleStatus.NotFound,
                Code: "application_photo_not_found",
                Detail: "Başvuru fotoğrafı bulunamadı.");
        }

        return await OpenFileAsync(photo, cancellationToken);
    }

    private async Task<ApplicationLifecycleResult<ApplicationPhotoContent>>
        OpenFileAsync(
            SubmittedApplicationPhotoSnapshot photo,
            CancellationToken cancellationToken)
    {
        try
        {
            var content = await photoPreparer.OpenReadAsync(
                photo.UrlPath,
                cancellationToken);
            return new(
                ApplicationLifecycleStatus.Succeeded,
                new ApplicationPhotoContent(
                    content,
                    CompanyApplicationPhotoPreparer.ContentTypeForPath(
                        photo.UrlPath),
                    Path.GetFileName(photo.UrlPath)));
        }
        catch (FileNotFoundException)
        {
            return PhotoFileNotFound();
        }
        catch (DirectoryNotFoundException)
        {
            return PhotoFileNotFound();
        }
        catch (InvalidDataException)
        {
            return new(
                ApplicationLifecycleStatus.Conflict,
                Code: "invalid_application_photo_path",
                Detail: "Başvuru fotoğraf yolu geçersiz.");
        }
    }

    private static ApplicationLifecycleResult<ApplicationPhotoContent>
        PhotoFileNotFound() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "application_photo_file_not_found",
            Detail: "Başvuru fotoğraf dosyası bulunamadı.");
}
