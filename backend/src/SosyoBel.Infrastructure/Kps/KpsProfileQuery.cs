using SosyoBel.Application.Authorization;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// Yetkiyi her sorguda veritabanından kontrol eder. Yetki yoksa KPS istemcisi
/// çağrılmadan işlem sonlandırılır; böylece yalnız arayüz kontrolüne güvenilmez.
/// </summary>
internal sealed class KpsProfileQuery(
    IAccessPermissionChecker permissionChecker,
    IKpsClient kpsClient,
    TimeProvider timeProvider) : IKpsProfileQuery
{
    public async Task<KpsProfileQueryResult> GetProfileAsync(
        KpsProfileActor actor,
        KpsLookupCriteria criteria,
        CancellationToken cancellationToken)
    {
        var errors = Validate(actor, criteria, timeProvider.GetUtcNow());
        if (errors.Count > 0)
        {
            return new KpsProfileQueryResult(
                KpsProfileQueryStatus.InvalidInput,
                Code: "invalid_kps_query",
                Detail: "KPS sorgu bilgileri doğrulanamadı.",
                Errors: errors);
        }

        var hasPermission = await permissionChecker.HasPermissionAsync(
            actor.UserId,
            actor.MunicipalityMembershipId,
            actor.MunicipalityId,
            PermissionCodes.KpsLookup,
            cancellationToken);
        if (!hasPermission)
        {
            return new KpsProfileQueryResult(
                KpsProfileQueryStatus.AccessDenied,
                Code: "kps_permission_required",
                Detail: "KPS sorgulama yetkisi bulunmuyor.");
        }

        try
        {
            // Kurum servisinin eşzamanlı çağrı sınırı bilinmediği için iki okuma
            // bilinçli olarak sıralı yapılır. Canlı ortam bilgisi gelirse ölçülerek değiştirilebilir.
            var identity = await kpsClient.GetIdentityAsync(criteria, cancellationToken);
            var address = await kpsClient.GetAddressAsync(criteria, cancellationToken);

            return new KpsProfileQueryResult(
                KpsProfileQueryStatus.Succeeded,
                new KpsProfile(
                    identity.IdentityNumber,
                    identity.FirstName,
                    identity.LastName,
                    identity.FatherName,
                    identity.MotherName,
                    identity.BirthDate,
                    identity.BirthPlace,
                    identity.Gender,
                    identity.MaritalStatus,
                    identity.Status,
                    address.FullAddress));
        }
        catch (KpsClientException)
        {
            return new KpsProfileQueryResult(
                KpsProfileQueryStatus.UpstreamUnavailable,
                Code: "kps_unavailable",
                Detail: "KPS servisine şu anda ulaşılamıyor.");
        }
        catch (KpsResponseContractException)
        {
            // Başarısız KPS response örnekleri henüz verilmedi. Bilinmeyen cevapları
            // kayıt bulunamadı diye varsaymak yerine güvenli ve genel bir hata döndürürüz.
            return new KpsProfileQueryResult(
                KpsProfileQueryStatus.InvalidUpstreamResponse,
                Code: "kps_invalid_response",
                Detail: "KPS servisinden beklenen biçimde cevap alınamadı.");
        }
    }

    private static Dictionary<string, string[]> Validate(
        KpsProfileActor? actor,
        KpsLookupCriteria? criteria,
        DateTimeOffset now)
    {
        var errors = new Dictionary<string, string[]>();
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId) ||
            actor.MunicipalityMembershipId <= 0 || actor.MunicipalityId <= 0)
        {
            errors["actor"] = ["Doğrulanmış personel kapsamı bulunamadı."];
        }

        if (criteria is null || string.IsNullOrEmpty(criteria.IdentityNumber) ||
            criteria.IdentityNumber.Length != 11 ||
            criteria.IdentityNumber.Any(value => !char.IsAsciiDigit(value)))
        {
            errors["tcKimlikNo"] = ["T.C. kimlik numarası 11 rakam olmalıdır."];
        }

        if (criteria is null || criteria.BirthDate > DateOnly.FromDateTime(now.UtcDateTime))
        {
            errors["dogumTarihi"] = ["Doğum tarihi gelecekte olamaz."];
        }

        return errors;
    }
}
