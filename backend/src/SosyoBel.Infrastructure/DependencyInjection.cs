using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SosyoBel.Application.Abstractions;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Auditing;
using SosyoBel.Application.FieldTasks;
using SosyoBel.Application.Kps;
using SosyoBel.Application.References;
using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Configuration;
using SosyoBel.Infrastructure.Kps;
using SosyoBel.Infrastructure.Persistence;
using SosyoBel.Infrastructure.Storage;

namespace SosyoBel.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddSosyoBelInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("SosyoBel");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:SosyoBel yapılandırılmalıdır. Gizli değeri appsettings dosyasına yazmayın.");
        }

        services.AddDbContextFactory<SosyoBelDbContext>(options =>
            options.UseSqlServer(
                connectionString,
                sqlServer =>
                {
                    sqlServer.CommandTimeout(30);
                    sqlServer.EnableRetryOnFailure(
                        maxRetryCount: 3,
                        maxRetryDelay: TimeSpan.FromSeconds(5),
                        errorNumbersToAdd: null);
                }));

        services.AddScoped(provider =>
            provider.GetRequiredService<IDbContextFactory<SosyoBelDbContext>>()
                .CreateDbContext());
        services.AddScoped<IMunicipalityIntegrationRepository, MunicipalityIntegrationRepository>();
        services.AddScoped<IApplicationLifecycleService, ApplicationLifecycleService>();
        services.AddScoped<IApplicationPhotoService, ApplicationPhotoService>();
        services.AddScoped<IApplicationPhotoStorage, LocalApplicationPhotoStorage>();
        services.AddScoped<IAssignedFieldTaskQuery, AssignedFieldTaskQuery>();
        services.AddScoped<IApplicationReferenceQuery, ApplicationReferenceQuery>();
        services.AddScoped<IUserWorkItemQuery, UserWorkItemQuery>();
        services.AddScoped<IAuditEventQuery, AuditEventQuery>();
        services.AddSingleton<ISecretResolver, EnvironmentSecretResolver>();
        services.AddOptions<KpsOptions>()
            .Bind(configuration.GetSection(KpsOptions.SectionName));
        // İstemci singleton tutulur; kendi SocketsHttpHandler havuzu DNS
        // yenilemesini yönetir ve hassas query değerlerini framework loglamaz.
        services.AddSingleton<IKpsClient, KpsClient>();
        services.AddScoped<IKpsProfileQuery, KpsProfileQuery>();

        return services;
    }
}
