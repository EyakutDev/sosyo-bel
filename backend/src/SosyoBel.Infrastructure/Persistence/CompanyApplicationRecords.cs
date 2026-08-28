using System.Globalization;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirketin mevcut dbo.Vatandaslar satırının birebir persistence modelidir.
/// Mobil uygulamaya özgü alan içermez ve şirket şemasında kolon oluşturmaz.
/// </summary>
internal sealed class CompanyCitizenRecord
{
    public int Id { get; private set; }
    public string IdentityNumber { get; private set; } = string.Empty;
    public string FirstName { get; private set; } = string.Empty;
    public string LastName { get; private set; } = string.Empty;
    public DateTime BirthDate { get; private set; }
    public string Address { get; private set; } = string.Empty;
    public string PrimaryPhone { get; private set; } = string.Empty;
    public string? SecondaryPhone { get; private set; }
    public string? Email { get; private set; }
    public bool HasDisability { get; private set; }
    public int? DisabilityRate { get; private set; }
    public int? ChildCount { get; private set; }
    public DateTime RegisteredAt { get; private set; }
    public int NeighborhoodId { get; private set; }
    public int? StreetId { get; private set; }
    public string? CreatedByUserId { get; private set; }
    public bool IsDeleted { get; private set; }
    public int? EmploymentStatusId { get; private set; }
    public int? EducationStatusId { get; private set; }
    public int? DisabilityTypeId { get; private set; }
    public int? MaritalStatusId { get; private set; }
    public string? Gender { get; private set; }
    public string? BirthPlace { get; private set; }
    public int? ProvinceCode { get; private set; }
    public int? DistrictCode { get; private set; }
    public string? KpsNeighborhood { get; private set; }
    public string? KpsStreet { get; private set; }
    public int? NeighborhoodCode { get; private set; }
    public int? StreetCode { get; private set; }
    public long? AddressNumber { get; private set; }
}

/// <summary>
/// Şirketin mevcut dbo.Basvurular satırının birebir persistence modelidir.
/// PublicToken mobil isteğin tekrarında aynı başvuruyu bulmak için kullanılacaktır.
/// </summary>
internal sealed class CompanyApplicationRecord
{
    private CompanyApplicationRecord()
    {
    }

    public int Id { get; private set; }
    public int? CitizenId { get; private set; }
    public DateTime ApplicationDate { get; private set; }
    public string? Description { get; private set; }
    public string ApplicantFirstName { get; private set; } = string.Empty;
    public string? ApplicationAddress { get; private set; }
    public string? ApplicantBirthDate { get; private set; }
    public string ApplicantLastName { get; private set; } = string.Empty;
    public string ApplicantIdentityNumber { get; private set; } = string.Empty;
    public string ApplicantPhone { get; private set; } = string.Empty;
    public string? HouseholdPhotoPath { get; private set; }
    public string? CancellationDescription { get; private set; }
    public DateTime? CancellationDate { get; private set; }
    public int StatusId { get; private set; }
    public int? NeighborhoodId { get; private set; }
    public int? StreetId { get; private set; }
    public int HelpTypeId { get; private set; }
    public int RequestChannelId { get; private set; }
    public string? CreatedByUserId { get; private set; }
    public bool HasDisability { get; private set; }
    public int? DisabilityRate { get; private set; }
    public int? DisabilityTypeId { get; private set; }
    public string PublicToken { get; private set; } = string.Empty;
    public string? ApplicantGender { get; private set; }
    public string? ApplicantBirthPlace { get; private set; }
    public string? ApplicantMaritalStatus { get; private set; }
    public string? ApplicationNeighborhood { get; private set; }
    public string? ApplicationStreet { get; private set; }
    public int? ProvinceCode { get; private set; }
    public int? DistrictCode { get; private set; }
    public int? NeighborhoodCode { get; private set; }
    public int? StreetCode { get; private set; }
    public long? AddressNumber { get; private set; }

