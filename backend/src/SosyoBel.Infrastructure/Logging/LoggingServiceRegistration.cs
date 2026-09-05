using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;

namespace SosyoBel.Infrastructure.Logging;

public static class LoggingServiceRegistration
{
    public static IServiceCollection AddSosyoBelFileErrorLogging(
        this IServiceCollection services, IConfiguration configuration)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddScoped<RequestLogContext>();
        services.AddSingleton(FileErrorLogOptions.Read(configuration));
        services.AddSingleton<SafeFileLoggerProvider>();
        services.AddSingleton<ILoggerProvider>(provider =>
            provider.GetRequiredService<SafeFileLoggerProvider>());
        services.AddHostedService<FileLogMaintenanceService>();
        return services;
    }
}
