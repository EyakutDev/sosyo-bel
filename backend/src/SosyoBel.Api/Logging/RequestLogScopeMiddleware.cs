using System.Diagnostics;
using SosyoBel.Infrastructure.Logging;

namespace SosyoBel.Api.Logging;

/// <summary>
/// ExceptionHandler'ın DI/endpoint hatalarını logladığı anda scope hâlâ açık
/// olmalıdır; bu nedenle middleware UseExceptionHandler'dan önce yerleştirilir.
/// </summary>
internal sealed class RequestLogScopeMiddleware(
    RequestDelegate next,
    ILogger<RequestLogScopeMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context, RequestLogContext logContext)
    {
        logContext.Method = context.Request.Method switch
        {
            "GET" or "POST" or "PUT" or "PATCH" or "DELETE" or "HEAD" or "OPTIONS"
                => context.Request.Method,
            _ => "OTHER",
        };
        // Route şablonu sabittir. Path/QueryString/headers/claims asla alınmaz.
        logContext.Route = (context.GetEndpoint() as RouteEndpoint)?
            .RoutePattern.RawText ?? "(unmatched)";
        logContext.TraceId = Activity.Current?.Id ?? context.TraceIdentifier;
        using (logger.BeginScope(logContext))
            await next(context);
    }
}
