using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.UnitTests;

public sealed class CompanyRequestChannelResolverTests
{
    [Theory]
    [InlineData("Yüz yüze görüşme")]
    [InlineData("Yüzyüze Görüşme")]
    [InlineData(" YÜZ YÜZE GÖRÜŞME ")]
    public void FaceToFaceNameIgnoresCaseDiacriticsAndSpacing(string name)
    {
        Assert.True(CompanyRequestChannelResolver.IsFaceToFace(name));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("Telefon")]
    [InlineData("Web Başvurusu")]
    [InlineData("Yüz yüze yardım")]
    public void UnrelatedChannelIsNotAccepted(string? name)
    {
        Assert.False(CompanyRequestChannelResolver.IsFaceToFace(name));
    }
}
