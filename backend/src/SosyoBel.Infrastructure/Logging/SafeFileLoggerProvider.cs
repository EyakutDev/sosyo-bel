using Microsoft.Extensions.Logging;

namespace SosyoBel.Infrastructure.Logging;

public sealed class SafeFileLoggerProvider : ILoggerProvider, ISupportExternalScope
{
    private readonly RollingErrorFileWriter writer;
    private readonly TimeProvider clock;
    private IExternalScopeProvider scopes = new LoggerExternalScopeProvider();

    public SafeFileLoggerProvider(FileErrorLogOptions options, TimeProvider clock)
        : this(new RollingErrorFileWriter(options, clock), clock)
    {
    }

    internal SafeFileLoggerProvider(RollingErrorFileWriter writer, TimeProvider clock)
    {
        this.writer = writer;
        this.clock = clock;
    }

    public ILogger CreateLogger(string categoryName) => new SafeLogger(this, categoryName);
    public void SetScopeProvider(IExternalScopeProvider scopeProvider) => scopes = scopeProvider;
    public void Dispose() { }
    internal void Prune() => writer.Prune();

    private sealed class SafeLogger(SafeFileLoggerProvider owner, string category) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull =>
            owner.scopes.Push(state);

        public bool IsEnabled(LogLevel logLevel) =>
            logLevel is LogLevel.Warning or LogLevel.Error or LogLevel.Critical;

        public void Log<TState>(
            LogLevel logLevel, EventId eventId, TState state, Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel)) return;
            try
            {
                RequestLogContext? request = null;
                owner.scopes.ForEachScope((scope, _) =>
                {
                    if (scope is RequestLogContext context) request = context;
                }, state: 0);
                // formatter/state ve diğer scope'lar bilerek okunmaz. Framework
                // SQL komutu, query string veya form değerleri buradan sızamaz.
                owner.writer.Write(SafeErrorLogEntry.Create(
                    owner.clock.GetUtcNow(), logLevel, category, eventId, exception, request));
            }
            catch
            {
                try { Console.Error.WriteLine("file_log_failed: Güvenli hata kaydı üretilemedi."); }
                catch { }
            }
        }
    }
}
