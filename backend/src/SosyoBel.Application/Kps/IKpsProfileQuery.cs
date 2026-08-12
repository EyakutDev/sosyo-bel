namespace SosyoBel.Application.Kps;

/// <summary>
/// KPS erişim yetkisini güncel veritabanı kaydından doğrulayıp kimlik ve adres
/// sonuçlarını tek, sınırlı bir profile dönüştüren uygulama sınırıdır.
/// </summary>
public interface IKpsProfileQuery
{
    Task<KpsProfileQueryResult> GetProfileAsync(
        KpsProfileActor actor,
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken);
}

/// <summary>
/// Bu değerler istek gövdesinden değil, doğrulanmış personel JWT claim'lerinden gelir.
/// </summary>
public sealed record KpsProfileActor(
    string UserId,
    long MunicipalityMembershipId,
    int MunicipalityId);
