namespace SosyoBel.Application.Applications;

/// <summary>
/// Mobil ve şirket veritabanı fotoğraf akışlarının aynı dosya kurallarını
/// uygulamasını sağlar. Böylece endpoint değişse bile sınırlar farklılaşmaz.
/// </summary>
public static class ApplicationPhotoPolicy
{
    public const int MaximumPhotoCount = 15;
    public const long MaximumPhotoBytes = 10 * 1024 * 1024;

    private static readonly HashSet<string> AllowedContentTypes =
        ["image/jpeg", "image/png", "image/heic", "image/heif"];

    public static IReadOnlyDictionary<string, string[]> Validate(
        IReadOnlyCollection<ApplicationPhotoUpload> photos)
    {
        ArgumentNullException.ThrowIfNull(photos);
        var errors = new Dictionary<string, string[]>();
        if (photos.Count > MaximumPhotoCount)
        {
            errors["photos"] =
                [$"Bir defada en fazla {MaximumPhotoCount} fotoğraf yüklenmelidir."];
        }

        var orders = new HashSet<byte>();
        var index = 0;
        foreach (var photo in photos)
        {
            if (photo is null)
            {
                errors[$"photos[{index}]"] = ["Fotoğraf bilgisi zorunludur."];
                index++;
                continue;
            }

            if (photo.Order is < 1 or > MaximumPhotoCount ||
                !orders.Add(photo.Order))
            {
                errors[$"photos[{index}].order"] =
                    [$"Fotoğraf sırası 1-{MaximumPhotoCount} arasında ve benzersiz olmalıdır."];
            }
            if (photo.Length is < 1 or > MaximumPhotoBytes)
            {
                errors[$"photos[{index}].length"] =
                    ["Her fotoğraf en fazla 10 MB olabilir."];
            }
            if (string.IsNullOrWhiteSpace(photo.ContentType) ||
                !AllowedContentTypes.Contains(photo.ContentType.ToLowerInvariant()))
            {
                errors[$"photos[{index}].contentType"] =
                    ["Yalnız JPEG, PNG, HEIC veya HEIF kabul edilir."];
            }
            if (string.IsNullOrWhiteSpace(photo.FileName) ||
                photo.FileName.Length > 255)
            {
                errors[$"photos[{index}].fileName"] =
                    ["Geçerli dosya adı zorunludur."];
            }
            if (photo.Content is null || !photo.Content.CanRead)
            {
                errors[$"photos[{index}].content"] =
                    ["Okunabilir fotoğraf içeriği zorunludur."];
            }
            index++;
        }

        return errors;
    }
}
