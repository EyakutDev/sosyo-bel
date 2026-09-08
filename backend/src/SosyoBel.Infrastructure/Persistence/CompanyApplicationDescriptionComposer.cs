using System.Text;
using SosyoBel.Application.Applications;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// dbo.BasvuruAileFertleri tablosunda kolonu bulunmayan aile ayrıntılarını,
/// ayrıca haneye ait ekstra notu dbo.Basvurular.TalepAciklamasi sonuna ekler.
/// </summary>
internal static class CompanyApplicationDescriptionComposer
{
    private const string Separator = "--------------------";
    private const string FamilyHeader = "Aile fertleri ek bilgileri";
    private const string ExtraNoteHeader = "Haneye ait ekstra not";
    private const string VitalStatusPrefix = "Ölü/Sağ: ";
    private const string OtherRelationshipPrefix = "Diğer yakınlık: ";
    private const string DisabilityDescriptionPrefix = "Engel açıklaması: ";

    public static string? Compose(
        string? requestDescription,
        IReadOnlyCollection<ApplicationFamilyMemberData> familyMembers,
        string? extraNote = null)
    {
        ArgumentNullException.ThrowIfNull(familyMembers);
        var normalizedDescription = NormalizeOptional(requestDescription);
        var normalizedExtraNote = NormalizeOptional(extraNote);
        if (familyMembers.Count == 0 &&
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
            builder.AppendLine(FamilyHeader);
            var index = 1;
            foreach (var member in familyMembers)
            {
                builder
                    .Append(index++)
                    .Append(". ")
                    .Append(CollapseToSingleLine(member.FullName))
                    .Append(" | ")
                    .Append(VitalStatusPrefix)
                    .Append(VitalStatusLabel(member.VitalStatusCode));

                if (string.Equals(
                        member.RelationshipCode,
                        CompanyRelationshipReferenceResolver.OtherCode,
                        StringComparison.Ordinal))
                {
                    builder
                        .Append(" | ")
                        .Append(OtherRelationshipPrefix)
                        .Append(CollapseToSingleLine(
                            member.OtherRelationshipDescription ?? string.Empty));
                }

                if (!string.IsNullOrWhiteSpace(member.DisabilityDescription))
                {
                    builder
                        .Append(" | ")
                        .Append(DisabilityDescriptionPrefix)
                        .Append(CollapseToSingleLine(member.DisabilityDescription));
                }

                builder.AppendLine();
            }
        }

        if (normalizedExtraNote is not null)
        {
            builder.AppendLine(Separator);
            builder.AppendLine(ExtraNoteHeader);
            builder.AppendLine(CollapseToSingleLine(normalizedExtraNote));
        }

        return builder.ToString().TrimEnd();
    }

    /// <summary>
    /// Daha önce Compose ile yazılmış açıklamayı düzenleme ekranı için tekrar
    /// bölümlere ayırır. Tanınmayan eski/web açıklamaları olduğu gibi korunur.
    /// </summary>
    public static CompanyApplicationDescriptionParts Parse(string? value)
    {
        var normalized = NormalizeOptional(value);
        if (normalized is null)
            return new(null, null, []);

        var lines = normalized
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n')
            .Split('\n');
        var familyHeaderIndex = FindSectionHeader(lines, FamilyHeader);
        var extraNoteHeaderIndex = FindSectionHeader(lines, ExtraNoteHeader);
        if (familyHeaderIndex < 0 && extraNoteHeaderIndex < 0)
            return new(normalized, null, []);

        var firstSeparatorIndex = new[]
            {
                familyHeaderIndex,
                extraNoteHeaderIndex,
            }
            .Where(index => index > 0)
            .Select(index => index - 1)
            .DefaultIfEmpty(lines.Length)
            .Min();
        var requestDescription = NormalizeOptional(string.Join(
            '\n',
            lines.Take(firstSeparatorIndex)));

        CompanyApplicationFamilyDescriptionPart[] family = [];
        if (familyHeaderIndex >= 0)
        {
            var familyEnd = extraNoteHeaderIndex > familyHeaderIndex
                ? extraNoteHeaderIndex - 1
                : lines.Length;
            family = lines
                .Skip(familyHeaderIndex + 1)
                .Take(familyEnd - familyHeaderIndex - 1)
                .Select(ParseFamilyLine)
                .Where(part => part is not null)
                .Select(part => part!)
                .ToArray();
        }

        var extraNote = extraNoteHeaderIndex < 0
            ? null
            : NormalizeOptional(string.Join(
                '\n',
                lines.Skip(extraNoteHeaderIndex + 1)));
        return new(requestDescription, extraNote, family);
    }

    private static int FindSectionHeader(string[] lines, string header)
    {
        for (var index = 1; index < lines.Length; index++)
        {
            if (string.Equals(lines[index].Trim(), header, StringComparison.Ordinal) &&
                string.Equals(
                    lines[index - 1].Trim(),
                    Separator,
                    StringComparison.Ordinal))
            {
                return index;
            }
        }

        return -1;
    }

    private static CompanyApplicationFamilyDescriptionPart? ParseFamilyLine(
        string line)
    {
        var normalized = line.Trim();
        var numberSeparator = normalized.IndexOf(". ", StringComparison.Ordinal);
        if (numberSeparator <= 0 ||
            !int.TryParse(normalized[..numberSeparator], out _))
        {
            return null;
        }

        var segments = normalized[(numberSeparator + 2)..]
            .Split(" | ", StringSplitOptions.None);
        string? vitalStatusCode = null;
        string? otherRelationshipDescription = null;
        string? disabilityDescription = null;
        foreach (var segment in segments.Skip(1))
        {
            if (segment.StartsWith(VitalStatusPrefix, StringComparison.Ordinal))
            {
                vitalStatusCode = segment[VitalStatusPrefix.Length..] switch
                {
                    "Sağ" => "SAG",
                    "Ölü" => "OLU",
                    _ => null,
                };
            }
            else if (segment.StartsWith(
                         OtherRelationshipPrefix,
                         StringComparison.Ordinal))
            {
                otherRelationshipDescription = NormalizeOptional(
                    segment[OtherRelationshipPrefix.Length..]);
            }
            else if (segment.StartsWith(
                         DisabilityDescriptionPrefix,
                         StringComparison.Ordinal))
            {
                disabilityDescription = NormalizeOptional(
                    segment[DisabilityDescriptionPrefix.Length..]);
            }
        }

        return new(
            vitalStatusCode,
            otherRelationshipDescription,
            disabilityDescription);
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

internal sealed record CompanyApplicationDescriptionParts(
    string? RequestDescription,
    string? ExtraNote,
    IReadOnlyList<CompanyApplicationFamilyDescriptionPart> FamilyMembers);

internal sealed record CompanyApplicationFamilyDescriptionPart(
    string? VitalStatusCode,
    string? OtherRelationshipDescription,
    string? DisabilityDescription);
