using System.Globalization;

namespace SosyoBel.Application.Applications;

/// <summary>
/// Başvuru güncellemesinde yalnız personelin değiştirebildiği alanları doğrular.
/// Kimlik, doğum tarihi ve adres bu sözleşmenin parçası değildir.
/// </summary>
public static class SubmittedApplicationUpdateValidation
{
    public static bool TryNormalize(
        SubmittedApplicationEditableData input,
        out SubmittedApplicationEditableData normalized,
        out IReadOnlyDictionary<string, string[]> errors)
    {
        ArgumentNullException.ThrowIfNull(input);
        var validationErrors = new Dictionary<string, string[]>();
        var phoneNumber = NormalizePhone(input.PhoneNumber);
        var helpTypeCode = NormalizeCode(input.HelpTypeCode);
        var disabilityTypeCode = NormalizeCode(input.DisabilityTypeCode);
        var description = NormalizeText(input.Description);
        var fieldInspectionNote = NormalizeText(input.FieldInspectionNote);

        if (phoneNumber.Length != 10)
            validationErrors["phoneNumber"] =
                ["Telefon numarası 10 rakam olmalıdır."];
        if (string.IsNullOrWhiteSpace(helpTypeCode) ||
            helpTypeCode.Length > 50)
        {
            validationErrors["helpTypeCode"] =
                ["Geçerli bir yardım türü kodu seçilmelidir."];
        }
        if (input.HasDisability &&
            (string.IsNullOrWhiteSpace(disabilityTypeCode) ||
             disabilityTypeCode.Length > 50))
        {
            validationErrors["disabilityTypeCode"] =
                ["Engel türü kodu seçilmelidir."];
        }
        else if (!input.HasDisability && disabilityTypeCode is not null)
        {
            validationErrors["disabilityTypeCode"] =
                ["Engel durumu yoksa engel türü gönderilmemelidir."];
        }
        if (!input.HasDisability && input.DisabilityRate is not null)
        {
            validationErrors["disabilityRate"] =
                ["Engel durumu yoksa engel oranı gönderilmemelidir."];
        }
        if (description?.Length > 1000)
            validationErrors["description"] =
                ["Alan en fazla 1000 karakter olabilir."];
        if (fieldInspectionNote?.Length > 2000)
            validationErrors["fieldInspectionNote"] =
                ["Alan en fazla 2000 karakter olabilir."];

        normalized = input with
        {
            PhoneNumber = phoneNumber,
            HelpTypeCode = helpTypeCode ?? string.Empty,
            DisabilityTypeCode =
                input.HasDisability ? disabilityTypeCode : null,
            DisabilityRate =
                input.HasDisability ? input.DisabilityRate : null,
            Description = description,
            FieldInspectionNote = fieldInspectionNote,
        };
        errors = validationErrors;
        return validationErrors.Count == 0;
    }

    private static string NormalizePhone(string? value)
    {
        var digits = string.Concat(
            (value ?? string.Empty).Where(char.IsAsciiDigit));
        if (digits.StartsWith("90", StringComparison.Ordinal) &&
            digits.Length == 12)
        {
            digits = digits[2..];
        }
        if (digits.StartsWith('0') && digits.Length == 11)
            digits = digits[1..];
        return digits;
    }

    private static string? NormalizeCode(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim().ToUpper(CultureInfo.InvariantCulture);

    private static string? NormalizeText(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
