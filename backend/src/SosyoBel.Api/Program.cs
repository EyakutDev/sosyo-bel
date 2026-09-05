using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using SosyoBel.Api;
using SosyoBel.Api.Applications;
using SosyoBel.Api.Authentication;
using SosyoBel.Api.Kps;
using SosyoBel.Api.Logging;
using SosyoBel.Api.OpenApi;
using SosyoBel.Api.References;
using SosyoBel.Api.WorkItems;
using SosyoBel.Infrastructure;
using SosyoBel.Infrastructure.Health;
using SosyoBel.Infrastructure.Identity;

var builder = WebApplication.CreateBuilder(args);
builder.AddSosyoBelErrorLogging();

// Program.cs composition root olarak kalır: katmanların gerçek uygulamaları burada
// bağlanır; başvuru, kimlik veya KPS iş kuralları bu dosyada uygulanmaz.
builder.Services.AddProblemDetails();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSosyoBelInfrastructure(builder.Configuration);
builder.Services.AddSosyoBelIdentity(builder.Configuration);
builder.Services.AddSosyoBelAuthentication(builder.Configuration);
builder.Services.AddAuthenticationRateLimiting();
builder.Services.AddSosyoBelOpenApi();
builder.Services
    .AddHealthChecks()
    .AddCheck<CompanyDatabaseHealthCheck>(
        "company-database",
        failureStatus: HealthStatus.Unhealthy,
        tags: ["ready"]);

var app = builder.Build();

// Sıra güvenlik davranışının parçasıdır: authentication kullanıcıyı oluşturur,
// authorization ise endpoint çalışmadan önce şirketin mevcut Identity rollerini uygular.
app.UseMiddleware<RequestLogScopeMiddleware>();
app.UseExceptionHandler(new ExceptionHandlerOptions
{
    // .NET 10'da ele alınan exception'larda da güvenli hata kaydı üretilsin.
    // HTTP hata cevabı mevcut ProblemDetails davranışında kalır.
    SuppressDiagnosticsCallback = _ => false,
});
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", (IHostEnvironment environment) => Results.Ok(new
{
    service = "Sosyo-Bel API",
    environment = environment.EnvironmentName,
    version = typeof(Program).Assembly.GetName().Version?.ToString(),
}))
    .WithTags("Sistem")
    .WithSummary("API servis bilgilerini getirir")
    .WithDescription(
        "Sosyo-Bel API'nin çalıştığını, aktif çalışma ortamını ve derleme sürümünü gösterir.")
    .AllowAnonymous();

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false,
    ResponseWriter = HealthResponseWriter.WriteAsync,
})
    .WithTags("Sistem")
    .WithSummary("Servisin çalıştığını denetler")
    .WithDescription(
        "IIS veya yük dengeleyicinin API sürecinin ayakta olduğunu kontrol etmesi için kullanılır; " +
        "veritabanı bağlantısını sınamaz.")
    .AllowAnonymous();

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = registration => registration.Tags.Contains("ready"),
    ResponseWriter = HealthResponseWriter.WriteAsync,
})
    .WithTags("Sistem")
    .WithSummary("Servisin isteklere hazır olduğunu denetler")
    .WithDescription(
        "API'nin bağımlılıklarıyla birlikte trafik almaya hazır olup olmadığını kontrol eder; " +
        "Şirket SQL Server veritabanı bağlantısını da sınar.")
    .AllowAnonymous();

// Endpoint dosyaları yalnız HTTP sınırını tanımlar; kalıcı veri ve dış servis
// işlemleri Application sözleşmeleri üzerinden Infrastructure katmanına geçer.
app.MapAuthenticationEndpoints();
app.MapApplicationEndpoints();
app.MapApplicationReferenceEndpoints();
app.MapKpsEndpoints();
app.MapWorkItemEndpoints();
app.MapSosyoBelOpenApi();

// Kullanıcı ve rol yönetimi şirketin mevcut web panelinin sorumluluğundadır.
// Mobil API yalnız saha uygulamasının kullandığı sözleşmeleri yayımlar.

app.Run();

// WebApplicationFactory ile entegrasyon testi yazılabilmesi için görünür giriş noktası.
public partial class Program;
