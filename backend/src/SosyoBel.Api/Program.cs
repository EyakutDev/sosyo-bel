using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using SosyoBel.Api;
using SosyoBel.Api.Administration;
using SosyoBel.Api.Applications;
using SosyoBel.Api.Authentication;
using SosyoBel.Api.Auditing;
using SosyoBel.Api.FieldTasks;
using SosyoBel.Api.Kps;
using SosyoBel.Api.OpenApi;
using SosyoBel.Api.References;
using SosyoBel.Api.Tenant;
using SosyoBel.Api.WorkItems;
using SosyoBel.Application.Abstractions;
using SosyoBel.Infrastructure;
using SosyoBel.Infrastructure.Health;
using SosyoBel.Infrastructure.Identity;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentMunicipality, HttpCurrentMunicipality>();
builder.Services.AddSosyoBelInfrastructure(builder.Configuration);
builder.Services.AddSosyoBelIdentity(builder.Configuration);
builder.Services.AddSosyoBelAuthentication(builder.Configuration);
builder.Services.AddAuthenticationRateLimiting();
builder.Services.AddSosyoBelOpenApi();
builder.Services
    .AddHealthChecks()
    .AddCheck<MunicipalityDatabaseHealthCheck>(
        "sosyobel-database",
        failureStatus: HealthStatus.Unhealthy,
        tags: ["ready"]);

var app = builder.Build();

app.UseExceptionHandler();
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
        "Sosyo-Bel veritabanı bağlantısını da sınar.")
    .AllowAnonymous();

app.MapAuthenticationEndpoints();
app.MapAdministrationEndpoints();
app.MapApplicationEndpoints();
app.MapApplicationReferenceEndpoints();
app.MapAuditEndpoints();
app.MapFieldTaskEndpoints();
app.MapKpsEndpoints();
app.MapWorkItemEndpoints();
app.MapSosyoBelOpenApi();

app.Run();

// WebApplicationFactory ile entegrasyon testi yazılabilmesi için görünür giriş noktası.
public partial class Program;
