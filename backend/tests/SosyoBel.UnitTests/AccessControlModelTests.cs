using SosyoBel.Application.Authorization;

namespace SosyoBel.UnitTests;

public sealed class AccessControlModelTests
{
    [Theory]
    [InlineData(CompanyIdentityRoleCodes.Administrator)]
    [InlineData(CompanyIdentityRoleCodes.Board)]
    [InlineData(CompanyIdentityRoleCodes.Personnel)]
    [InlineData("ADMIN")]
    [InlineData("personel")]
    public void ExistingCompanyRolesGrantMobileFieldAccess(string role)
    {
        Assert.True(CompanyIdentityRoleCodes.GrantsMobileFieldAccess(role));
    }

    [Theory]
    [InlineData("Nakdi Yardımlar")]
    [InlineData("SISTEM_YONETICISI")]
    [InlineData("BELEDIYE_YONETICISI")]
    [InlineData("BilinmeyenRol")]
    [InlineData(null)]
    public void UnapprovedOrLegacyRolesDoNotGrantMobileFieldAccess(string? role)
    {
        Assert.False(CompanyIdentityRoleCodes.GrantsMobileFieldAccess(role));
    }
}
