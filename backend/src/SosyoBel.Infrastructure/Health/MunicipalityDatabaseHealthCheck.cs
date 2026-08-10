using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.Infrastructure.Health;

/// <summary>
/// Readiness kontrolü, API'nin V2 veritabanına gerçekten erişip erişemediğini ölçer.
/// Bağlantı dizesi veya iç hata ayrıntısı HTTP yanıtında yayımlanmaz.
/// </summary>
public sealed class MunicipalityDatabaseHealthCheck(
    IDbContextFactory<SosyoBelDbContext> dbContextFactory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var dbContext =
                await dbContextFactory.CreateDbContextAsync(cancellationToken);

            return await dbContext.Database.CanConnectAsync(cancellationToken)
                ? HealthCheckResult.Healthy("V2 SQL Server bağlantısı kullanılabilir.")
                : HealthCheckResult.Unhealthy("V2 SQL Server bağlantısı kullanılamıyor.");
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy(
                "V2 SQL Server bağlantısı kontrol edilirken hata oluştu.",
                exception);
        }
    }
}
