using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SosyoBel.Application.Applications;
using SosyoBel.Application.FieldTasks;
using SosyoBel.Application.Kps;
using SosyoBel.Application.References;
using SosyoBel.Application.WorkItems;
using SosyoBel.Infrastructure.Kps;
using SosyoBel.Infrastructure.Logging;
using SosyoBel.Infrastructure.Persistence;
using SosyoBel.Infrastructure.Storage;

namespace SosyoBel.Infrastructure;

/// <summary>
/// Application katmanındaki portları SQL, KPS ve dosya depolamasının gerçek
/// uygulamalarına bağlayan Infrastructure composition modülüdür.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddSosyoBelInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Log sağlayıcısı kurulmasa da servislerin teşhis bağlamı çözülebilir.
        services.TryAddScoped<RequestLogContext>();
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

        // Aynı fiziksel şirket veritabanını kullanır; yalnız doğrulanmış dbo
        // tablolarını modelleyen context migration üretmeden izole tutulur.
        services.AddDbContextFactory<CompanyApplicationDbContext>(options =>
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
        services.AddScoped<IApplicationLifecycleService, ApplicationLifecycleService>();
        services.AddScoped<IApplicationPhotoService, ApplicationPhotoService>();
        services.AddScoped<IApplicationPhotoStorage, LocalApplicationPhotoStorage>();
        services.AddScoped<CompanyApplicationPhotoPreparer>();
        services.AddScoped<
            ICompletedApplicationSubmissionService,
            CompletedApplicationSubmissionService>();
        services.AddScoped<
            ISubmittedApplicationDetailQuery,
            SubmittedApplicationDetailQuery>();
        services.AddScoped<
            IUpdateSubmittedApplicationService,
            SubmittedApplicationUpdateService>();
        services.AddScoped<IAssignedFieldTaskQuery, AssignedFieldTaskQuery>();
        services.AddScoped<IApplicationReferenceQuery, ApplicationReferenceQuery>();
        services.AddScoped<IUserWorkItemQuery, UserWorkItemQuery>();
        services.AddOptions<KpsOptions>()
            .Bind(configuration.GetSection(KpsOptions.SectionName));
        // İstemci singleton tutulur; kendi SocketsHttpHandler havuzu DNS
        // yenilemesini yönetir ve hassas query değerlerini framework loglamaz.
        services.AddSingleton<IKpsClient, KpsClient>();
        services.AddScoped<IKpsProfileQuery, KpsProfileQuery>();

        return services;
    }
}
