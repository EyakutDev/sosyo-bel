namespace SosyoBel.Application.Applications;

/// <summary>
/// Şirketin mevcut dbo başvuru tablolarından okunmuş, mobil detay ekranını
/// eksiksiz kurmaya yetecek başvuru görünümüdür.
/// </summary>
public sealed record SubmittedApplicationDetails(
    int ApplicationId,
    Guid? ApplicationPublicId,
    string ApplicationNumber,
    string StatusCode,
    bool IsOwnedByCurrentUser,
    bool IsEditable,
    DateTime ApplicationDate,
    string IdentityNumber,
    string FirstName,
    string LastName,
    DateOnly? BirthDate,
    string PhoneNumber,
    string HelpTypeCode,
    bool HasDisability,
    string? DisabilityTypeCode,
    int? DisabilityRate,
    string? Description,
    string? FieldInspectionNote,
    string? Address,
    string? Gender,
    string? BirthPlace,
    string? MaritalStatus,
    string? CancellationDescription,
    DateTime? CancellationDate,
    IReadOnlyCollection<ApplicationFamilyMemberSnapshot> FamilyMembers,
    IReadOnlyCollection<ApplicationHouseholdAnswerData> HouseholdAnswers,
    IReadOnlyCollection<SubmittedApplicationPhotoSnapshot> Photos);

public sealed record SubmittedApplicationPhotoSnapshot(
    int PhotoId,
    string UrlPath,
    string? Description,
    DateTime UploadedAt);

public interface ISubmittedApplicationDetailQuery
{
    Task<ApplicationLifecycleResult<SubmittedApplicationDetails>> GetAsync(
        ApplicationActorContext actor,
        int applicationId,
        CancellationToken cancellationToken);
}

public interface ISubmittedApplicationPhotoQuery
{
    Task<ApplicationLifecycleResult<ApplicationPhotoContent>> OpenReadAsync(
        ApplicationActorContext actor,
        int applicationId,
        int photoId,
        CancellationToken cancellationToken);
}
