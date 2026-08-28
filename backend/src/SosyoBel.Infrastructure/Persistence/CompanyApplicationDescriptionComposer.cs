using System.Text;
using SosyoBel.Application.Applications;
using SosyoBel.Application.References;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// dbo.BasvuruAileFertleri tablosunda kolonu bulunmayan aile ayrıntılarını,
/// kararlaştırılan biçimde dbo.Basvurular.TalepAciklamasi sonuna ekler.
/// </summary>
internal static class CompanyApplicationDescriptionComposer
{
    private const string Separator = "--------------------";

    public static string? Compose(
        string? requestDescription,
        IReadOnlyCollection<ApplicationFamilyMemberData> familyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerData>? householdAnswers = null,
        string? extraNote = null)
    {
        ArgumentNullException.ThrowIfNull(familyMembers);
        householdAnswers ??= [];
        var normalizedDescription = NormalizeOptional(requestDescription);
        var normalizedExtraNote = NormalizeOptional(extraNote);
        if (familyMembers.Count == 0 &&
            householdAnswers.Count == 0 &&
            normalizedExtraNote is null)
            return normalizedDescription;

        var builder = new StringBuilder();
        if (normalizedDescription is not null)
        {
            builder.AppendLine(normalizedDescription);
            builder.AppendLine();
        }

        if (familyMembers.Count > 0)
        {
            builder.AppendLine(Separator);
            builder.AppendLine("Aile fertleri ek bilgileri");
            var index = 1;
            foreach (var member in familyMembers)
            {
                builder
                    .Append(index++)
                    .Append(". ")
                    .Append(CollapseToSingleLine(member.FullName))
                    .Append(" | Ölü/Sağ: ")
                    .Append(VitalStatusLabel(member.VitalStatusCode));

                if (string.Equals(
                        member.RelationshipCode,
                        CompanyRelationshipReferenceResolver.OtherCode,
                        StringComparison.Ordinal))
                {
                    builder
                        .Append(" | Diğer yakınlık: ")
                        .Append(CollapseToSingleLine(
                            member.OtherRelationshipDescription ?? string.Empty));
                }

                if (!string.IsNullOrWhiteSpace(member.DisabilityDescription))
                {
                    builder
                        .Append(" | Engel açıklaması: ")
                        .Append(CollapseToSingleLine(member.DisabilityDescription));
                }

                builder.AppendLine();
            }
        }

        if (householdAnswers.Count > 0)
        {
            builder.AppendLine(Separator);
            builder.AppendLine("Hane durumu bilgileri");
            var answersByQuestion = householdAnswers.ToDictionary(
                value => value.QuestionCode,
                StringComparer.Ordinal);
            foreach (var question in HouseholdFormContract.Questions)
            {
                if (!answersByQuestion.TryGetValue(question.Code, out var answer))
                    continue;

                var option = HouseholdFormContract.FindOption(
                    question,
                    answer.OptionCode) ?? throw new ArgumentException(
                    "Hane cevabı form sözleşmesiyle eşleşmiyor.",
                    nameof(householdAnswers));
                builder
                    .Append(question.Label.TrimEnd().TrimEnd('?'))
                    .Append(": ")
                    .AppendLine(option.Label);
            }
        }

        if (normalizedExtraNote is not null)
        {
            builder.AppendLine(Separator);
            builder.AppendLine("Haneye ait ekstra not");
            builder.AppendLine(CollapseToSingleLine(normalizedExtraNote));
        }

        return builder.ToString().TrimEnd();
    }

    private static string VitalStatusLabel(string code) => code switch
    {
        "SAG" => "Sağ",
        "OLU" => "Ölü",
        _ => throw new ArgumentOutOfRangeException(
            nameof(code),
            "Yaşam durumu SAG veya OLU olmalıdır."),
    };

    private static string CollapseToSingleLine(string value) =>
        string.Join(
            ' ',
            value.Split(
                [' ', '\t', '\r', '\n'],
                StringSplitOptions.RemoveEmptyEntries));

    private static string? NormalizeOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
