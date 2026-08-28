namespace SosyoBel.Application.Applications;

/// <summary>
/// Telefonda tutulan tamamlanmış taslağın kurula tek istekte gönderilme
/// sözleşmesidir. Sunucu taslağı veya ara ekranları veritabanında saklamaz.
/// </summary>
public sealed record SubmitCompletedApplicationCommand(
    ApplicationActorContext Actor,
    string IdempotencyKey,
    ApplicationDraftData Draft,
    IReadOnlyCollection<ApplicationFamilyMemberData> FamilyMembers,
    IReadOnlyCollection<ApplicationHouseholdAnswerData> HouseholdAnswers,
    IReadOnlyCollection<ApplicationPhotoUpload> Photos);

public sealed record CompletedApplicationSubmission(
    Guid ApplicationPublicId,
    string ApplicationNumber,
    string StatusCode,
    bool IsEditable);

public interface ICompletedApplicationSubmissionService
{
    Task<ApplicationLifecycleResult<CompletedApplicationSubmission>> SubmitAsync(
        SubmitCompletedApplicationCommand command,
        CancellationToken cancellationToken);
}