    /// <summary>
    /// Şirket web uygulamasının personel başvurusu oluştururken doldurduğu çekirdek
    /// dbo.Basvurular alanlarını aynı biçimde hazırlar. Aile, hane ve fotoğraf
    /// verileri bu satıra zorla sığdırılmaz.
    /// </summary>
    public static CompanyApplicationRecord CreatePending(
        int statusId,
        int helpTypeId,
        int? disabilityTypeId,
        int requestChannelId,
        int neighborhoodId,
        int? streetId,
        string actorUserId,
        DateTime applicationDate,
        string publicToken,
        ApplicationDraftData draft,
        KpsProfile profile,
        int citizenId)
    {
        ArgumentNullException.ThrowIfNull(draft);
        ArgumentNullException.ThrowIfNull(profile);
        ArgumentException.ThrowIfNullOrWhiteSpace(actorUserId);
        if (statusId <= 0) throw new ArgumentOutOfRangeException(nameof(statusId));
        if (helpTypeId <= 0) throw new ArgumentOutOfRangeException(nameof(helpTypeId));
        if (requestChannelId <= 0)
            throw new ArgumentOutOfRangeException(nameof(requestChannelId));
        if (neighborhoodId <= 0)
            throw new ArgumentOutOfRangeException(nameof(neighborhoodId));
        if (citizenId <= 0)
            throw new ArgumentOutOfRangeException(nameof(citizenId));
        if (publicToken.Length != 32 || publicToken.Any(value => !Uri.IsHexDigit(value)))
            throw new ArgumentException("PublicToken 32 hexadecimal karakter olmalıdır.", nameof(publicToken));

        return new CompanyApplicationRecord
        {
            CitizenId = citizenId,
            ApplicationDate = applicationDate,
            Description = draft.Description,
            ApplicantFirstName = profile.FirstName.Trim(),
            ApplicantLastName = profile.LastName.Trim(),
            ApplicantIdentityNumber = profile.IdentityNumber,
            ApplicantPhone = draft.PhoneNumber,
            // Şirket web uygulaması bu kolonu dd.MM.yyyy biçiminde okuyup yazıyor.
            ApplicantBirthDate = profile.BirthDate.ToString(
                "dd.MM.yyyy",
                CultureInfo.InvariantCulture),
            ApplicationAddress = profile.FullAddress.Trim(),
            StatusId = statusId,
            NeighborhoodId = neighborhoodId,
            StreetId = streetId,
            HelpTypeId = helpTypeId,
            RequestChannelId = requestChannelId,
            CreatedByUserId = actorUserId,
            HasDisability = draft.HasDisability,
            DisabilityRate = draft.HasDisability ? draft.DisabilityRate : null,
            DisabilityTypeId = draft.HasDisability ? disabilityTypeId : null,
            PublicToken = publicToken,
            ApplicantGender = profile.Gender,
            ApplicantBirthPlace = profile.BirthPlace,
            ApplicantMaritalStatus = profile.MaritalStatus,
            ApplicationNeighborhood = profile.Neighborhood,
            ApplicationStreet = profile.Street,
            ProvinceCode = profile.ProvinceCode,
            DistrictCode = profile.DistrictCode,
            NeighborhoodCode = profile.NeighborhoodCode,
            StreetCode = profile.StreetCode,
            AddressNumber = profile.AddressNumber,
            HouseholdPhotoPath = null,
            CancellationDescription = null,
            CancellationDate = null,
        };
    }
}

/// <summary>
/// Başvuru anındaki aile fotoğrafını tutan mevcut dbo.BasvuruAileFertleri
/// satırıdır. Ölü/Sağ ve diğer yakınlık metni bu tabloya eklenmez.
/// </summary>
internal sealed class CompanyApplicationFamilyMemberRecord
{
    private CompanyApplicationFamilyMemberRecord()
    {
    }

    public int Id { get; private set; }
    public int ApplicationId { get; private set; }
    public string FullName { get; private set; } = string.Empty;
    public int Age { get; private set; }
    public bool HasDisability { get; private set; }
    public int? DisabilityTypeId { get; private set; }
    public int? EmploymentStatusId { get; private set; }
    public int? EducationStatusId { get; private set; }
    public int RelationshipId { get; private set; }

    public static CompanyApplicationFamilyMemberRecord Create(
        int applicationId,
        int relationshipId,
        int? disabilityTypeId,
        int employmentStatusId,
        int educationStatusId,
        ApplicationFamilyMemberData member)
    {
        ArgumentNullException.ThrowIfNull(member);
        if (applicationId <= 0)
            throw new ArgumentOutOfRangeException(nameof(applicationId));
        if (relationshipId <= 0)
            throw new ArgumentOutOfRangeException(nameof(relationshipId));
        if (employmentStatusId <= 0)
            throw new ArgumentOutOfRangeException(nameof(employmentStatusId));
        if (educationStatusId <= 0)
            throw new ArgumentOutOfRangeException(nameof(educationStatusId));

        return new CompanyApplicationFamilyMemberRecord
        {
            ApplicationId = applicationId,
            FullName = member.FullName,
            Age = member.Age,
            HasDisability = member.HasDisability,
            DisabilityTypeId = member.HasDisability ? disabilityTypeId : null,
            EmploymentStatusId = employmentStatusId,
            EducationStatusId = educationStatusId,
            RelationshipId = relationshipId,
        };
    }
}

/// <summary>
/// Şirketin mevcut dbo.HaneFotograflari satırıdır. Tablo başvuru kimliği
/// içermediği için fotoğraf yalnız mevcut vatandaş kaydına bağlanır.
/// </summary>
internal sealed class CompanyHouseholdPhotoRecord
{
    private CompanyHouseholdPhotoRecord()
    {
    }

    public int Id { get; private set; }
    public int CitizenId { get; private set; }
    public string PhotoPath { get; private set; } = string.Empty;
    public string? Description { get; private set; }
    public DateTime UploadedAt { get; private set; }

    public static CompanyHouseholdPhotoRecord Create(
        int citizenId,
        string photoPath,
        string? description,
        DateTime uploadedAt)
    {
        if (citizenId <= 0)
            throw new ArgumentOutOfRangeException(nameof(citizenId));
        ArgumentException.ThrowIfNullOrWhiteSpace(photoPath);

        return new CompanyHouseholdPhotoRecord
        {
            CitizenId = citizenId,
            PhotoPath = photoPath.Trim(),
            Description = string.IsNullOrWhiteSpace(description)
                ? null
                : description.Trim(),
            UploadedAt = uploadedAt,
        };
    }
}

/// <summary>
/// Şirketin mevcut dbo.Mahalleler tablosundaki etkin mahalle kaydıdır.
/// </summary>
internal sealed class CompanyNeighborhoodReference
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public bool IsDeleted { get; init; }
}

/// <summary>
/// Şirketin mevcut dbo.Sokaklar tablosundaki etkin sokak kaydıdır.
/// </summary>
internal sealed class CompanyStreetReference
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public int NeighborhoodId { get; init; }
    public bool IsDeleted { get; init; }
}
