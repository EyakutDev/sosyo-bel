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

    private sealed class StubKpsClient : IKpsClient
    {
        public int IdentityCallCount { get; private set; }

        public int AddressCallCount { get; private set; }

        public Task<KpsIdentityInformation> GetIdentityAsync(
            KpsLookupCriteria criteria,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            IdentityCallCount++;
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
            return Task.FromResult(new KpsAddressInformation(
                criteria.IdentityNumber,
                "ÖRNEK MAH. TEST SK. NO: 1"));
        }
    }
}
