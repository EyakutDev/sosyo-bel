namespace SosyoBel.Application.Kps;

/// <summary>
/// KPS kimlik ve adres sonuçlarını tek, sınırlı bir profile dönüştüren uygulama sınırıdır.
/// Rol yetkilendirmesi API politikasında, kurum KPS çağrısından önce uygulanır.
/// </summary>
public interface IKpsProfileQuery
{
    Task<KpsProfileQueryResult> GetProfileAsync(
        KpsProfileActor actor,
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken);
}

/// <summary>
/// Kullanıcı kimliği istekten alınmaz; doğrulanmış JWT'nin sub claim'inden gelir.
/// </summary>
public sealed record KpsProfileActor(string UserId);
