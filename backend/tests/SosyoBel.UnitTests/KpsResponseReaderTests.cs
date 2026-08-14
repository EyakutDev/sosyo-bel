using SosyoBel.Infrastructure.Kps;

namespace SosyoBel.UnitTests;

public sealed class KpsResponseReaderTests
{
    private const string SyntheticIdentityNumber = "12345678901";

    [Fact]
    public void IdentityResponseMapsOnlyRequiredApplicationFields()
    {
        const string json = """
        {
          "Success": true,
          "Message": "Sorgulama başarılı.",
          "TcKimlikNo": 12345678901,
          "Ad": " ÖRNEK ",
          "Soyad": " KİŞİ ",
          "BabaAd": "BABA",
          "AnneAd": "ANNE",
          "DogumGunu": 14,
          "DogumAy": 9,
          "DogumYili": 1986,
          "DogumYeri": "ÖRNEK İL",
          "Cinsiyet": "Erkek",
          "MedeniHal": "Evli",
          "Durum": "Açık"
        }
        """;

        var result = KpsResponseReader.ReadIdentity(json, SyntheticIdentityNumber);

        Assert.Equal(SyntheticIdentityNumber, result.IdentityNumber);
        Assert.Equal("ÖRNEK", result.FirstName);
        Assert.Equal("KİŞİ", result.LastName);
        Assert.Equal(new DateOnly(1986, 9, 14), result.BirthDate);
        Assert.Equal("Evli", result.MaritalStatus);
    }

    [Fact]
    public void AddressResponseUsesMatchingResidenceAndIgnoresOtherAddressError()
    {
        const string json = """
        {
          "Success": true,
          "Message": "Adres sorgulama başarılı.",
          "RawData": {
            "HataBilgisi": null,
            "SorguSonucu": [
              {
                "DigerAdresBilgileri": [
                  {
                    "HataBilgisi": {
                      "Aciklama": "KayitBulunamadi",
                      "Kod": 2
                    }
                  }
                ],
                "HataBilgisi": null,
                "KimlikNo": 12345678901,
                "YerlesimYeriAdresi": {
                  "AcikAdres": " ÖRNEK MAH. TEST SK. NO: 1 ",
                  "HataBilgisi": null
                }
              }
            ]
          }
        }
        """;

        var result = KpsResponseReader.ReadAddress(json, SyntheticIdentityNumber);

        Assert.Equal(SyntheticIdentityNumber, result.IdentityNumber);
        Assert.Equal("ÖRNEK MAH. TEST SK. NO: 1", result.FullAddress);
    }

    [Theory]
    [InlineData(5)]
    [InlineData(31)]
    public void IdentityFailureUsesKnownBusinessCode(int kpsCode)
    {
        var expectedReason = kpsCode switch
        {
            5 => KpsQueryRejectionReason.InvalidIdentityNumber,
            31 => KpsQueryRejectionReason.BirthDateMismatch,
            _ => throw new ArgumentOutOfRangeException(nameof(kpsCode)),
        };
        var json = $$"""
        {
          "Success": false,
          "Message": "Ham kurum mesajı",
          "RawData": {
            "SorguSonucu": [
              {
                "HataBilgisi": {
                  "Aciklama": "Ham kurum açıklaması",
                  "Kod": {{kpsCode}}
                },
                "KimlikNo": 12345678901,
                "YerlesimYeriAdresi": null
              }
            ]
          }
        }
        """;

        var error = Assert.Throws<KpsQueryRejectedException>(
            () => KpsResponseReader.ReadIdentity(json, SyntheticIdentityNumber));

        Assert.Equal(expectedReason, error.Reason);
        Assert.DoesNotContain(SyntheticIdentityNumber, error.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("Ham kurum", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void AddressFailurePrefersServiceAreaCodeAndIgnoresOtherAddressCode()
    {
        const string json = """
        {
          "Success": false,
          "Message": "AdreseErisimYetkiHatasi",
          "RawData": {
            "SorguSonucu": [
              {
                "DigerAdresBilgileri": [
                  {
                    "HataBilgisi": {
                      "Aciklama": "KayitBulunamadi",
                      "Kod": 2
                    }
                  }
                ],
                "HataBilgisi": null,
                "KimlikNo": 12345678901,
                "YerlesimYeriAdresi": {
                  "HataBilgisi": {
                    "Kod": 16
                  }
                }
              }
            ]
          }
        }
        """;

        var error = Assert.Throws<KpsQueryRejectedException>(
            () => KpsResponseReader.ReadAddress(json, SyntheticIdentityNumber));

        Assert.Equal(KpsQueryRejectionReason.AddressOutsideServiceArea, error.Reason);
    }

    [Fact]
    public void UnknownFailureCodeRemainsAContractError()
    {
        const string json = """
        {
          "Success": false,
          "Message": "Bilinmeyen ham KPS mesajı",
          "RawData": {
            "SorguSonucu": [
              {
                "HataBilgisi": {
                  "Kod": 999
                },
                "KimlikNo": 12345678901
              }
            ]
          }
        }
        """;

        var error = Assert.Throws<KpsResponseContractException>(
            () => KpsResponseReader.ReadIdentity(json, SyntheticIdentityNumber));

        Assert.Equal("KPS_KIMLIK_CEVABI_GECERSIZ", error.Code);
        Assert.DoesNotContain(SyntheticIdentityNumber, error.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("Bilinmeyen ham", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void IdentityResponseRejectsMismatchedIdentityWithoutLeakingIt()
    {
        const string json = """
        {
          "Success": true,
          "TcKimlikNo": 10987654321,
          "Ad": "ÖRNEK",
          "Soyad": "KİŞİ",
          "DogumGunu": 1,
          "DogumAy": 1,
          "DogumYili": 1990
        }
        """;

        var error = Assert.Throws<KpsResponseContractException>(
            () => KpsResponseReader.ReadIdentity(json, SyntheticIdentityNumber));

        Assert.Equal("KPS_KIMLIK_CEVABI_GECERSIZ", error.Code);
        Assert.DoesNotContain(SyntheticIdentityNumber, error.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("10987654321", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void AddressResponseRejectsMissingResidenceAddress()
    {
        const string json = """
        {
          "Success": true,
          "RawData": {
            "SorguSonucu": [
              {
                "KimlikNo": 12345678901,
                "YerlesimYeriAdresi": null
              }
            ]
          }
        }
        """;

        var error = Assert.Throws<KpsResponseContractException>(
            () => KpsResponseReader.ReadAddress(json, SyntheticIdentityNumber));

        Assert.Equal("KPS_ADRES_CEVABI_GECERSIZ", error.Code);
    }
}
