namespace SosyoBel.Application.WorkItems;

public static class WorkItemSourceCodes
{
    public const string AssignedTask = "ASSIGNED_TASK";
    public const string OwnApplication = "OWN_APPLICATION";
}

/// <summary>
/// Ana ekranda gösterilecek tek karttır. Bir başvuru hem kullanıcı tarafından
/// oluşturulmuş hem de aynı kullanıcıya görev olarak atanmışsa sorgu tek kayıt döndürür.
/// </summary>
public sealed record UserWorkItemSummary(
    Guid ApplicationPublicId,
    Guid? TaskPublicId,
    string ApplicationNumber,
    string? ApplicantFullName,
    string? Address,
    string SourceCode,
    string StatusCode,
    bool IsCompleted,
    bool IsEditable,
    string? Description,
    DateTime ActivityAtUtc);
