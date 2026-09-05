using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SosyoBel.Api.Logging;
using SosyoBel.Application.Applications;
using SosyoBel.Infrastructure.Logging;
using SosyoBel.Infrastructure.Storage;

namespace SosyoBel.UnitTests;

public sealed class FileErrorLoggingTests
{
    [Fact]
    public void UsesTurkeyTimeAndLocalDateForFilename()
    {
        using var temp = new LogTestDirectory();
        var clock = new TestClock(new(2026, 9, 4, 22, 10, 0, TimeSpan.Zero));
        var writer = Writer(temp.Path, clock);
        writer.Write(Entry(clock));

        var file = Assert.Single(Directory.GetFiles(temp.Path, "*.log"));
        Assert.Equal("sosyobel-20260905-0001.log", System.IO.Path.GetFileName(file));
        using var json = JsonDocument.Parse(File.ReadAllText(file));
        Assert.Equal(
            new DateTimeOffset(2026, 9, 5, 1, 10, 0, TimeSpan.FromHours(3)),
            json.RootElement.GetProperty("timestamp").GetDateTimeOffset());
    }

    [Fact]
    public void ProviderIgnoresNormalRequestsAndNeverFormatsSensitiveState()
    {
        using var temp = new LogTestDirectory();
        var clock = Clock();
        using var provider = new SafeFileLoggerProvider(Writer(temp.Path, clock), clock);
        var logger = provider.CreateLogger("SosyoBel.Test");
        using var unsafeScope = logger.BeginScope(new Dictionary<string, object>
        {
            ["identityNumber"] = "12345678901",
            ["Authorization"] = "Bearer PRIVATE_TOKEN",
        });
        using var scope = logger.BeginScope(new RequestLogContext
        {
            Method = "POST", Route = "/api/v1/applications/submit",
            Stage = RequestLogStage.StorePhotos, TraceId = "safe-trace",
        });
        logger.LogInformation("Normal request");
        Assert.Empty(Directory.GetFiles(temp.Path, "*.log"));
        var exception = new UnauthorizedAccessException(
            "12345678901 PRIVATE_TOKEN PRIVATE_PASSWORD C:\\private\\citizen.jpg");
        exception.Data["form"] = "PRIVATE_FORM";
        logger.Log(
            LogLevel.Error, new EventId(1001), "PRIVATE_STATE", exception,
            (_, _) => throw new InvalidOperationException("Formatter must never run"));

        var content = File.ReadAllText(Assert.Single(Directory.GetFiles(temp.Path, "*.log")));
        Assert.DoesNotContain("PRIVATE", content, StringComparison.Ordinal);
        Assert.DoesNotContain("12345678901", content, StringComparison.Ordinal);
        Assert.DoesNotContain("citizen.jpg", content, StringComparison.Ordinal);
        Assert.Contains("UnauthorizedAccessException", content, StringComparison.Ordinal);
        Assert.Contains("StorePhotos", content, StringComparison.Ordinal);
        Assert.Contains("safe-trace", content, StringComparison.Ordinal);
    }

    [Fact]
    public void RotationRespectsFileAndTotalByteLimitsAndKeepsNewestEntry()
    {
        using var temp = new LogTestDirectory();
        var clock = Clock();
        var writer = Writer(temp.Path, clock, maxFile: 1024, maxTotal: 2048);
        for (var index = 0; index < 25; index++)
            writer.Write(Entry(clock) with { EventId = index });

        var files = new DirectoryInfo(temp.Path).GetFiles("*.log");
        Assert.NotEmpty(files);
        Assert.All(files, file => Assert.InRange(file.Length, 1, 1024));
        Assert.InRange(files.Sum(file => file.Length), 1, 2048);
        var entries = files.OrderBy(file => file.Name, StringComparer.Ordinal)
            .SelectMany(file => File.ReadAllLines(file.FullName))
            .Select(line => JsonSerializer.Deserialize<JsonElement>(line)).ToArray();
        Assert.Equal(25 - 1, entries[^1].GetProperty("eventId").GetInt32());
    }

    [Fact]
    public void MaintenanceExpiresOnlyManagedFilesEvenWithoutNewErrors()
    {
        using var temp = new LogTestDirectory();
        var expired = System.IO.Path.Combine(temp.Path, "sosyobel-20260820-0001.log");
        var recent = System.IO.Path.Combine(temp.Path, "sosyobel-20260903-0001.log");
        var unrelated = System.IO.Path.Combine(temp.Path, "company.log");
        var invalidDate = System.IO.Path.Combine(temp.Path, "sosyobel-20269999-0001.log");
        var nested = Directory.CreateDirectory(System.IO.Path.Combine(temp.Path, "nested"));
        var nestedFile = System.IO.Path.Combine(nested.FullName, "sosyobel-20260820-0001.log");
        foreach (var file in new[] { expired, recent, unrelated, invalidDate, nestedFile })
            File.WriteAllText(file, "artificial test data");

        Writer(temp.Path, Clock()).Prune();

        Assert.False(File.Exists(expired));
        Assert.True(File.Exists(recent));
        Assert.True(File.Exists(unrelated));
        Assert.True(File.Exists(invalidDate));
        Assert.True(File.Exists(nestedFile));
    }

