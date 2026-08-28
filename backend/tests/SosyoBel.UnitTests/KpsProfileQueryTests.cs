using System.Net;
using SosyoBel.Application.Kps;
using SosyoBel.Infrastructure.Kps;

namespace SosyoBel.UnitTests;

public sealed class KpsProfileQueryTests
{
    private static readonly KpsProfileActor Actor = new("identity-user-1");
    private static readonly KpsLookupCriteria Criteria = new(
        "12345678901",
        new DateOnly(1986, 9, 14));

    [Fact]
    public async Task MissingAuthenticatedUserStopsBeforeAnyKpsCall()
    {
        var kpsClient = new StubKpsClient();
        var query = new KpsProfileQuery(
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            new KpsProfileActor(" "),
            Criteria,
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.InvalidInput, result.Status);
        Assert.Contains("actor", result.Errors!.Keys);
        Assert.Equal(0, kpsClient.IdentityCallCount);
        Assert.Equal(0, kpsClient.AddressCallCount);
    }

    [Fact]
    public async Task AuthenticatedUserQueryCombinesIdentityAndAddress()
    {
        var kpsClient = new StubKpsClient();
        var query = new KpsProfileQuery(
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria,
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.Succeeded, result.Status);
        Assert.NotNull(result.Value);
        Assert.Equal("ÖRNEK", result.Value.FirstName);
        Assert.Equal("ÖRNEK MAH. TEST SK. NO: 1", result.Value.FullAddress);
        Assert.Equal(1, kpsClient.IdentityCallCount);
        Assert.Equal(1, kpsClient.AddressCallCount);
    }

    [Fact]
    public async Task InvalidCriteriaStopsBeforeKpsCalls()
    {
        var kpsClient = new StubKpsClient();
        var query = new KpsProfileQuery(
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria with { IdentityNumber = "123" },
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.InvalidInput, result.Status);
        Assert.Equal(0, kpsClient.IdentityCallCount);
        Assert.Equal(0, kpsClient.AddressCallCount);
    }

    [Theory]
    [InlineData(
        5,
        KpsProfileQueryStatus.InvalidIdentityNumber,
        "kps_invalid_identity_number",
        "Geçerli bir T.C. kimlik numarası giriniz.")]
    [InlineData(
        31,
        KpsProfileQueryStatus.BirthDateMismatch,
        "kps_identity_birth_date_mismatch",
        "T.C. kimlik numarası ile doğum tarihi eşleşmiyor.")]
    public async Task IdentityBusinessFailureMapsToSafeApplicationResult(
        int kpsCode,
        KpsProfileQueryStatus expectedStatus,
        string expectedCode,
        string expectedDetail)
    {
        var reason = kpsCode switch
        {
            5 => KpsQueryRejectionReason.InvalidIdentityNumber,
            31 => KpsQueryRejectionReason.BirthDateMismatch,
            _ => throw new ArgumentOutOfRangeException(nameof(kpsCode)),
        };
        var kpsClient = new StubKpsClient(
            identityException: new KpsQueryRejectedException(reason));
        var query = new KpsProfileQuery(
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria,
            CancellationToken.None);

        Assert.Equal(expectedStatus, result.Status);
        Assert.Equal(expectedCode, result.Code);
        Assert.Equal(expectedDetail, result.Detail);
        Assert.Equal(1, kpsClient.IdentityCallCount);
        Assert.Equal(0, kpsClient.AddressCallCount);
    }

    [Fact]
    public async Task AddressOutsideServiceAreaBlocksProfileWithApprovedMessage()
    {
        var kpsClient = new StubKpsClient(
            addressException: new KpsQueryRejectedException(
                KpsQueryRejectionReason.AddressOutsideServiceArea));
        var query = new KpsProfileQuery(
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria,
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.AddressOutsideServiceArea, result.Status);
        Assert.Equal("kps_address_outside_service_area", result.Code);
        Assert.Equal("Adres kurumun hizmet alanı dışında.", result.Detail);
        Assert.Equal(1, kpsClient.IdentityCallCount);
        Assert.Equal(1, kpsClient.AddressCallCount);
    }

    [Fact]
    public async Task UpstreamBadRequestMapsToInvalidKpsRequest()
    {
        var kpsClient = new StubKpsClient(
            identityException: new KpsClientException(
                "KPS_HTTP_HATASI",
                "Ham upstream mesajı",
                HttpStatusCode.BadRequest));
        var query = new KpsProfileQuery(
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria,
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.UpstreamInvalidRequest, result.Status);
        Assert.Equal("kps_invalid_request", result.Code);
        Assert.Equal("KPS sorgu bilgileri eksik veya geçersiz.", result.Detail);
        Assert.DoesNotContain("upstream", result.Detail, StringComparison.OrdinalIgnoreCase);
    }

    private sealed class StubKpsClient(
        Exception? identityException = null,
        Exception? addressException = null) : IKpsClient
    {
        public int IdentityCallCount { get; private set; }

        public int AddressCallCount { get; private set; }

        public Task<KpsIdentityInformation> GetIdentityAsync(
            KpsLookupCriteria criteria,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            IdentityCallCount++;
            if (identityException is not null)
            {
                return Task.FromException<KpsIdentityInformation>(identityException);
            }
            return Task.FromResult(new KpsIdentityInformation(
                criteria.IdentityNumber,
                "ÖRNEK",
                "KİŞİ",
                "BABA",
                "ANNE",
                criteria.BirthDate,
                "ÖRNEK İL",
                "Erkek",
                "Evli",
                "Açık"));
        }

        public Task<KpsAddressInformation> GetAddressAsync(
            KpsLookupCriteria criteria,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            AddressCallCount++;
            if (addressException is not null)
            {
                return Task.FromException<KpsAddressInformation>(addressException);
            }
            return Task.FromResult(new KpsAddressInformation(
                criteria.IdentityNumber,
                "ÖRNEK MAH. TEST SK. NO: 1"));
        }
    }
}
