using System.Security.Cryptography;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using SosyoBel.Application.Applications;

namespace SosyoBel.Infrastructure.Storage;

/// <summary>
/// Geliştirme ve tek IIS sunuculu kurulumlar için özel klasör deposudur.
/// Klasör web kökünün dışında tutulur; dışarıya doğrudan statik dosya sunulmaz.
/// </summary>
internal sealed class LocalApplicationPhotoStorage
    : IApplicationPhotoStorage
{
    private readonly string rootPath;

    public LocalApplicationPhotoStorage(
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        var configuredPath = configuration["ApplicationPhotos:RootPath"];
        if (string.IsNullOrWhiteSpace(configuredPath))
        {
            throw new InvalidOperationException(
                "ApplicationPhotos:RootPath yapılandırılmalıdır.");
        }

        rootPath = Path.GetFullPath(
            Path.IsPathRooted(configuredPath)
                ? configuredPath
                : Path.Combine(environment.ContentRootPath, configuredPath));
        Directory.CreateDirectory(rootPath);
    }

    public async Task<StoredApplicationPhoto> SaveAsync(
        int municipalityId,
        Guid applicationPublicId,
        ApplicationPhotoUpload photo,
        CancellationToken cancellationToken)
    {
        var temporaryDirectory = Path.Combine(rootPath, ".staging");
        Directory.CreateDirectory(temporaryDirectory);
        var temporaryPath = Path.Combine(
            temporaryDirectory,
            $"{Guid.NewGuid():N}.upload");
        byte[] hash;
        long written = 0;

        try
        {
            using var incrementalHash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            await using (var output = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: 81920,
                useAsync: true))
            {
                var buffer = new byte[81920];
                int read;
                while ((read = await photo.Content.ReadAsync(
                    buffer,
                    cancellationToken)) > 0)
                {
                    written += read;
                    incrementalHash.AppendData(buffer, 0, read);
                    await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                }
                await output.FlushAsync(cancellationToken);
            }
            hash = incrementalHash.GetHashAndReset();
            if (written != photo.Length)
                throw new InvalidDataException("Fotoğraf boyutu aktarım sırasında değişti.");

            var hashText = Convert.ToHexString(hash).ToLowerInvariant();
            var extension = ExtensionFor(photo.ContentType);
            var relativeDirectory = Path.Combine(
                municipalityId.ToString(System.Globalization.CultureInfo.InvariantCulture),
                applicationPublicId.ToString("N"));
            var relativePath = Path.Combine(
                relativeDirectory,
                $"{photo.Order:D2}-{hashText}{extension}");
            var finalPath = ResolveInsideRoot(relativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(finalPath)!);

            try
            {
                File.Move(temporaryPath, finalPath);
            }
            catch (IOException) when (File.Exists(finalPath))
            {
                // İçerik hash'i aynıysa ağ tekrarında aynı güvenli nesne kullanılır.
                File.Delete(temporaryPath);
            }

            return new StoredApplicationPhoto(
                relativePath.Replace(Path.DirectorySeparatorChar, '/'),
                SafeFileName(photo.FileName),
                photo.ContentType,
                written,
                hash,
                photo.Order);
        }
        catch
        {
            if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
            throw;
        }
    }

    private string ResolveInsideRoot(string relativePath)
    {
        var fullPath = Path.GetFullPath(Path.Combine(rootPath, relativePath));
        var rootWithSeparator = rootPath.TrimEnd(
            Path.DirectorySeparatorChar,
            Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (!fullPath.StartsWith(rootWithSeparator, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Geçersiz fotoğraf depolama yolu.");
        return fullPath;
    }

    private static string SafeFileName(string value)
    {
        var name = Path.GetFileName(value);
        if (string.IsNullOrWhiteSpace(name)) return "photo";
        return name.Length <= 255 ? name : name[..255];
    }

    private static string ExtensionFor(string contentType) =>
        contentType.ToLowerInvariant() switch
        {
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            "image/heic" => ".heic",
            "image/heif" => ".heif",
            _ => throw new InvalidDataException("Desteklenmeyen fotoğraf MIME türü."),
        };
}