    [Fact]
    public void MaintenanceEnforcesTotalSizeAfterConfigurationIsReduced()
    {
        using var temp = new LogTestDirectory();
        for (var i = 1; i <= 3; i++)
            File.WriteAllText(
                System.IO.Path.Combine(temp.Path, $"sosyobel-20260904-{i:D4}.log"),
                new string('a', 800));
        Writer(temp.Path, Clock(), maxFile: 1024, maxTotal: 1024).Prune();
        var file = Assert.Single(new DirectoryInfo(temp.Path).GetFiles("*.log"));
        Assert.Equal("sosyobel-20260904-0003.log", file.Name);
    }

    [Theory]
    [InlineData("")]
    [InlineData("relative-log-directory")]
    public void UnconfiguredOrRelativeDirectoryFallsBackWithoutCreatingFiles(string path)
    {
        var lines = new List<string>();
        var clock = Clock();
        var writer = Writer(path, clock, console: lines.Add);
        writer.Prune();
        writer.Write(Entry(clock));
        Assert.Contains(lines, line => line.Contains("file_log_unavailable", StringComparison.Ordinal));
        Assert.Contains(lines, line => IsEvent(line, 7));
    }

    [Fact]
    public void InvalidConfigurationDoesNotBreakApplicationStartup()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["FileErrorLogging:RetentionDays"] = "not-an-integer",
            }).Build();
        Assert.Equal(string.Empty, FileErrorLogOptions.Read(configuration).DirectoryPath);
    }

    [Fact]
    public void IoAndConsoleFailuresDoNotEscapeLogger()
    {
        using var temp = new LogTestDirectory();
        var blocked = System.IO.Path.Combine(temp.Path, "not-a-directory");
        File.WriteAllText(blocked, "keep");
        var clock = Clock();
        var writer = Writer(blocked, clock, console: _ => throw new IOException("closed console"));
        Assert.Null(Record.Exception(() => writer.Write(Entry(clock))));
        Assert.Null(Record.Exception(writer.Prune));
        Assert.Equal("keep", File.ReadAllText(blocked));
    }

    [Fact]
    public void BusyWriterFallsBackThenRecoversWithoutBreakingByteLimits()
    {
        using var temp = new LogTestDirectory();
        var console = new List<string>();
        var clock = Clock();
        var writer = Writer(temp.Path, clock, console: console.Add);
        using (new FileStream(
            System.IO.Path.Combine(temp.Path, ".sosyobel-writer.lock"),
            FileMode.Create, FileAccess.ReadWrite, FileShare.None))
        {
            writer.Write(Entry(clock));
        }
        writer.Write(Entry(clock) with { EventId = 8 });
        Assert.Contains(console, line => IsEvent(line, 7));
        var file = Assert.Single(Directory.GetFiles(temp.Path, "*.log"));
        Assert.True(IsEvent(File.ReadAllText(file), 8));
    }

    [Fact]
    public async Task ConcurrentRequestsKeepTheirOwnTraceAndStage()
    {
        using var temp = new LogTestDirectory();
        var clock = Clock();
        using var provider = new SafeFileLoggerProvider(Writer(temp.Path, clock), clock);
        var logger = provider.CreateLogger("SosyoBel.Test");
        await Task.WhenAll(Enumerable.Range(0, 12).Select(index => Task.Run(async () =>
        {
            using var scope = logger.BeginScope(new RequestLogContext { TraceId = $"trace-{index}" });
            await Task.Yield();
            logger.Log(LogLevel.Error, new EventId(index), "", null, (_, _) => "");
        })));
        var lines = Directory.GetFiles(temp.Path, "*.log").SelectMany(File.ReadAllLines);
        var entries = lines.Select(line => JsonSerializer.Deserialize<JsonElement>(line)).ToArray();
        Assert.Equal(12, entries.Length);
        Assert.All(entries, entry => Assert.Equal(
            $"trace-{entry.GetProperty("eventId").GetInt32()}",
            entry.GetProperty("traceId").GetString()));
    }

    [Fact]
    public async Task RealHttpExceptionRetainsGenericResponseAndMatchingSafeTrace()
    {
        using var temp = new LogTestDirectory();
        await using var app = CreateTestApi(temp.Path);
        app.MapGet("/test/failure/{id}", Fail);
        await app.StartAsync();
        using var client = new HttpClient();
        var response = await client.GetAsync(
            app.Urls.Single() + "/test/failure/12345678901?token=PRIVATE_QUERY");
        var responseBody = await response.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        Assert.DoesNotContain("PRIVATE", responseBody, StringComparison.Ordinal);
        using var problem = JsonDocument.Parse(responseBody);
        var trace = problem.RootElement.GetProperty("traceId").GetString();
        var entries = Directory.GetFiles(temp.Path, "*.log").SelectMany(File.ReadAllLines)
            .Select(line => JsonSerializer.Deserialize<JsonElement>(line)).ToArray();
        var failure = Assert.Single(entries, entry =>
            entry.GetProperty("category").GetString() ==
                "Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware" &&
            entry.GetProperty("eventId").GetInt32() == 1);
        Assert.Equal(trace, failure.GetProperty("traceId").GetString());
        Assert.Equal("/test/failure/{id}", failure.GetProperty("route").GetString());
        Assert.Equal("SaveFamilyAndPhotos", failure.GetProperty("stage").GetString());
        Assert.DoesNotContain("PRIVATE", failure.ToString(), StringComparison.Ordinal);
        Assert.DoesNotContain("12345678901", failure.ToString(), StringComparison.Ordinal);
        await app.StopAsync();
    }

    [Fact]
    public async Task PhotoStorageConstructorFailureIsCapturedBeforeEndpointRuns()
    {
        using var temp = new LogTestDirectory();
        await using var app = CreateTestApi(temp.Path, registerPhotoStorage: true);
        app.MapGet("/test/photo-init", (IApplicationPhotoStorage storage) => Results.Ok());
        await app.StartAsync();
        using var client = new HttpClient();
        var response = await client.GetAsync(app.Urls.Single() + "/test/photo-init");
        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        var text = string.Join("\n", Directory.GetFiles(temp.Path, "*.log").Select(File.ReadAllText));
        Assert.Contains("InitializePhotoStorage", text, StringComparison.Ordinal);
        Assert.Contains("InvalidOperationException", text, StringComparison.Ordinal);
        await app.StopAsync();
    }

    private static IResult Fail(RequestLogContext context)
    {
        context.Stage = RequestLogStage.SaveFamilyAndPhotos;
        throw new InvalidOperationException("PRIVATE_PASSWORD 12345678901");
    }

    private static bool IsEvent(string line, int id) =>
        line.StartsWith('{') &&
        JsonSerializer.Deserialize<JsonElement>(line).GetProperty("eventId").GetInt32() == id;

    private static WebApplication CreateTestApi(string logDirectory, bool registerPhotoStorage = false)
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = "Production",
            ContentRootPath = logDirectory,
        });
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["FileErrorLogging:DirectoryPath"] = logDirectory,
            ["ApplicationPhotos:RootPath"] = "",
        });
        builder.AddSosyoBelErrorLogging();
        builder.Services.AddProblemDetails();
        if (registerPhotoStorage)
            builder.Services.AddScoped<IApplicationPhotoStorage, LocalApplicationPhotoStorage>();
        var app = builder.Build();
        app.Urls.Add("http://127.0.0.1:0");
        app.UseMiddleware<RequestLogScopeMiddleware>();
        app.UseExceptionHandler(new ExceptionHandlerOptions { SuppressDiagnosticsCallback = _ => false });
        return app;
    }

    private static RollingErrorFileWriter Writer(
        string path, TimeProvider clock, long maxFile = 64 * 1024, long maxTotal = 256 * 1024,
        Action<string>? console = null) =>
        new(path, 14, maxFile, maxTotal, clock, console ?? (_ => { }));

    private static TestClock Clock() => new(new(2026, 9, 4, 12, 0, 0, TimeSpan.Zero));

    private static SafeErrorLogEntry Entry(TimeProvider clock) =>
        SafeErrorLogEntry.Create(clock.GetUtcNow(), LogLevel.Error, "SosyoBel.Test",
            new EventId(7), null, new RequestLogContext { TraceId = "test-trace" });

    private sealed class TestClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}

internal sealed class LogTestDirectory : IDisposable
{
    public string Path { get; } = Directory.CreateTempSubdirectory("sosyobel-log-tests-").FullName;

    public void Dispose()
    {
        var full = System.IO.Path.GetFullPath(Path);
        var tempRoot = System.IO.Path.GetFullPath(System.IO.Path.GetTempPath())
            .TrimEnd(System.IO.Path.DirectorySeparatorChar) + System.IO.Path.DirectorySeparatorChar;
        if (!full.StartsWith(tempRoot, StringComparison.OrdinalIgnoreCase) ||
            !System.IO.Path.GetFileName(full).StartsWith("sosyobel-log-tests-", StringComparison.Ordinal) ||
            (File.GetAttributes(full) & FileAttributes.ReparsePoint) != 0)
            throw new InvalidOperationException("Unexpected test cleanup target.");
        Directory.Delete(full, recursive: true);
    }
}
