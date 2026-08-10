using System.Globalization;

namespace SosyoBel.Application.Applications;

/// <summary>
/// Manuel aile ve hane girişlerini referans kodları çözülmeden önce doğrular ve
/// aynı kod biçimine getirir. Tasarım fixture'ı veya serbest etiket üretmez.
/// </summary>
public static class ApplicationFieldDataValidation
{
    public static bool TryNormalize(
        IReadOnlyCollection<ApplicationFamilyMemberData>? familyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? householdAnswers,
        bool saveToBeneficiaryDirectory,
        out IReadOnlyCollection<ApplicationFamilyMemberData> normalizedFamily,
        out IReadOnlyCollection<ApplicationHouseholdAnswerData> normalizedAnswers,
        out IReadOnlyDictionary<string, string[]> errors)
    {
        var validationErrors = new Dictionary<string, string[]>();
        var family = familyMembers?.ToArray() ?? [];
        var answers = householdAnswers?.ToArray() ?? [];

        if (family.Length > 50)
            validationErrors["familyMembers"] = ["Bir başvuruda en fazla 50 aile üyesi olabilir."];
        if (answers.Length > 100)
            validationErrors["householdAnswers"] = ["Bir başvuruda en fazla 100 hane cevabı olabilir."];
        if (saveToBeneficiaryDirectory)
        {
            validationErrors["saveToBeneficiaryDirectory"] =
                ["Vatandaş profili bağlantısı kurulmadan aile bilgileri ortak rehbere kaydedilemez."];
        }

        var normalizedFamilyItems = new List<ApplicationFamilyMemberData>(family.Length);
        for (var index = 0; index < family.Length; index++)
        {
            var item = family[index];
            var prefix = $"familyMembers[{index}]";
            var fullName = NormalizeText(item.FullName);
            var relationshipCode = NormalizeCode(item.RelationshipCode);
            var otherRelationship = NormalizeText(item.OtherRelationshipDescription);
            var disabilityTypeCode = NormalizeCode(item.DisabilityTypeCode);
            var disabilityDescription = NormalizeText(item.DisabilityDescription);
            var employmentCode = NormalizeCode(item.EmploymentStatusCode);
            var educationCode = NormalizeCode(item.EducationStatusCode);
            var vitalCode = NormalizeCode(item.VitalStatusCode);

            ValidateRequiredText(fullName, $"{prefix}.fullName", 200, validationErrors);
            if (item.Age is < 0 or > 130)
                validationErrors[$"{prefix}.age"] = ["Yaş 0-130 arasında olmalıdır."];
            ValidateRequiredCode(relationshipCode, $"{prefix}.relationshipCode", validationErrors);
            ValidateRequiredCode(employmentCode, $"{prefix}.employmentStatusCode", validationErrors);
            ValidateRequiredCode(educationCode, $"{prefix}.educationStatusCode", validationErrors);
            ValidateRequiredCode(vitalCode, $"{prefix}.vitalStatusCode", validationErrors);

            if (relationshipCode == "DIGER")
                ValidateRequiredText(otherRelationship, $"{prefix}.otherRelationshipDescription", 100, validationErrors);
            else if (otherRelationship is not null)
                validationErrors[$"{prefix}.otherRelationshipDescription"] =
                    ["Diğer açıklaması yalnız DIGER yakınlık koduyla gönderilebilir."];

            if (item.HasDisability)
                ValidateRequiredCode(disabilityTypeCode, $"{prefix}.disabilityTypeCode", validationErrors);
            else if (disabilityTypeCode is not null || disabilityDescription is not null)
                validationErrors[$"{prefix}.disabilityTypeCode"] =
                    ["Engel durumu yoksa engel ayrıntısı gönderilemez."];

            if (disabilityDescription?.Length > 250)
                validationErrors[$"{prefix}.disabilityDescription"] =
                    ["Engel açıklaması en fazla 250 karakter olabilir."];

            normalizedFamilyItems.Add(item with
            {
                FullName = fullName ?? string.Empty,
                RelationshipCode = relationshipCode ?? string.Empty,
                OtherRelationshipDescription = relationshipCode == "DIGER" ? otherRelationship : null,
                DisabilityTypeCode = item.HasDisability ? disabilityTypeCode : null,
                DisabilityDescription = item.HasDisability ? disabilityDescription : null,
                EmploymentStatusCode = employmentCode ?? string.Empty,
                EducationStatusCode = educationCode ?? string.Empty,
                VitalStatusCode = vitalCode ?? string.Empty,
            });
        }

        var normalizedAnswerItems = new List<ApplicationHouseholdAnswerData>(answers.Length);
        var questionCodes = new HashSet<string>(StringComparer.Ordinal);
        for (var index = 0; index < answers.Length; index++)
        {
            var answer = answers[index];
            var questionCode = NormalizeCode(answer.QuestionCode);
            var optionCode = NormalizeCode(answer.OptionCode);
            ValidateRequiredCode(questionCode, $"householdAnswers[{index}].questionCode", validationErrors, 80);
            ValidateRequiredCode(optionCode, $"householdAnswers[{index}].optionCode", validationErrors, 80);
            if (questionCode is not null && !questionCodes.Add(questionCode))
            {
                validationErrors[$"householdAnswers[{index}].questionCode"] =
                    ["Aynı hane sorusu birden fazla gönderilemez."];
            }
            normalizedAnswerItems.Add(new(
                questionCode ?? string.Empty,
                optionCode ?? string.Empty));
        }

        normalizedFamily = normalizedFamilyItems;
        normalizedAnswers = normalizedAnswerItems;
        errors = validationErrors;
        return validationErrors.Count == 0;
    }

    private static void ValidateRequiredText(
        string? value,
        string field,
        int maxLength,
        IDictionary<string, string[]> errors)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > maxLength)
            errors[field] = [$"Alan zorunludur ve en fazla {maxLength} karakter olabilir."];
    }

    private static void ValidateRequiredCode(
        string? value,
        string field,
        IDictionary<string, string[]> errors,
        int maxLength = 50)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > maxLength)
            errors[field] = [$"Geçerli bir kod zorunludur; en fazla {maxLength} karakter olabilir."];
    }

    private static string? NormalizeText(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string? NormalizeCode(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim().ToUpper(CultureInfo.InvariantCulture);
}
