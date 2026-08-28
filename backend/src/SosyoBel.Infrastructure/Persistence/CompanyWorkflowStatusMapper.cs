using SosyoBel.Application.WorkItems;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirketin web uygulamasında ve mevcut dbo kayıtlarında kullanılan durumları,
/// mobil istemcinin kararlı durum kodlarına dönüştürür.
/// </summary>
internal static class CompanyWorkflowStatusMapper
{
    public static string MapFieldTask(string? companyStatus)
    {
        var status = companyStatus?.Trim();
        if (string.Equals(status, "Bekliyor", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Pending;
        if (string.Equals(status, "Onaya Gönderildi", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.BoardPending;
        if (string.Equals(status, "Onaylandı", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Completed;
        if (string.Equals(status, "Reddedildi", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Rejected;
        if (string.Equals(status, "İptal Edildi", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Canceled;

        // Yeni veya hatalı bir şirket değeri tamamlanmış varsayılmaz.
        return WorkItemStatusCodes.Unknown;
    }

    public static bool IsFieldTaskCompleted(string statusCode) =>
        statusCode is WorkItemStatusCodes.Completed or
            WorkItemStatusCodes.Rejected or
            WorkItemStatusCodes.Canceled;

    public static string MapApplication(string? companyStatus)
    {
        var status = companyStatus?.Trim();

        // Taslak ve Kurul Bekliyor yalnız eski yerel API verisini okuyabilmek
        // içindir. Şirket web uygulamasının canlı iş akışı Beklemede ile başlar.
        if (string.Equals(status, "Taslak", StringComparison.OrdinalIgnoreCase))
            return SosyoBel.Application.Applications.ApplicationStatusCodes.Draft;
        if (string.Equals(status, "Kurul Bekliyor", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(status, "Beklemede", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.BoardPending;
        if (string.Equals(status, "Kişi Oluşturuldu", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(status, "Yardım Onaylandı", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Completed;
        if (string.Equals(status, "İptal Edildi", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Canceled;
        if (string.Equals(status, "Yardım Reddedildi", StringComparison.OrdinalIgnoreCase))
            return WorkItemStatusCodes.Rejected;

        return WorkItemStatusCodes.Unknown;
    }

    public static bool IsApplicationCompleted(string statusCode) =>
        statusCode is WorkItemStatusCodes.Completed or
            WorkItemStatusCodes.Rejected or
            WorkItemStatusCodes.Canceled;
}
