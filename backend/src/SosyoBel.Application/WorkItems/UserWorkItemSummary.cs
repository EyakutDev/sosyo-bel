namespace SosyoBel.Application.WorkItems;

public static class WorkItemSourceCodes
{
    public const string AssignedTask = "ASSIGNED_TASK";
    public const string OwnApplication = "OWN_APPLICATION";
}

public static class WorkItemStatusCodes
{
    public const string Pending = "BEKLIYOR";
    public const string BoardPending = "KURUL_BEKLIYOR";
    public const string Completed = "TAMAMLANDI";
    public const string Rejected = "REDDEDILDI";
    public const string Canceled = "IPTAL";
    public const string Unknown = "BILINMEYEN";
}

/// <summary>
/// Ana ekranda gösterilecek tek karttır. Bir başvuru hem kullanıcı tarafından
/// oluşturulmuş hem de aynı kullanıcıya görev olarak atanmışsa sorgu tek kayıt döndürür.
/// </summary>
public sealed record UserWorkItemSummary(
    Guid? ApplicationPublicId,
    int? TaskId,
    string ApplicationNumber,
    string? ApplicantFullName,
    string? Address,
    string SourceCode,
    string StatusCode,
    bool IsCompleted,
    bool IsEditable,
    string? Description,
    DateTime ActivityAtUtc);
