using SosyoBel.Application.Abstractions;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.References;

namespace SosyoBel.Api.References;

internal static class ApplicationReferenceEndpoints
{
    public static IEndpointRouteBuilder MapApplicationReferenceEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/application-references", GetAsync)
            .WithTags("Başvuru Referansları")
            .WithSummary("Mobil başvuru formlarının güncel seçeneklerini getirir")
            .WithDescription(
                "Yardım, engel, yakınlık, çalışma, eğitim ve yaşam durumu seçeneklerini; ayrıca " +
                "aktif hane soruları ile seçeneklerini kararlı kod ve kullanıcı etiketi olarak döndürür. " +
                "Şirket dbo tablolarındaki silinmiş kayıtlar gönderilmez. Hane sorularında belediyeye " +
                "özel tanım, aynı kodlu global tanımın önüne geçer.")
            .RequireAuthorization(AuthorizationPolicyNames.Personnel);

        return endpoints;
    }

    private static async Task<IResult> GetAsync(
        ICurrentMunicipality currentMunicipality,
        IApplicationReferenceQuery query,
        CancellationToken cancellationToken)
    {
        var catalog = await query.GetAsync(
            currentMunicipality.RequireMunicipalityId(),
            cancellationToken);
        return Results.Ok(catalog);
    }
}
