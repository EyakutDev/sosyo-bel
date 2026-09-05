using Microsoft.Extensions.Configuration;

namespace SosyoBel.Infrastructure.Logging;

public sealed class FileErrorLogOptions
{
    public const string SectionName = "FileErrorLogging";
    public string DirectoryPath { get; set; } = string.Empty;
    public int RetentionDays { get; set; } = 14;
    public int MaxFileSizeMB { get; set; } = 10;
    public int MaxTotalSizeMB { get; set; } = 200;

    // Hatalı/eksik log ayarı API'nin açılmasını engellemez; güvenli konsol
    // çıktısına dönülür. Sunucu yolu öğrenilene kadar DirectoryPath boş kalır.
    internal static FileErrorLogOptions Read(IConfiguration configuration)
    {
        try
        {
            return configuration.GetSection(SectionName)
                .Get<FileErrorLogOptions>() ?? new();
        }
        catch
        {
            return new();
        }
    }
}
