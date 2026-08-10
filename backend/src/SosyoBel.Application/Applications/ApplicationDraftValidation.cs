using System.Globalization;

namespace SosyoBel.Application.Applications;

/// <summary>
/// API ve veri erişim katmanlarının aynı doğrulama ve normalizasyon kurallarını
/// kullanmasını sağlar. Belediye seçeneklerinin kendisi burada üretilmez.
/// </summary>
public static class ApplicationDraftValidation
{
    public static bool TryNormalize(
        ApplicationDraftData input,
        DateOnly today,
        out ApplicationDraftData normalized,
        out IReadOnlyDictionary<string, string[]> errors)
    {
        ArgumentNullException.ThrowIfNull(input);
        var validationErrors = new Dictionary<string, string[]>();
        var identityNumber = DigitsOnly(input.IdentityNumber);
        var phoneNumber = NormalizePhone(input.PhoneNumber);
        var helpTypeCode = NormalizeCode(input.HelpTypeCode);
        var disabilityTypeCode = NormalizeCode(input.DisabilityTypeCode);

        ValidateIdentityAndContact(input, today, identityNumber, phoneNumber, validationErrors);
        ValidateReferenceCodes(input, helpTypeCode, disabilityTypeCode, validationErrors);
        ValidateTextLengths(input, validationErrors);

        normalized = Normalize(
            input,
            identityNumber,
            phoneNumber,
            helpTypeCode,
            disabilityTypeCode);
        errors = validationErrors;
        return validationErrors.Count == 0;
    }

    public static bool TryDecodeRowVersion(string? value, out byte[] rowVersion)
    {
        rowVersion = [];
        if (string.IsNullOrWhiteSpace(value)) return false;

        try
        {
            rowVersion = Convert.FromBase64String(value.Trim());
            return rowVersion.Length == 8;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static void ValidateIdentityAndContact(
        ApplicationDraftData input,
        DateOnly today,
        string identityNumber,
        string phoneNumber,
        IDictionary<string, string[]> errors)
    {
        if (identityNumber.Length != 11)
        {
            errors.Add("identityNumber", ["T.C. kimlik numarası 11 rakam olmalıdır."]);
        }
        if (input.BirthDate > today)
        {
            errors.Add("birthDate", ["Doğum tarihi gelecekte olamaz."]);
        }
        if (phoneNumber.Length != 10)
        {
            errors.Add("phoneNumber", ["Telefon numarası 10 rakam olmalıdır."]);
        }
    }

    private static void ValidateReferenceCodes(
        ApplicationDraftData input,
        string? helpTypeCode,
        string? disabilityTypeCode,
        IDictionary<string, string[]> errors)
    {
        if (string.IsNullOrWhiteSpace(helpTypeCode) || helpTypeCode.Length > 50)
        {
            errors.Add("helpTypeCode", ["Geçerli bir yardım türü kodu seçilmelidir."]);
        }
        if (input.HasDisability &&
            (string.IsNullOrWhiteSpace(disabilityTypeCode) || disabilityTypeCode.Length > 50))
        {
            errors.Add("disabilityTypeCode", ["Engel türü kodu seçilmelidir."]);
        }
        else if (!input.HasDisability && disabilityTypeCode is not null)
        {
            errors.Add("disabilityTypeCode", ["Engel durumu yoksa engel türü gönderilmemelidir."]);
        }
        if (!input.HasDisability && input.DisabilityRate is not null)
        {
            errors.Add("disabilityRate", ["Engel durumu yoksa engel oranı gönderilmemelidir."]);
        }
    }

    private static void ValidateTextLengths(
        ApplicationDraftData input,
        IDictionary<string, string[]> errors)
    {
        ValidateOptionalText(input.Description, "description", 1000, errors);
        ValidateOptionalText(input.ApplicantFirstName, "applicantFirstName", 100, errors);
        ValidateOptionalText(input.ApplicantLastName, "applicantLastName", 100, errors);
        ValidateOptionalText(input.Address, "address", 500, errors);
        ValidateOptionalText(input.FieldInspectionNote, "fieldInspectionNote", 2000, errors);
    }

    private static ApplicationDraftData Normalize(
        ApplicationDraftData input,
        string identityNumber,
        string phoneNumber,
        string? helpTypeCode,
        string? disabilityTypeCode) =>
        input with
        {
            IdentityNumber = identityNumber,
            PhoneNumber = phoneNumber,
            HelpTypeCode = helpTypeCode ?? string.Empty,
            DisabilityTypeCode = input.HasDisability ? disabilityTypeCode : null,
            DisabilityRate = input.HasDisability ? input.DisabilityRate : null,
            Description = NormalizeOptionalText(input.Description),
            ApplicantFirstName = NormalizeOptionalText(input.ApplicantFirstName),
            ApplicantLastName = NormalizeOptionalText(input.ApplicantLastName),
            Address = NormalizeOptionalText(input.Address),
            FieldInspectionNote = NormalizeOptionalText(input.FieldInspectionNote),
        };

    private static string DigitsOnly(string? value) =>
        string.Concat((value ?? string.Empty).Where(char.IsAsciiDigit));

    private static string NormalizePhone(string? value)
    {
        var digits = DigitsOnly(value);
        if (digits.StartsWith("90", StringComparison.Ordinal) && digits.Length == 12)
        {
            digits = digits[2..];
        }
        if (digits.StartsWith('0') && digits.Length == 11)
        {
            digits = digits[1..];
        }
        return digits;
    }

    private static string? NormalizeCode(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim().ToUpper(CultureInfo.InvariantCulture);

    private static string? NormalizeOptionalText(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void ValidateOptionalText(
        string? value,
        string fieldName,
        int maxLength,
        IDictionary<string, string[]> errors)
    {
        if (value?.Trim().Length > maxLength)
        {
            errors.Add(fieldName, [$"Alan en fazla {maxLength} karakter olabilir."]);
        }
    }
}
