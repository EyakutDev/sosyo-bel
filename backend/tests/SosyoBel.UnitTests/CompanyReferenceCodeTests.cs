using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class CompanyReferenceCodeTests
{
    [Theory]
    [InlineData("YARDIM_TURU", 12, "YARDIM_TURU:12")]
    [InlineData("ENGEL_TURU", 7, "ENGEL_TURU:7")]
    [InlineData("YAKINLIK", 1, "YAKINLIK:1")]
    public void EncodeIncludesReferenceTypeAndCompanyId(
        string referenceType,
        int sourceId,
        string expected)
    {
        Assert.Equal(expected, CompanyReferenceCode.Encode(referenceType, sourceId));
    }

    [Theory]
    [InlineData("YARDIM_TURU", "YARDIM_TURU:12", 12)]
    [InlineData("YARDIM_TURU", "yardim_turu:12", 12)]
    [InlineData("ENGEL_TURU", " ENGEL_TURU:7 ", 7)]
    public void TryDecodeAcceptsOnlyPositiveCompanyIds(
        string referenceType,
        string code,
        int expectedId)
    {
        Assert.True(CompanyReferenceCode.TryDecode(referenceType, code, out var sourceId));
        Assert.Equal(expectedId, sourceId);
    }

    [Theory]
    [InlineData("YARDIM_TURU", "ENGEL_TURU:12")]
    [InlineData("YARDIM_TURU", "YARDIM_TURU:0")]
    [InlineData("YARDIM_TURU", "YARDIM_TURU:-1")]
    [InlineData("YARDIM_TURU", "YARDIM_TURU:ABC")]
    [InlineData("YARDIM_TURU", "12")]
    public void TryDecodeRejectsWrongTypeOrInvalidId(
        string referenceType,
        string code)
    {
        Assert.False(CompanyReferenceCode.TryDecode(referenceType, code, out _));
    }
}
