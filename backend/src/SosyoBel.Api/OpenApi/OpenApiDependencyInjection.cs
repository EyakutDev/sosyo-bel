using Microsoft.OpenApi;

namespace SosyoBel.Api.OpenApi;

internal static class OpenApiDependencyInjection
{
    private const string DocumentName = "v1";

    public static IServiceCollection AddSosyoBelOpenApi(this IServiceCollection services)
    {
        // Minimal API uçlarının Swagger belgesinde bulunabilmesi için API Explorer kaydedilir.
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc(DocumentName, new OpenApiInfo
            {
                Title = "Sosyo-Bel API",
                Version = DocumentName,
                Description = "CATS Yazılım Sosyo-Bel mobil uygulaması servisleri.",
            });

            // .NET endpoint özetlerini ve açıklamalarını üretilen Swagger operasyonlarına taşır.
            options.OperationFilter<EndpointDocumentationOperationFilter>();

            // Swagger ekranındaki Authorize alanı, girişten alınan JWT ile korumalı uçları test eder.
            options.AddSecurityDefinition("bearer", new OpenApiSecurityScheme
            {
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                Description = "Yalnızca JWT erişim anahtarını girin; 'Bearer' öneki otomatik eklenir.",
            });
            options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("bearer", document)] = [],
            });
        });

        return services;
    }

    public static WebApplication MapSosyoBelOpenApi(this WebApplication app)
    {
        // Üretimde yanlışlıkla API kataloğu açılmasın; IIS test ortamında OpenApi__Enabled=true verilebilir.
        if (!app.Configuration.GetValue<bool>("OpenApi:Enabled"))
        {
            app.Logger.LogInformation("Swagger/OpenAPI uçları yapılandırma gereği kapalı.");
            return app;
        }

        app.Logger.LogInformation("Swagger/OpenAPI uçları /swagger altında etkin.");

        // Endpoint tabanlı kayıt sayesinde fallback authorization politikası açıkça aşılır.
        app.MapSwagger().AllowAnonymous();
        app.MapSwaggerUI(
                "swagger",
                options =>
                {
                    // Göreli adres IIS sanal dizini veya reverse proxy altında da doğru yolu kullanır.
                    options.SwaggerEndpoint("v1/swagger.json", "Sosyo-Bel API v1");
                    options.DocumentTitle = "Sosyo-Bel API";
                })
            .AllowAnonymous();

        return app;
    }
}
