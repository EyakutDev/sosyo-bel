using SosyoBel.Application.Administration;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.UnitTests;

public sealed class SensitiveDataBoundaryTests
{
    [Theory]
    [InlineData(typeof(AdministrationAuditRecord))]
    [InlineData(typeof(ManagedUserSummary))]
    [InlineData(typeof(ProvisionedMunicipalitySummary))]
    [InlineData(typeof(PermissionChangeSummary))]
    [InlineData(typeof(SystemAdministratorBootstrapResult))]
    public void AuditAndResponseModelsCannotCarryCredentialFields(Type modelType)
    {
        var forbiddenFragments = new[]
        {
            "password",
            "parola",
            "token",
            "secret",
            "sifre",
        };

        var unsafeProperties = modelType
            .GetProperties()
            .Where(property => forbiddenFragments.Any(fragment =>
                property.Name.Contains(fragment, StringComparison.OrdinalIgnoreCase)))
            .Select(property => property.Name)
            .ToArray();

        Assert.Empty(unsafeProperties);
    }
}
