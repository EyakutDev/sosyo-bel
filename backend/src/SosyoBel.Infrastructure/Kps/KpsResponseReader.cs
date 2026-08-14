using System.Globalization;
using System.Text.Json;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// Kurum KPS servisinin başarılı kimlik ve adres JSON cevaplarını, uygulamanın
/// ihtiyaç duyduğu sınırlı modellere dönüştürür.
/// </summary>
internal static class KpsResponseReader
{
    private const string InvalidIdentityResponseCode = "KPS_KIMLIK_CEVABI_GECERSIZ";
    private const string InvalidAddressResponseCode = "KPS_ADRES_CEVABI_GECERSIZ";
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public static KpsIdentityInformation ReadIdentity(
        string json,
        string expectedIdentityNumber)
    {
        ValidateExpectedIdentityNumber(expectedIdentityNumber);
        var response = Deserialize<IdentityResponse>(
            json,
            InvalidIdentityResponseCode,
            "KPS kimlik cevabı okunamadı.");

        ThrowIfKnownRejection(json, response.Success, InvalidIdentityResponseCode);
        if (!MatchesIdentityNumber(response.TcKimlikNo, expectedIdentityNumber) ||
            string.IsNullOrWhiteSpace(response.Ad) ||
            string.IsNullOrWhiteSpace(response.Soyad) ||
            response.DogumGunu is null ||
            response.DogumAy is null ||
            response.DogumYili is null)
        {
            throw InvalidContract(
                InvalidIdentityResponseCode,
                "KPS kimlik cevabı gerekli başarılı alanları içermiyor.");
        }

        DateOnly birthDate;
        try
        {
            birthDate = new DateOnly(
                response.DogumYili.Value,
                response.DogumAy.Value,
                response.DogumGunu.Value);
        }
        catch (ArgumentOutOfRangeException)
        {
            throw InvalidContract(
                InvalidIdentityResponseCode,
                "KPS kimlik cevabındaki doğum tarihi geçersiz.");
        }

        return new KpsIdentityInformation(
            expectedIdentityNumber,
            response.Ad.Trim(),
            response.Soyad.Trim(),
            NormalizeOptional(response.BabaAd),
            NormalizeOptional(response.AnneAd),
            birthDate,
            NormalizeOptional(response.DogumYeri),
            NormalizeOptional(response.Cinsiyet),
            NormalizeOptional(response.MedeniHal),
            NormalizeOptional(response.Durum));
    }

    public static KpsAddressInformation ReadAddress(
        string json,
        string expectedIdentityNumber)
    {
        ValidateExpectedIdentityNumber(expectedIdentityNumber);
        var response = Deserialize<AddressResponse>(
            json,
            InvalidAddressResponseCode,
            "KPS adres cevabı okunamadı.");

        ThrowIfKnownRejection(json, response.Success, InvalidAddressResponseCode);
        if (response.RawData?.SorguSonucu is null)
        {
            throw InvalidContract(
                InvalidAddressResponseCode,
                "KPS adres cevabı gerekli başarılı alanları içermiyor.");
        }

        // Birden fazla sonuç gelirse ilk satırı varsaymak yerine istenen kimlik
        // numarasıyla eşleşen yerleşim yeri kaydı seçilir.
        var address = response.RawData.SorguSonucu
            .FirstOrDefault(value =>
                MatchesIdentityNumber(value.KimlikNo, expectedIdentityNumber))
            ?.YerlesimYeriAdresi
            ?.AcikAdres;
        if (string.IsNullOrWhiteSpace(address))
        {
            throw InvalidContract(
                InvalidAddressResponseCode,
                "KPS adres cevabında yerleşim yeri açık adresi bulunamadı.");
        }

        return new KpsAddressInformation(expectedIdentityNumber, address.Trim());
    }

    private static void ThrowIfKnownRejection(
        string json,
        bool success,
        string invalidResponseCode)
    {
        if (success) return;

        // Kurum KPS servisi iş kuralı hatalarını HTTP 200 ve Success:false ile
        // bildiriyor. Yalnızca doğrulanmış hata kodlarını uygulama sonucuna çeviririz.
        var failure = Deserialize<FailureResponse>(
            json,
            invalidResponseCode,
            "KPS başarısız cevap bilgisi okunamadı.");
        var knownReason = ReadKnownRejectionReason(failure);
        if (knownReason is not null)
        {
            throw new KpsQueryRejectedException(knownReason.Value);
        }

        throw InvalidContract(
            invalidResponseCode,
            "KPS cevabı bilinmeyen bir başarısızlık durumu içeriyor.");
    }

