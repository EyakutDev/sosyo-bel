namespace SosyoBel.Application.Kps;

/// <summary>
/// KPS kimlik cevabından uygulamanın gerçekten kullandığı alanları taşır.
/// Ham servis cevabı katmanlar arasında dolaştırılmaz.
/// </summary>
public sealed record KpsIdentityInformation(
    string IdentityNumber,
    string FirstName,
    string LastName,
    string? FatherName,
    string? MotherName,
    DateOnly BirthDate,
    string? BirthPlace,
    string? Gender,
    string? MaritalStatus,
    string? Status);

/// <summary>
/// Adres cevabındaki ayrıntılı bina verileri yerine başvuru ekranının ihtiyaç
/// duyduğu yerleşim yeri açık adresini taşır.
/// </summary>
public sealed record KpsAddressInformation(
    string IdentityNumber,
    string FullAddress,
    long? AddressNumber = null,
    int? ProvinceCode = null,
    int? DistrictCode = null,
    int? NeighborhoodCode = null,
    int? StreetCode = null,
    string? Neighborhood = null,
    string? Street = null,
    string? ExteriorDoorNumber = null,
    string? InteriorDoorNumber = null);

/// <summary>
/// Kimlik ve adres sorgularından başvuru formuna aktarılabilecek tek profili temsil eder.
/// KPS'nin ham cevabı veya uygulamanın kullanmadığı ayrıntılar dışarı açılmaz.
/// </summary>
public sealed record KpsProfile(
    string IdentityNumber,
    string FirstName,
    string LastName,
    string? FatherName,
    string? MotherName,
    DateOnly BirthDate,
    string? BirthPlace,
    string? Gender,
    string? MaritalStatus,
    string? Status,
    string FullAddress,
    long? AddressNumber = null,
    int? ProvinceCode = null,
    int? DistrictCode = null,
    int? NeighborhoodCode = null,
    int? StreetCode = null,
    string? Neighborhood = null,
    string? Street = null,
    string? ExteriorDoorNumber = null,
    string? InteriorDoorNumber = null);

public enum KpsProfileQueryStatus
{
    Succeeded,
    InvalidInput,
    InvalidIdentityNumber,
    BirthDateMismatch,
    AddressOutsideServiceArea,
    UpstreamInvalidRequest,
    UpstreamUnavailable,
    InvalidUpstreamResponse,
}

public sealed record KpsProfileQueryResult(
    KpsProfileQueryStatus Status,
    KpsProfile? Value = null,
    string? Code = null,
    string? Detail = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);
