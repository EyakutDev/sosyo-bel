using System.Diagnostics;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace SosyoBel.Infrastructure.Logging;

/// <summary>
/// Bilerek ham Message, StackTrace, log formatter/state veya exception.Data
/// kullanmaz. SQL mesajları kırpılan kolon değerlerini, HTTP hataları TCKN içeren
/// URL'leri taşıyabilir. Yalnız tür/numara ve kod metadatası kaydedilir.
/// </summary>
internal sealed record SafeErrorLogEntry(
    DateTimeOffset Timestamp,
    string Level,
    string Category,
    int EventId,
    string? Method,
    string? Route,
    string? TraceId,
    string Stage,
    string Summary,
    IReadOnlyList<SafeExceptionInfo> Exceptions)
{
    internal static readonly TimeZoneInfo TurkeyTimeZone = FindTurkeyTimeZone();

    public static SafeErrorLogEntry Create(
        DateTimeOffset now,
        LogLevel level,
        string category,
        EventId eventId,
        Exception? exception,
        RequestLogContext? context)
    {
        var exceptions = new List<SafeExceptionInfo>();
        var current = exception;
        while (current is not null && exceptions.Count < 5)
        {
            var frames = new StackTrace(current, fNeedFileInfo: false)
                .GetFrames()
                .Take(12)
                .Select(frame => frame.GetMethod())
                .Where(method => method is not null)
                .Select(method => $"{method!.DeclaringType?.FullName}.{method.Name}")
                .ToArray();
            var sqlErrors = current is SqlException sql
                ? sql.Errors.Cast<SqlError>().Take(8)
                    .Select(error => new SafeSqlError(error.Number, error.State, error.Class))
                    .ToArray()
                : [];
            exceptions.Add(new(
                current.GetType().FullName ?? current.GetType().Name,
                current.HResult,
                frames,
                sqlErrors));
            current = current.InnerException;
        }

        return new(
            TimeZoneInfo.ConvertTime(now, TurkeyTimeZone),
            level.ToString(),
            category,
            eventId.Id,
            context?.Method,
            context?.Route,
            context?.TraceId ?? Activity.Current?.Id,
            (context?.Stage ?? RequestLogStage.RequestHandling).ToString(),
            Describe(exceptions),
            exceptions);
    }

    private static string Describe(IReadOnlyList<SafeExceptionInfo> exceptions)
    {
        var numbers = exceptions.SelectMany(value => value.SqlErrors)
            .Select(value => value.Number).ToArray();
        if (numbers.Contains(515)) return "Veritabanında zorunlu bir alan boş kaldı.";
        if (numbers.Contains(207)) return "Veritabanında beklenen kolon bulunamadı.";
        if (numbers.Contains(208)) return "Veritabanında beklenen tablo veya nesne bulunamadı.";
        if (numbers.Contains(547)) return "Veritabanı ilişki veya kontrol kısıtı ihlal edildi.";
        if (numbers.Contains(2601) || numbers.Contains(2627))
            return "Veritabanında benzersiz kayıt kısıtı ihlal edildi.";
        if (numbers.Contains(229)) return "Veritabanı işlem yetkisi yetersiz.";
        if (numbers.Contains(-2)) return "Veritabanı işlem süresi aşıldı.";
        if (exceptions.Any(value => value.Type == typeof(UnauthorizedAccessException).FullName))
            return "Dosya veya klasöre erişim reddedildi.";
        if (exceptions.Any(value => value.Type == typeof(IOException).FullName))
            return "Dosya okuma veya yazma işlemi başarısız.";
        return "Hata türü, işlem aşaması ve kod konumu kontrol edilmeli; ham hata metni kaydedilmedi.";
    }

    private static TimeZoneInfo FindTurkeyTimeZone()
    {
        foreach (var id in new[] { "Europe/Istanbul", "Turkey Standard Time" })
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
            catch (TimeZoneNotFoundException) { }
            catch (InvalidTimeZoneException) { }
        }
        // ICU/saat dilimi verisi bulunmayan kurulumda sunucunun yerel saatine
        // düşmeyiz. Türkiye'nin mevcut UTC+03:00 ofseti korunur.
        return TimeZoneInfo.CreateCustomTimeZone(
            "TurkeyFallback", TimeSpan.FromHours(3), "Türkiye", "Türkiye");
    }
}

internal sealed record SafeExceptionInfo(
    string Type,
    int HResult,
    IReadOnlyList<string> Frames,
    IReadOnlyList<SafeSqlError> SqlErrors);

internal sealed record SafeSqlError(int Number, byte State, byte Severity);
