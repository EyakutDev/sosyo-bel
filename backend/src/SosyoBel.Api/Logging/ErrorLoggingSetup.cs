using Microsoft.Extensions.Logging.Console;
using SosyoBel.Infrastructure.Logging;

namespace SosyoBel.Api.Logging;

internal static class ErrorLoggingSetup
{
    public static void AddSosyoBelErrorLogging(this WebApplicationBuilder builder)
    {
        // Ham exception/SQL/request loglarını başka bir sink'e kopyalamayız.
        // Konsolda yalnız sunucu açılış-kapanış mesajları eski biçimde kalır;
        // Warning/Error/Critical kayıtları güvenli sağlayıcıdan geçer.
        builder.Logging.ClearProviders();
        builder.Logging.AddSimpleConsole();
        builder.Logging.AddFilter<ConsoleLoggerProvider>(
            (category, level) => category == "Microsoft.Hosting.Lifetime" &&
                                 level >= LogLevel.Information);
        builder.Logging.AddFilter<SafeFileLoggerProvider>(null, LogLevel.Warning);
        builder.Services.AddSosyoBelFileErrorLogging(builder.Configuration);
    }
}
