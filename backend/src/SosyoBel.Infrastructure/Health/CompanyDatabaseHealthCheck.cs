using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using SosyoBel.Infrastructure.Persistence;

namespace SosyoBel.Infrastructure.Health;

/// <summary>
/// API'nin şirket SQL Server veritabanına erişebildiğini denetler.
/// Bağlantı dizesi ve iç hata ayrıntıları HTTP yanıtında yayımlanmaz.
/// </summary>
public sealed class CompanyDatabaseHealthCheck(
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
                ? HealthCheckResult.Healthy("Şirket SQL Server bağlantısı kullanılabilir.")
                : HealthCheckResult.Unhealthy("Şirket SQL Server bağlantısı kullanılamıyor.");
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy(
                "Şirket SQL Server bağlantısı kontrol edilirken hata oluştu.",
                exception);
        }
    }
}
