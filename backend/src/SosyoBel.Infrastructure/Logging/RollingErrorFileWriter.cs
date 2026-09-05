using System.Globalization;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Text.Unicode;

namespace SosyoBel.Infrastructure.Logging;

/// <summary>
/// Yalnız sosyobel-YYYYMMDD-NNNN.log dosyalarını yönetir. Senkron ve sınırlı
/// yazım, hata oluştuğunda kaydın kuyrukta kaybolmasını önler. Bir yazım/izin
/// hatası çağıran iş akışına fırlatılmaz; arındırılmış kayıt konsola gönderilir.
/// </summary>
internal sealed class RollingErrorFileWriter
{
    private static readonly Regex ManagedName = new(
        @"^sosyobel-(\d{8})-(\d{4})\.log$",
        RegexOptions.CultureInvariant | RegexOptions.NonBacktracking);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Encoder = JavaScriptEncoder.Create(UnicodeRanges.All),
    };
    private readonly object gate = new();
    private readonly TimeProvider clock;
    private readonly Action<string> console;
    private readonly string? directory;
    private readonly int retentionDays;
    private readonly long maxFileBytes;
    private readonly long maxTotalBytes;
    private bool reportedFileFailure;

    public RollingErrorFileWriter(FileErrorLogOptions options, TimeProvider clock)
        : this(
            options.DirectoryPath,
            options.RetentionDays,
            (long)options.MaxFileSizeMB * 1024 * 1024,
            (long)options.MaxTotalSizeMB * 1024 * 1024,
            clock,
            Console.Error.WriteLine)
    {
    }

    // Byte sınırları küçük geçici klasörlerde de sınanabilir; üretim ayarı MB'dır.
    internal RollingErrorFileWriter(
        string directoryPath, int retentionDays, long maxFileBytes,
        long maxTotalBytes, TimeProvider clock, Action<string> console)
    {
        this.clock = clock;
        this.console = console;
        this.retentionDays = retentionDays;
        this.maxFileBytes = maxFileBytes;
        this.maxTotalBytes = maxTotalBytes;
        try
        {
            if (!string.IsNullOrWhiteSpace(directoryPath) &&
                Path.IsPathFullyQualified(directoryPath) &&
                retentionDays is >= 1 and <= 3650 &&
                maxFileBytes > 0 && maxTotalBytes >= maxFileBytes)
            {
                var full = Path.GetFullPath(directoryPath)
                    .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                // Disk kökü gibi geniş bir dizini log temizliğine açmayız.
                if (!string.Equals(
                    full,
                    Path.GetPathRoot(full)?.TrimEnd(
                        Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                    StringComparison.OrdinalIgnoreCase))
                {
                    directory = full;
                }
            }
        }
        catch
        {
            // Geçersiz yol yalnız dosya logunu devre dışı bırakır.
        }
    }

    public void Write(SafeErrorLogEntry entry)
    {
        string line;
        try { line = JsonSerializer.Serialize(entry, JsonOptions); }
        catch { ReportFailure(); return; }

        lock (gate)
        {
            try
            {
                if (directory is null) throw new IOException();
                var bytes = Encoding.UTF8.GetBytes(line + "\n");
                if (bytes.LongLength > maxFileBytes) throw new IOException();
                using var lease = OpenLease();
                var now = TurkeyNow();
                var files = ReadManagedFiles();
                RemoveExpired(files, now);
                var day = now.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
                var last = files.LastOrDefault(file =>
                    file.Name.StartsWith($"sosyobel-{day}-", StringComparison.Ordinal));
                var append = last is not null && last.Length + bytes.Length <= maxFileBytes;
                var sequence = last is null ? 1 : int.Parse(
                    ManagedName.Match(last.Name).Groups[2].Value,
                    CultureInfo.InvariantCulture) + (append ? 0 : 1);
                if (sequence > 9999) throw new IOException();
                var target = Path.Combine(directory, $"sosyobel-{day}-{sequence:D4}.log");
                RemoveOverBudget(files, bytes.Length, append ? target : null);
                EnsureManagedPath(target);
                using var stream = new FileStream(
                    target, FileMode.Append, FileAccess.Write, FileShare.Read);
                if (stream.Length + bytes.Length > maxFileBytes) throw new IOException();
                stream.Write(bytes);
                reportedFileFailure = false;
            }
            catch
            {
                // Ham exception/klasör yolu konsola da taşınmaz.
                ReportFailure();
                SafeConsole(line);
            }
        }
    }

    public void Prune()
    {
        lock (gate)
        {
            try
            {
                if (directory is null) { ReportFailure(); return; }
                using var lease = OpenLease();
                var files = ReadManagedFiles();
                RemoveExpired(files, TurkeyNow());
                RemoveOverBudget(files, 0, null);
            }
            catch { ReportFailure(); }
        }
    }

    private FileStream OpenLease()
    {
        var root = Directory.CreateDirectory(directory!);
        if ((root.Attributes & FileAttributes.ReparsePoint) != 0) throw new IOException();
        var leasePath = Path.Combine(directory!, ".sosyobel-writer.lock");
        if (File.Exists(leasePath) &&
            (File.GetAttributes(leasePath) & FileAttributes.ReparsePoint) != 0)
            throw new IOException();
        // IIS recycle sırasında iki worker aynı dizine yazarsa boyut/rotasyon
        // hesabı yarışmaz. Kilit alınamazsa kayıt güvenli konsola düşer.
        return new FileStream(
            leasePath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
    }

    private List<FileInfo> ReadManagedFiles() =>
        new DirectoryInfo(directory!).EnumerateFiles("sosyobel-*.log")
            .Where(file =>
                ManagedName.IsMatch(file.Name) &&
                DateOnly.TryParseExact(
                    ManagedName.Match(file.Name).Groups[1].Value, "yyyyMMdd",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out _) &&
                (file.Attributes & FileAttributes.ReparsePoint) == 0)
            .OrderBy(file => file.Name, StringComparer.Ordinal)
            .ToList();

    private void RemoveExpired(List<FileInfo> files, DateTimeOffset now)
    {
        foreach (var file in files.ToArray())
        {
            var day = DateOnly.ParseExact(
                ManagedName.Match(file.Name).Groups[1].Value, "yyyyMMdd",
                CultureInfo.InvariantCulture);
            if (day.ToDateTime(TimeOnly.MinValue) >= now.DateTime.AddDays(-retentionDays))
                continue;
            DeleteManagedFile(file);
            files.Remove(file);
        }
    }

    private void RemoveOverBudget(List<FileInfo> files, long incomingBytes, string? keepPath)
    {
        var total = files.Sum(file => file.Length);
        foreach (var file in files.ToArray())
        {
            if (total + incomingBytes <= maxTotalBytes) return;
            if (string.Equals(file.FullName, keepPath, StringComparison.OrdinalIgnoreCase))
                continue;
            var length = file.Length;
            DeleteManagedFile(file);
            files.Remove(file);
            total -= length;
        }
        if (total + incomingBytes > maxTotalBytes) throw new IOException();
    }

    private void EnsureManagedPath(string path)
    {
        var full = Path.GetFullPath(path);
        if (!string.Equals(Path.GetDirectoryName(full), directory, StringComparison.OrdinalIgnoreCase) ||
            !ManagedName.IsMatch(Path.GetFileName(full)) ||
            (File.Exists(full) && (File.GetAttributes(full) & FileAttributes.ReparsePoint) != 0))
            throw new IOException();
    }

    private void DeleteManagedFile(FileInfo file)
    {
        EnsureManagedPath(file.FullName);
        File.Delete(file.FullName);
    }

    private DateTimeOffset TurkeyNow() =>
        TimeZoneInfo.ConvertTime(clock.GetUtcNow(), SafeErrorLogEntry.TurkeyTimeZone);

    private void ReportFailure()
    {
        if (reportedFileFailure) return;
        reportedFileFailure = true;
        SafeConsole(
            $"{TurkeyNow():yyyy-MM-dd HH:mm:ss zzz} [Warning] file_log_unavailable: " +
            "Dosya logu yazılamıyor. Log yolu, izinler ve disk alanı kontrol edilmeli; " +
            "güvenli hata kayıtları konsola yönlendiriliyor.");
    }

    private void SafeConsole(string message)
    {
        try { console(message); }
        catch { /* Konsol arızası da uygulama isteğini etkilemez. */ }
    }
}
