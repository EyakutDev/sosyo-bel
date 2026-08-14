using System.Net;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.Kps;
using SosyoBel.Infrastructure.Kps;

namespace SosyoBel.UnitTests;

public sealed class KpsProfileQueryTests
{
    private static readonly KpsProfileActor Actor = new("personnel-1", 12, 34);
    private static readonly KpsLookupCriteria Criteria = new(
        "12345678901",
        new DateOnly(1986, 9, 14));

    [Fact]
    public async Task MissingPermissionStopsBeforeAnyKpsCall()
    {
        var permissionChecker = new StubPermissionChecker(false);
        var kpsClient = new StubKpsClient();
        var query = new KpsProfileQuery(
            permissionChecker,
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria,
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.AccessDenied, result.Status);
        Assert.Equal("kps_permission_required", result.Code);
        Assert.Equal(PermissionCodes.KpsLookup, permissionChecker.PermissionCode);
        Assert.Equal(0, kpsClient.IdentityCallCount);
        Assert.Equal(0, kpsClient.AddressCallCount);
    }

    [Fact]
    public async Task AuthorizedQueryCombinesIdentityAndAddress()
    {
        var permissionChecker = new StubPermissionChecker(true);
        var kpsClient = new StubKpsClient();
        var query = new KpsProfileQuery(
            permissionChecker,
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
    public async Task InvalidCriteriaStopsBeforePermissionAndKpsCalls()
    {
        var permissionChecker = new StubPermissionChecker(true);
        var kpsClient = new StubKpsClient();
        var query = new KpsProfileQuery(
            permissionChecker,
            kpsClient,
            TimeProvider.System);

        var result = await query.GetProfileAsync(
            Actor,
            Criteria with { IdentityNumber = "123" },
            CancellationToken.None);

        Assert.Equal(KpsProfileQueryStatus.InvalidInput, result.Status);
        Assert.Equal(0, permissionChecker.CallCount);
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
            new StubPermissionChecker(true),
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
            new StubPermissionChecker(true),
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
            new StubPermissionChecker(true),
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

    private sealed class StubPermissionChecker(bool allowed) : IAccessPermissionChecker
    {
        public int CallCount { get; private set; }

        public string? PermissionCode { get; private set; }

        public Task<bool> HasPermissionAsync(
            string userId,
            long municipalityMembershipId,
            int municipalityId,
            string permissionCode,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            CallCount++;
            PermissionCode = permissionCode;
            return Task.FromResult(allowed);
        }
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
