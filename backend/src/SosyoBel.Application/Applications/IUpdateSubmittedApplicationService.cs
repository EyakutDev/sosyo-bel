using System.Globalization;

namespace SosyoBel.Application.Applications;

/// <summary>
/// KPS tarafından doğrulanmış kimlik ve adres alanlarını değiştirmeden personelin
/// düzenleyebileceği başvuru alanlarını taşır.
/// </summary>
public sealed record SubmittedApplicationEditableData(
    string PhoneNumber,
    string HelpTypeCode,
    bool HasDisability,
    string? DisabilityTypeCode,
    byte? DisabilityRate,
    string? Description,
    string? FieldInspectionNote);

public sealed record UpdateSubmittedApplicationCommand(
    ApplicationActorContext Actor,
    int ApplicationId,
    SubmittedApplicationEditableData Application,
    IReadOnlyCollection<ApplicationFamilyMemberData> FamilyMembers,
    IReadOnlyCollection<ApplicationHouseholdAnswerData> HouseholdAnswers);

public sealed record UpdatedSubmittedApplication(
    int ApplicationId,
    Guid? ApplicationPublicId,
    string ApplicationNumber,
    string StatusCode,
    bool IsEditable)
{
    public static UpdatedSubmittedApplication Create(
        int applicationId,
        string? publicToken,
        string statusCode)
    {
        Guid? publicId = Guid.TryParseExact(publicToken, "N", out var parsed)
            ? parsed
            : null;
        return new(
            applicationId,
            publicId,
            $"#{applicationId.ToString(CultureInfo.InvariantCulture)}",
            statusCode,
            IsEditable: true);
    }
}

public interface IUpdateSubmittedApplicationService
{
    Task<ApplicationLifecycleResult<UpdatedSubmittedApplication>> UpdateAsync(
        UpdateSubmittedApplicationCommand command,
        CancellationToken cancellationToken);
}
