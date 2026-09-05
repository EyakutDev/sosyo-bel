using Microsoft.Extensions.Hosting;

namespace SosyoBel.Infrastructure.Logging;

/// <summary>Hiç yeni hata gelmese de süresi dolan kayıtları saatlik temizler.</summary>
internal sealed class FileLogMaintenanceService(
    SafeFileLoggerProvider provider,
    TimeProvider clock) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        provider.Prune();
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1), clock);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
                provider.Prune();
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
    }
}
