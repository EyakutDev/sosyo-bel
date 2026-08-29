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
                "Yardım türlerinde Sil alanı filtrelenmez; diğer dbo seçeneklerinde yalnız aktif kayıtlar " +
                "gönderilir. Hane soruları tek belediyeye " +
                "ait etkin katalogdan okunur.")
            .RequireAuthorization(AuthorizationPolicyNames.MobileFieldOperations);

        return endpoints;
    }

    private static async Task<IResult> GetAsync(
        IApplicationReferenceQuery query,
        CancellationToken cancellationToken)
    {
        var catalog = await query.GetAsync(cancellationToken);
        return Results.Ok(catalog);
    }
}
