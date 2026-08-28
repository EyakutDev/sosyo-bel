using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace SosyoBel.Api.OpenApi;

/// <summary>
/// Minimal API endpointlerine eklenen açıklama metadatasını Swagger belgesine aktarır.
/// </summary>
internal sealed class EndpointDocumentationOperationFilter : IOperationFilter
{
    private const string CompletedApplicationSubmitPath =
        "api/v1/applications/submit";

    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        var endpointMetadata = context.ApiDescription.ActionDescriptor.EndpointMetadata;

        // Son metadata değeri endpoint üzerinde yapılan en güncel tanımı temsil eder.
        var summary = endpointMetadata
            .OfType<IEndpointSummaryMetadata>()
            .LastOrDefault()
            ?.Summary;
        var description = endpointMetadata
            .OfType<IEndpointDescriptionMetadata>()
            .LastOrDefault()
            ?.Description;

        if (!string.IsNullOrWhiteSpace(summary))
        {
            operation.Summary = summary;
        }

        if (!string.IsNullOrWhiteSpace(description))
        {
            operation.Description = description;
        }

        if (IsCompletedApplicationSubmit(context))
        {
            AddCompletedApplicationSubmitContract(operation);
        }
    }

    private static bool IsCompletedApplicationSubmit(
        OperationFilterContext context) =>
        string.Equals(
            context.ApiDescription.HttpMethod,
            HttpMethods.Post,
            StringComparison.OrdinalIgnoreCase) &&
        string.Equals(
            context.ApiDescription.RelativePath?.TrimStart('/'),
            CompletedApplicationSubmitPath,
            StringComparison.OrdinalIgnoreCase);

    private static void AddCompletedApplicationSubmitContract(
        OpenApiOperation operation)
    {
        // Endpoint formu güvenlik ve dosya akışı nedeniyle HttpRequest üzerinden
        // kendisi okur. Swashbuckle bunu otomatik çıkaramadığı için aynı runtime
        // sözleşmesi yalnız dokümantasyon katmanında açıkça tanımlanır.
        operation.Parameters ??= [];
        if (!operation.Parameters.Any(parameter =>
                parameter.In == ParameterLocation.Header &&
                string.Equals(
                    parameter.Name,
                    "Idempotency-Key",
                    StringComparison.OrdinalIgnoreCase)))
        {
            operation.Parameters.Add(new OpenApiParameter
            {
                Name = "Idempotency-Key",
                In = ParameterLocation.Header,
                Required = true,
                Description =
                    "Aynı gönderimin ikinci başvuru oluşturmasını önleyen 8-100 karakterlik benzersiz istek anahtarı.",
                Schema = new OpenApiSchema
                {
                    Type = JsonSchemaType.String,
                    MinLength = 8,
                    MaxLength = 100,
                },
            });
        }

        operation.RequestBody = new OpenApiRequestBody
        {
            Required = true,
            Description =
                "payload alanı tamamlanmış başvurunun JSON metnidir; photos alanına en fazla 15 fotoğraf eklenebilir.",
            Content = new Dictionary<string, OpenApiMediaType>
            {
                ["multipart/form-data"] = new()
                {
                    Schema = new OpenApiSchema
                    {
                        Type = JsonSchemaType.Object,
                        Required = new HashSet<string>(StringComparer.Ordinal)
                        {
                            "payload",
                        },
                        Properties = new Dictionary<string, IOpenApiSchema>(
                            StringComparer.Ordinal)
                        {
                            ["payload"] = new OpenApiSchema
                            {
                                Type = JsonSchemaType.String,
                                Description =
                                    "Kişi/talep, aile fertleri ve hane cevaplarını içeren JSON metni.",
                            },
                            ["photos"] = new OpenApiSchema
                            {
                                Type = JsonSchemaType.Array,
                                Description =
                                    "İsteğe bağlı JPEG, PNG, HEIC veya HEIF dosyaları; en fazla 15 adet ve dosya başına 10 MB.",
                                Items = new OpenApiSchema
                                {
                                    Type = JsonSchemaType.String,
                                    Format = "binary",
                                },
                            },
                        },
                    },
                },
            },
        };
    }
}
