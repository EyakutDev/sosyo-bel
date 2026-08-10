using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace SosyoBel.Api.OpenApi;

/// <summary>
/// Minimal API endpointlerine eklenen açıklama metadatasını Swagger belgesine aktarır.
/// </summary>
internal sealed class EndpointDocumentationOperationFilter : IOperationFilter
{
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
    }
}
