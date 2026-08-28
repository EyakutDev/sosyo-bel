using SosyoBel.Application.Applications;
using SosyoBel.Application.References;

namespace SosyoBel.Infrastructure.Persistence;

internal enum CompanyApplicationHouseholdPreparationStatus
{
    Prepared,
    InvalidInput,
}

internal sealed record CompanyApplicationHouseholdPreparationResult(
    CompanyApplicationHouseholdPreparationStatus Status,
    IReadOnlyCollection<ApplicationHouseholdAnswerData>? Answers = null,
    string? Code = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);

/// <summary>
/// Hane cevaplarını sabit mobil form sözleşmesine göre doğrular. Ayrı bir tabloya
/// yazmaz; doğrulanmış cevaplar TalepAciklamasi metnine eklenecektir.
/// </summary>
internal static class CompanyApplicationHouseholdPreparer
{
    public static CompanyApplicationHouseholdPreparationResult Prepare(
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? householdAnswers)
    {
        if (!ApplicationFieldDataValidation.TryNormalize(
                [],
                householdAnswers,
                saveToBeneficiaryDirectory: false,
                out _,
                out var normalizedAnswers,
                out var normalizationErrors))
        {
            return Invalid(normalizationErrors);
        }

        var errors = new Dictionary<string, string[]>();
        var answersByQuestion = normalizedAnswers
            .Select((answer, index) => new { Answer = answer, Index = index })
            .ToDictionary(value => value.Answer.QuestionCode, StringComparer.Ordinal);

        foreach (var indexedAnswer in answersByQuestion.Values)
        {
            var question = HouseholdFormContract.FindQuestion(
                indexedAnswer.Answer.QuestionCode);
            if (question is null)
            {
                errors[$"householdAnswers[{indexedAnswer.Index}].questionCode"] =
                    ["Hane sorusu uygulama sözleşmesinde bulunamadı."];
                continue;
            }

            if (HouseholdFormContract.FindOption(
                    question,
                    indexedAnswer.Answer.OptionCode) is null)
            {
                errors[$"householdAnswers[{indexedAnswer.Index}].optionCode"] =
                    ["Seçenek bu hane sorusuna ait değildir."];
            }
        }

        foreach (var requiredQuestion in HouseholdFormContract.Questions
                     .Where(value => value.IsRequired))
        {
            if (!answersByQuestion.ContainsKey(requiredQuestion.Code))
            {
                errors[$"householdAnswers.{requiredQuestion.Code}"] =
                    [$"{requiredQuestion.Label} sorusu zorunludur."];
            }
        }

        if (errors.Count > 0) return Invalid(errors);

        var orderedAnswers = HouseholdFormContract.Questions
            .Select(question => answersByQuestion[question.Code].Answer)
            .ToArray();
        return new CompanyApplicationHouseholdPreparationResult(
            CompanyApplicationHouseholdPreparationStatus.Prepared,
            orderedAnswers);
    }

    private static CompanyApplicationHouseholdPreparationResult Invalid(
        IReadOnlyDictionary<string, string[]> errors) =>
        new(
            CompanyApplicationHouseholdPreparationStatus.InvalidInput,
            Code: "invalid_application_household",
            Errors: errors);
}
