namespace SosyoBel.Application.Applications;

/// <summary>
/// Veritabanında saklanan kararlı başvuru durum kodlarıdır. Kullanıcıya gösterilen
/// Türkçe etiketler değişse bile iş kuralları bu kodlarla çalışmaya devam eder.
/// </summary>
public static class ApplicationStatusCodes
{
    public const string Draft = "TASLAK";
    public const string PendingBoard = "KURUL_BEKLIYOR";
    public const string Completed = "TAMAMLANDI";
}

public static class ApplicationStatusRules
{
    public static bool IsEditable(string? statusCode) =>
        string.Equals(statusCode, ApplicationStatusCodes.Draft, StringComparison.Ordinal);

    public static bool CanSubmitToBoard(string? statusCode) => IsEditable(statusCode);
}
