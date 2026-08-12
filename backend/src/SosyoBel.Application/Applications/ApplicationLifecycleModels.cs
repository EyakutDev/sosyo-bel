namespace SosyoBel.Application.Applications;

public enum ApplicationLifecycleStatus
{
    Succeeded,
    InvalidInput,
    NotFound,
    Conflict,
    IdempotencyConflict,
}

/// <summary>
/// Belediye ve kullanıcı bilgileri istek gövdesinden değil, doğrulanmış JWT
/// claim'lerinden üretilir. Böylece personel başka belediye adına kayıt açamaz.
/// </summary>
public sealed record ApplicationActorContext(
    string ActorUserId,
    int MunicipalityId,
    long MunicipalityMembershipId);

/// <summary>
/// Başvurunun kişi ve talep adımında toplanan çekirdek verisidir. Yardım ve engel
/// türleri değişebilen etiketlerle değil, referans API'sinin döndüreceği kodlarla taşınır.
/// </summary>
public sealed record ApplicationDraftData(
    string IdentityNumber,
    DateOnly BirthDate,
    string PhoneNumber,
    string HelpTypeCode,
    bool HasDisability,
    string? DisabilityTypeCode,
    byte? DisabilityRate,
    string? Description,
    string? ApplicantFirstName,
    string? ApplicantLastName,
    string? Address,
    string? FieldInspectionNote);

public sealed record CreateApplicationDraftCommand(
    ApplicationActorContext Actor,
    string IdempotencyKey,
    ApplicationDraftData Draft);

public sealed record UpdateApplicationDraftCommand(
    ApplicationActorContext Actor,
    Guid ApplicationPublicId,
    string ExpectedRowVersion,
    ApplicationDraftData Draft);

/// <summary>
/// Personelin elle girdiği aile üyesinin başvuru anındaki değişmez kopyasıdır.
/// Etiketler yerine belediye referans tablolarındaki kodlar taşınır.
/// </summary>
public sealed record ApplicationFamilyMemberData(
    string FullName,
    short Age,
    string RelationshipCode,
    string? OtherRelationshipDescription,
    bool HasDisability,
    string? DisabilityTypeCode,
    string? DisabilityDescription,
    string EmploymentStatusCode,
    string EducationStatusCode,
    string VitalStatusCode);

/// <summary>
/// Yönetilebilir hane sorusunun tek seçim cevabıdır.
/// </summary>
public sealed record ApplicationHouseholdAnswerData(
    string QuestionCode,
    string OptionCode);

public sealed record SaveApplicationFieldDataCommand(
    ApplicationActorContext Actor,
    Guid ApplicationPublicId,
    string ExpectedRowVersion,
    IReadOnlyCollection<ApplicationFamilyMemberData> FamilyMembers,
    IReadOnlyCollection<ApplicationHouseholdAnswerData> HouseholdAnswers,
    bool SaveToBeneficiaryDirectory);

public sealed record SubmitApplicationToBoardCommand(
    ApplicationActorContext Actor,
    Guid ApplicationPublicId,
    string ExpectedRowVersion,
    string IdempotencyKey);

public sealed record ApplicationDetails(
    Guid ApplicationPublicId,
    string ApplicationNumber,
    string StatusCode,
    bool IsEditable,
    string IdentityNumber,
    DateOnly BirthDate,
    string PhoneNumber,
    string HelpTypeCode,
    bool HasDisability,
    string? DisabilityTypeCode,
    byte? DisabilityRate,
    string? Description,
    string? ApplicantFirstName,
    string? ApplicantLastName,
    string? Address,
    string? FieldInspectionNote,
    DateTime CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    DateTime? SubmittedToBoardAtUtc,
    string RowVersion);

/// <summary>
/// Kaydedilmiş aile üyesinin ekranı yeniden kurmak için gereken kod tabanlı görünümüdür.
/// Nullable alanlar, şirketin eski kayıtlarında eksik bırakılmış değerlerin okunmasını engellemez.
/// </summary>
public sealed record ApplicationFamilyMemberSnapshot(
    string FullName,
    int Age,
    string? RelationshipCode,
    string? OtherRelationshipDescription,
    bool HasDisability,
    string? DisabilityTypeCode,
    string? DisabilityDescription,
    string? EmploymentStatusCode,
    string? EducationStatusCode,
    string? VitalStatusCode);

public sealed record ApplicationPhotoSnapshot(
    int PhotoId,
    string? OriginalFileName,
    string ContentType,
    long Length,
    byte Order);

/// <summary>
/// Mobil uygulamanın bekleyen bir taslağı ağ kaybı veya uygulama kapanması sonrasında
/// eksiksiz yeniden açabilmesi için gereken tek, tutarlı okuma sözleşmesidir.
/// </summary>
public sealed record ApplicationDraftSnapshot(
    ApplicationDetails Application,
    IReadOnlyCollection<ApplicationFamilyMemberSnapshot> FamilyMembers,
    IReadOnlyCollection<ApplicationHouseholdAnswerData> HouseholdAnswers,
    bool SaveToBeneficiaryDirectory,
    IReadOnlyCollection<ApplicationPhotoSnapshot> Photos);

public sealed record ApplicationLifecycleResult<T>(
    ApplicationLifecycleStatus Status,
    T? Value = default,
    string? Code = null,
    string? Detail = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);
