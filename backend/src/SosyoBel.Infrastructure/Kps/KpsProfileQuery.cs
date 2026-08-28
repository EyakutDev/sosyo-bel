using System.Net;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// Doğrulanmış kullanıcı ve sorgu girdilerini kontrol edip iki kurum cevabını
/// mobil uygulamanın kullandığı tek bir profile dönüştürür.
/// </summary>
internal sealed class KpsProfileQuery(
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
                    address.FullAddress,
                    address.AddressNumber,
                    address.ProvinceCode,
                    address.DistrictCode,
                    address.NeighborhoodCode,
                    address.StreetCode,
                    address.Neighborhood,
                    address.Street,
                    address.ExteriorDoorNumber,
                    address.InteriorDoorNumber));
        }
        catch (KpsQueryRejectedException error)
        {
            // KPS'nin ham hata metni kullanıcıya taşınmaz. Kurumun doğruladığı
            // sayısal kodlar sabit, uygulamaya ait mesajlara burada dönüştürülür.
            return error.Reason switch
            {
                KpsQueryRejectionReason.InvalidIdentityNumber =>
                    new KpsProfileQueryResult(
                        KpsProfileQueryStatus.InvalidIdentityNumber,
                        Code: "kps_invalid_identity_number",
                        Detail: "Geçerli bir T.C. kimlik numarası giriniz."),
                KpsQueryRejectionReason.BirthDateMismatch =>
                    new KpsProfileQueryResult(
                        KpsProfileQueryStatus.BirthDateMismatch,
                        Code: "kps_identity_birth_date_mismatch",
                        Detail: "T.C. kimlik numarası ile doğum tarihi eşleşmiyor."),
                KpsQueryRejectionReason.AddressOutsideServiceArea =>
                    new KpsProfileQueryResult(
                        KpsProfileQueryStatus.AddressOutsideServiceArea,
                        Code: "kps_address_outside_service_area",
                        Detail: "Adres kurumun hizmet alanı dışında."),
                _ => new KpsProfileQueryResult(
                    KpsProfileQueryStatus.InvalidUpstreamResponse,
                    Code: "kps_invalid_response",
                    Detail: "KPS servisinden beklenen biçimde cevap alınamadı."),
            };
        }
        catch (KpsClientException error)
            when (error.StatusCode == HttpStatusCode.BadRequest)
        {
            // Paylaşılan sözleşmede upstream 400 yalnızca dört zorunlu sorgu
            // alanından biri eksik olduğunda dönüyor.
            return new KpsProfileQueryResult(
                KpsProfileQueryStatus.UpstreamInvalidRequest,
                Code: "kps_invalid_request",
                Detail: "KPS sorgu bilgileri eksik veya geçersiz.");
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
            // Sözleşmede tanımlanmayan cevapları bilinen bir iş hatası gibi
            // göstermeyiz; güvenli ve genel bir entegrasyon hatası döndürürüz.
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
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
        {
            errors["actor"] = ["Doğrulanmış kullanıcı kimliği bulunamadı."];
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
