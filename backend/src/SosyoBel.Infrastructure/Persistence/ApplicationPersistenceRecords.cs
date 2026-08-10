using SosyoBel.Application.Applications;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class ApplicationRecord
{
    private ApplicationRecord()
    {
    }

    public int Id { get; private set; }
    public Guid PublicId { get; private set; }
    public int MunicipalityId { get; private set; }
    public string ApplicationNumber { get; private set; } = string.Empty;
    public string IdentityNumber { get; private set; } = string.Empty;
    public string? ApplicantFirstName { get; private set; }
    public string? ApplicantLastName { get; private set; }
    public DateOnly BirthDate { get; private set; }
    public string PhoneNumber { get; private set; } = string.Empty;
    public string? Address { get; private set; }
    public bool HasDisability { get; private set; }
    public byte? DisabilityRate { get; private set; }
    public int? DisabilityTypeId { get; private set; }
    public int HelpTypeId { get; private set; }
    public int RequestChannelId { get; private set; }
    public string? Description { get; private set; }
    public string? FieldInspectionNote { get; private set; }
    public int StatusId { get; private set; }
    public string CreatedByUserId { get; private set; } = string.Empty;
    public DateTime CreatedAtUtc { get; private set; }
    public string? UpdatedByUserId { get; private set; }
    public DateTime? UpdatedAtUtc { get; private set; }
    public string? SubmittedByUserId { get; private set; }
    public DateTime? SubmittedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public static ApplicationRecord Create(
        int municipalityId,
        string applicationNumber,
        int statusId,
        int helpTypeId,
        int? disabilityTypeId,
        int requestChannelId,
        string actorUserId,
        DateTime nowUtc,
        ApplicationDraftData draft)
    {
        return new ApplicationRecord
        {
            PublicId = Guid.NewGuid(),
            MunicipalityId = municipalityId,
            ApplicationNumber = applicationNumber,
            StatusId = statusId,
            RequestChannelId = requestChannelId,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
            IdentityNumber = draft.IdentityNumber,
            BirthDate = draft.BirthDate,
            PhoneNumber = draft.PhoneNumber,
            HelpTypeId = helpTypeId,
            HasDisability = draft.HasDisability,
            DisabilityTypeId = disabilityTypeId,
            DisabilityRate = draft.DisabilityRate,
            Description = draft.Description,
            ApplicantFirstName = draft.ApplicantFirstName,
            ApplicantLastName = draft.ApplicantLastName,
            Address = draft.Address,
            FieldInspectionNote = draft.FieldInspectionNote,
        };
    }

    public void UpdateDraft(
        ApplicationDraftData draft,
        int helpTypeId,
        int? disabilityTypeId,
        string actorUserId,
        DateTime nowUtc)
    {
        IdentityNumber = draft.IdentityNumber;
        BirthDate = draft.BirthDate;
        PhoneNumber = draft.PhoneNumber;
        HelpTypeId = helpTypeId;
        HasDisability = draft.HasDisability;
        DisabilityTypeId = disabilityTypeId;
        DisabilityRate = draft.DisabilityRate;
        Description = draft.Description;
        ApplicantFirstName = draft.ApplicantFirstName;
        ApplicantLastName = draft.ApplicantLastName;
        Address = draft.Address;
        FieldInspectionNote = draft.FieldInspectionNote;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = nowUtc;
    }

    public void SubmitToBoard(int pendingBoardStatusId, string actorUserId, DateTime nowUtc)
    {
        StatusId = pendingBoardStatusId;
        SubmittedByUserId = actorUserId;
        SubmittedAtUtc = nowUtc;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = nowUtc;
    }

    public void Touch(string actorUserId, DateTime nowUtc)
    {
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = nowUtc;
    }
}

internal sealed class ApplicationFamilyMemberRecord
{
    private ApplicationFamilyMemberRecord()
    {
    }

    public int Id { get; private set; }
    public int MunicipalityId { get; private set; }
    public int ApplicationId { get; private set; }
    public int? SourceFamilyMemberId { get; private set; }
    public string FullName { get; private set; } = string.Empty;
    public short Age { get; private set; }
    public int RelationshipId { get; private set; }
    public string? OtherRelationshipDescription { get; private set; }
    public bool HasDisability { get; private set; }
    public int? DisabilityTypeId { get; private set; }
    public string? DisabilityDescription { get; private set; }
    public int? EmploymentStatusId { get; private set; }
    public int? EducationStatusId { get; private set; }
    public int VitalStatusId { get; private set; }
    public string CreatedByUserId { get; private set; } = string.Empty;
    public DateTime CreatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public static ApplicationFamilyMemberRecord Create(
        int municipalityId,
        int applicationId,
        int relationshipId,
        int? disabilityTypeId,
        int employmentStatusId,
        int educationStatusId,
        int vitalStatusId,
        string actorUserId,
        DateTime nowUtc,
        ApplicationFamilyMemberData member) =>
        new()
        {
            MunicipalityId = municipalityId,
            ApplicationId = applicationId,
            FullName = member.FullName,
            Age = member.Age,
            RelationshipId = relationshipId,
            OtherRelationshipDescription = member.OtherRelationshipDescription,
            HasDisability = member.HasDisability,
            DisabilityTypeId = disabilityTypeId,
            DisabilityDescription = member.DisabilityDescription,
            EmploymentStatusId = employmentStatusId,
            EducationStatusId = educationStatusId,
            VitalStatusId = vitalStatusId,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
        };
}

