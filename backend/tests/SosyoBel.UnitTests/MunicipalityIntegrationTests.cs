using SosyoBel.Domain.Municipalities;

namespace SosyoBel.UnitTests;

public sealed class MunicipalityIntegrationTests
{
    [Fact]
    public void SqlServerIntegrationCannotActivateBeforeConfiguration()
    {
        var integration = MunicipalityIntegration.Create(
            municipalityId: 1,
            name: "Belediye SQL",
            type: MunicipalityIntegrationType.SqlServer,
            accessScope: MunicipalityIntegrationAccessScope.ReadOnly);

        var exception = Assert.Throws<InvalidOperationException>(integration.Activate);

        Assert.Contains("bağlantı ayarları", exception.Message, StringComparison.OrdinalIgnoreCase);
        Assert.False(integration.IsActive);
    }

    [Fact]
    public void SqlServerIntegrationActivatesWithSecretReference()
    {
        var integration = MunicipalityIntegration.Create(
            municipalityId: 1,
            name: "Belediye SQL",
            type: MunicipalityIntegrationType.SqlServer,
            accessScope: MunicipalityIntegrationAccessScope.ReadOnly);

        integration.ConfigureSqlServer(
            serverAddress: "10.20.0.15",
            port: 1433,
            databaseName: "SosyalHizmetDb",
            secretReference: "env://MUNICIPALITY_SQL_SECRET",
            authenticationType: MunicipalityAuthenticationType.SqlAccount);
        integration.Activate();

        Assert.True(integration.IsActive);
        Assert.Equal("env://MUNICIPALITY_SQL_SECRET", integration.SecretReference);
    }

    [Fact]
    public void RestApiRequiresHttps()
    {
        var integration = MunicipalityIntegration.Create(
            municipalityId: 1,
            name: "Belediye API",
            type: MunicipalityIntegrationType.RestApi,
            accessScope: MunicipalityIntegrationAccessScope.ReadOnly);

        Assert.Throws<ArgumentException>(() => integration.ConfigureRestApi(
            new Uri("http://example.test"),
            "env://MUNICIPALITY_API_SECRET",
            MunicipalityAuthenticationType.ApiKey));
    }

    [Fact]
    public void MunicipalityNormalizesCodeAndBranding()
    {
        var municipality = Municipality.Create(" demo ", " Demo Belediyesi ");

        Assert.Equal("DEMO", municipality.Code);
        Assert.Equal("Demo Belediyesi", municipality.Name);
    }
}
