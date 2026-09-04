namespace SosyoBel.Application.Kps;

/// <summary>
/// Kurum KPS servisinde kimlik ve adres verisini yalnız okuyan adapter sınırıdır.
/// HTTP ayrıntıları uygulama ve API katmanlarına taşınmaz.
/// </summary>
public interface IKpsClient
{
    Task<KpsIdentityInformation> GetIdentityAsync(
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken);

    Task<KpsAddressInformation> GetAddressAsync(
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken);
}

/// <summary>
/// İki KPS POST çağrısında JSON gövdesine yazılan ortak sorgu kriteridir.
/// </summary>
public sealed record KpsLookupCriteria(
    string IdentityNumber,
    DateOnly BirthDate);