internal sealed class ApplicationHouseholdAnswerRecord
{
    private ApplicationHouseholdAnswerRecord()
    {
    }

    public int Id { get; private set; }
    public int MunicipalityId { get; private set; }
    public int ApplicationId { get; private set; }
    public int QuestionId { get; private set; }
    public int? OptionId { get; private set; }
    public string? TextAnswer { get; private set; }
    public decimal? NumericAnswer { get; private set; }
    public string CreatedByUserId { get; private set; } = string.Empty;
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime? UpdatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public static ApplicationHouseholdAnswerRecord CreateSingleChoice(
        int municipalityId,
        int applicationId,
        int questionId,
        int optionId,
        string actorUserId,
        DateTime nowUtc) =>
        new()
        {
            MunicipalityId = municipalityId,
            ApplicationId = applicationId,
            QuestionId = questionId,
            OptionId = optionId,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
        };
}

internal sealed class ApplicationPhotoRecord
{
    private ApplicationPhotoRecord()
    {
    }

    public int Id { get; private set; }
    public int MunicipalityId { get; private set; }
    public int ApplicationId { get; private set; }
    public string StorageKey { get; private set; } = string.Empty;
    public string? OriginalFileName { get; private set; }
    public string ContentType { get; private set; } = string.Empty;
    public long Length { get; private set; }
    public byte[] Sha256 { get; private set; } = [];
    public byte Order { get; private set; }
    public string ScanStatusCode { get; private set; } = "BEKLIYOR";
    public bool ExifRemoved { get; private set; }
    public bool IsDeleted { get; private set; }
    public string CreatedByUserId { get; private set; } = string.Empty;
    public DateTime CreatedAtUtc { get; private set; }
    public string? DeletedByUserId { get; private set; }
    public DateTime? DeletedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public static ApplicationPhotoRecord Create(
        int municipalityId,
        int applicationId,
        string actorUserId,
        DateTime nowUtc,
        StoredApplicationPhoto photo) =>
        new()
        {
            MunicipalityId = municipalityId,
            ApplicationId = applicationId,
            StorageKey = photo.StorageKey,
            OriginalFileName = photo.OriginalFileName,
            ContentType = photo.ContentType,
            Length = photo.Length,
            Sha256 = photo.Sha256,
            Order = photo.Order,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
        };
}

internal sealed class ApplicationStatusReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class HelpTypeReference
{
    public int Id { get; init; }
    public int? MunicipalityId { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class DisabilityTypeReference
{
    public int Id { get; init; }
    public int? MunicipalityId { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class RequestChannelReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class RelationshipReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class EmploymentStatusReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class EducationStatusReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class VitalStatusReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class HouseholdQuestionReference
{
    public int Id { get; init; }
    public int? MunicipalityId { get; init; }
    public string Code { get; init; } = string.Empty;
    public string AnswerTypeCode { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class HouseholdQuestionOptionReference
{
    public int Id { get; init; }
    public int QuestionId { get; init; }
    public string Code { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

internal sealed class ApplicationStatusHistoryRecord
{
    private ApplicationStatusHistoryRecord()
    {
    }

    public long Id { get; private set; }
    public int MunicipalityId { get; private set; }
    public int ApplicationId { get; private set; }
    public int? PreviousStatusId { get; private set; }
    public int NewStatusId { get; private set; }
    public string? Description { get; private set; }
    public string CreatedByUserId { get; private set; } = string.Empty;
    public DateTime CreatedAtUtc { get; private set; }

    public static ApplicationStatusHistoryRecord Create(
        int municipalityId,
        int applicationId,
        int? previousStatusId,
        int newStatusId,
        string actorUserId,
        DateTime nowUtc) =>
        new()
        {
            MunicipalityId = municipalityId,
            ApplicationId = applicationId,
            PreviousStatusId = previousStatusId,
            NewStatusId = newStatusId,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
        };
}