    private static KpsQueryRejectionReason? ReadKnownRejectionReason(
        FailureResponse failure)
    {
        var codes = new List<int?>
        {
            failure.HataBilgisi?.Kod,
            failure.RawData?.HataBilgisi?.Kod,
        };

        if (failure.RawData?.SorguSonucu is not null)
        {
            foreach (var result in failure.RawData.SorguSonucu)
            {
                codes.Add(result.HataBilgisi?.Kod);
                codes.Add(result.YerlesimYeriAdresi?.HataBilgisi?.Kod);
            }
        }

        // DigerAdresBilgileri içindeki Kod=2, paylaşılan başarılı ve başarısız
        // örneklerde de bulunuyor. Asıl sorgu sonucunu ezmemesi için kasıtlı okunmaz.
        foreach (var code in codes)
        {
            var reason = code switch
            {
                5 => KpsQueryRejectionReason.InvalidIdentityNumber,
                16 => KpsQueryRejectionReason.AddressOutsideServiceArea,
                31 => KpsQueryRejectionReason.BirthDateMismatch,
                _ => (KpsQueryRejectionReason?)null,
            };
            if (reason is not null) return reason;
        }

        return null;
    }

    private static T Deserialize<T>(string json, string code, string message)
    {
        if (string.IsNullOrWhiteSpace(json)) throw InvalidContract(code, message);

        try
        {
            return JsonSerializer.Deserialize<T>(json, JsonOptions)
                ?? throw InvalidContract(code, message);
        }
        catch (JsonException)
        {
            // Ayrıştırıcı hatasında hassas ham cevap üst katmana taşınmaz.
            throw InvalidContract(code, message);
        }
    }

    private static void ValidateExpectedIdentityNumber(string identityNumber)
    {
        if (identityNumber.Length != 11 || identityNumber.Any(value => !char.IsDigit(value)))
        {
            throw new ArgumentException(
                "T.C. kimlik numarası 11 rakam olmalıdır.",
                nameof(identityNumber));
        }
    }

    private static bool MatchesIdentityNumber(long? actual, string expected) =>
        actual?.ToString(CultureInfo.InvariantCulture) == expected;

    private static string? NormalizeOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static KpsResponseContractException InvalidContract(
        string code,
        string message) => new(code, message);

    private sealed record IdentityResponse
    {
        public bool Success { get; init; }
        public long? TcKimlikNo { get; init; }
        public string? Ad { get; init; }
        public string? Soyad { get; init; }
        public string? BabaAd { get; init; }
        public string? AnneAd { get; init; }
        public int? DogumGunu { get; init; }
        public int? DogumAy { get; init; }
        public int? DogumYili { get; init; }
        public string? DogumYeri { get; init; }
        public string? Cinsiyet { get; init; }
        public string? MedeniHal { get; init; }
        public string? Durum { get; init; }
    }

    private sealed record AddressResponse
    {
        public bool Success { get; init; }
        public AddressRawData? RawData { get; init; }
    }

    private sealed record AddressRawData
    {
        public IReadOnlyCollection<AddressResult>? SorguSonucu { get; init; }
    }

    private sealed record AddressResult
    {
        public long? KimlikNo { get; init; }
        public ResidenceAddress? YerlesimYeriAdresi { get; init; }
    }

    private sealed record ResidenceAddress
    {
        public string? AcikAdres { get; init; }
    }

    private sealed record FailureResponse
    {
        public FailureInformation? HataBilgisi { get; init; }
        public FailureRawData? RawData { get; init; }
    }

    private sealed record FailureRawData
    {
        public FailureInformation? HataBilgisi { get; init; }
        public IReadOnlyCollection<FailureResult>? SorguSonucu { get; init; }
    }

    private sealed record FailureResult
    {
        public FailureInformation? HataBilgisi { get; init; }
        public FailureResidenceAddress? YerlesimYeriAdresi { get; init; }
    }

    private sealed record FailureResidenceAddress
    {
        public FailureInformation? HataBilgisi { get; init; }
    }

    private sealed record FailureInformation
    {
        public int? Kod { get; init; }
    }
}
