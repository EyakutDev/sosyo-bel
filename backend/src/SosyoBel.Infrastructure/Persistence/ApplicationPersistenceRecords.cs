using System.Globalization;
using SosyoBel.Application.Applications;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class ApplicationRecord
{
    private ApplicationRecord()
    {
    }

    public int Id { get; private set; }
    public Guid PublicId { get; private set; }
    public string? ApplicationNumber { get; private set; }
    public string IdentityNumber { get; private set; } = string.Empty;
    public string ApplicantFirstName { get; private set; } = string.Empty;
    public string ApplicantLastName { get; private set; } = string.Empty;
    public string BirthDateStorage { get; private set; } = string.Empty;
    public DateOnly BirthDate => DateOnly.ParseExact(
        BirthDateStorage,
        "yyyy-MM-dd",
        CultureInfo.InvariantCulture);
    public string PhoneNumber { get; private set; } = string.Empty;
    public string? Address { get; private set; }
    public bool HasDisability { get; private set; }
    public int? DisabilityRate { get; private set; }
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
            StatusId = statusId,
            RequestChannelId = requestChannelId,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
            IdentityNumber = draft.IdentityNumber,
            // Şirket tablosu doğum tarihini metin olarak tutuyor. Yeni mobil
            // kayıtlar kültürden bağımsız ve geri okunabilir ISO biçiminde yazılır.
            BirthDateStorage = draft.BirthDate.ToString(
                "yyyy-MM-dd",
                CultureInfo.InvariantCulture),
            PhoneNumber = draft.PhoneNumber,
            HelpTypeId = helpTypeId,
            HasDisability = draft.HasDisability,
            DisabilityTypeId = disabilityTypeId,
            DisabilityRate = draft.DisabilityRate,
            Description = draft.Description,
            ApplicantFirstName = draft.ApplicantFirstName ?? string.Empty,
            ApplicantLastName = draft.ApplicantLastName ?? string.Empty,
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
        BirthDateStorage = draft.BirthDate.ToString(
            "yyyy-MM-dd",
            CultureInfo.InvariantCulture);
        PhoneNumber = draft.PhoneNumber;
        HelpTypeId = helpTypeId;
        HasDisability = draft.HasDisability;
        DisabilityTypeId = disabilityTypeId;
        DisabilityRate = draft.DisabilityRate;
        Description = draft.Description;
        ApplicantFirstName = draft.ApplicantFirstName ?? string.Empty;
        ApplicantLastName = draft.ApplicantLastName ?? string.Empty;
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
    public int ApplicationId { get; private set; }
    public string FullName { get; private set; } = string.Empty;
    public int Age { get; private set; }
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
        int applicationId,
        int questionId,
        int optionId,
        string actorUserId,
        DateTime nowUtc) =>
        new()
        {
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
        int applicationId,
        string actorUserId,
        DateTime nowUtc,
        StoredApplicationPhoto photo) =>
        new()
        {
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

    public void MarkDeleted(string actorUserId, DateTime nowUtc)
    {
        if (IsDeleted) return;
        IsDeleted = true;
        DeletedByUserId = actorUserId;
        DeletedAtUtc = nowUtc;
    }
}

internal interface ICompanyReferenceSource
{
    int Id { get; }
    string Name { get; }
    bool IsDeleted { get; }
}

internal sealed class ApplicationStatusReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class HelpTypeReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class DisabilityTypeReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class RequestChannelReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class RelationshipReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class EmploymentStatusReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class EducationStatusReference : ICompanyReferenceSource
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

internal sealed class VitalStatusReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public short Order { get; init; }
    public bool IsActive { get; init; }
}

internal sealed class HouseholdQuestionReference
{
    public int Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public string Label { get; init; } = string.Empty;
    public string AnswerTypeCode { get; init; } = string.Empty;
    public bool IsRequired { get; init; }
    public short Order { get; init; }
    public bool IsActive { get; init; }
}

internal sealed class HouseholdQuestionOptionReference
{
    public int Id { get; init; }
    public int QuestionId { get; init; }
    public string Code { get; init; } = string.Empty;
    public string Label { get; init; } = string.Empty;
    public short Order { get; init; }
    public bool IsActive { get; init; }
}

internal sealed class ApplicationStatusHistoryRecord
{
    private ApplicationStatusHistoryRecord()
    {
    }

    public long Id { get; private set; }
    public int ApplicationId { get; private set; }
    public int? PreviousStatusId { get; private set; }
    public int NewStatusId { get; private set; }
    public string? Description { get; private set; }
    public string CreatedByUserId { get; private set; } = string.Empty;
    public DateTime CreatedAtUtc { get; private set; }

    public static ApplicationStatusHistoryRecord Create(
        int applicationId,
        int? previousStatusId,
        int newStatusId,
        string actorUserId,
        DateTime nowUtc) =>
        new()
        {
            ApplicationId = applicationId,
            PreviousStatusId = previousStatusId,
            NewStatusId = newStatusId,
            CreatedByUserId = actorUserId,
            CreatedAtUtc = nowUtc,
        };
}
