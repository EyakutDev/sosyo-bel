namespace SosyoBel.Application.References;

/// <summary>
/// Mobil formlarda saklanacak kararlı kod ile kullanıcıya gösterilecek etiketi birlikte taşır.
/// Etiket değişse bile gönderilen kod değişmediği için mevcut kayıt sözleşmesi bozulmaz.
/// </summary>
public sealed record ApplicationReferenceOption(string Code, string Label);

public sealed record HouseholdQuestionOption(
    string Code,
    string Label,
    short Order);

public sealed record HouseholdQuestionDefinition(
    string Code,
    string Label,
    string AnswerTypeCode,
    bool IsRequired,
    short Order,
    IReadOnlyCollection<HouseholdQuestionOption> Options);

public sealed record ApplicationReferenceCatalog(
    IReadOnlyCollection<ApplicationReferenceOption> HelpTypes,
    IReadOnlyCollection<ApplicationReferenceOption> DisabilityStatuses,
    IReadOnlyCollection<ApplicationReferenceOption> Relationships,
    IReadOnlyCollection<ApplicationReferenceOption> EmploymentStatuses,
    IReadOnlyCollection<ApplicationReferenceOption> EducationStatuses,
    IReadOnlyCollection<ApplicationReferenceOption> VitalStatuses,
    IReadOnlyCollection<HouseholdQuestionDefinition> HouseholdQuestions);

public interface IApplicationReferenceQuery
{
    Task<ApplicationReferenceCatalog> GetAsync(
        CancellationToken cancellationToken = default);
}
