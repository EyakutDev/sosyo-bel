using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.Kps;

namespace SosyoBel.Api.Kps;

internal static class KpsEndpoints
{
    public static IEndpointRouteBuilder MapKpsEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints
            .MapGroup("/api/v1/kps")
            .WithTags("KPS Sorguları")
            .RequireAuthorization(AuthorizationPolicyNames.Personnel);

        group.MapGet("/profile", GetProfileAsync)
            .WithSummary("KPS kimlik ve adres profilini getirir")
            .WithDescription(
                "T.C. kimlik numarası ve doğum tarihiyle kurumun KPS kimlik ve adres servislerine " +
                "yalnız GET isteği gönderir. Personelin aktif KPS_SORGULA yetkisi her istekte " +
                "veritabanından doğrulanır; yetki yoksa kurum KPS servisine istek çıkmaz.")
            .Produces<KpsProfile>(StatusCodes.Status200OK)
            .ProducesValidationProblem()
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status422UnprocessableEntity)
            .ProducesProblem(StatusCodes.Status502BadGateway)
            .ProducesProblem(StatusCodes.Status503ServiceUnavailable);

        return endpoints;
    }

    private static async Task<IResult> GetProfileAsync(
        [FromQuery(Name = "tcKimlikNo")] string? identityNumber,
        [FromQuery(Name = "dogumYil")] int? birthYear,
        [FromQuery(Name = "dogumAy")] int? birthMonth,
        [FromQuery(Name = "dogumGun")] int? birthDay,
        HttpContext httpContext,
        IKpsProfileQuery query,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        var criteria = ReadCriteria(
            identityNumber,
            birthYear,
            birthMonth,
            birthDay,
            errors);
        var actor = ReadActor(httpContext);
        if (actor is null)
        {
            // Personel politikası normalde bu durumu daha önce durdurur. Claim kapsamı
            // bozuk bir tokenla KPS'ye çıkılmaması için endpointte de kapalı davranılır.
            return Results.Forbid();
        }
        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await query.GetProfileAsync(actor, criteria!, cancellationToken);
        return result.Status switch
        {
            KpsProfileQueryStatus.Succeeded => Results.Ok(result.Value),
            KpsProfileQueryStatus.InvalidInput => Results.ValidationProblem(
                result.Errors ?? new Dictionary<string, string[]>
                {
                    ["request"] = [result.Detail ?? "KPS sorgu bilgileri doğrulanamadı."],
                }),
            KpsProfileQueryStatus.AccessDenied => Problem(
                StatusCodes.Status403Forbidden,
                result.Code ?? "kps_permission_required",
                result.Detail ?? "KPS sorgulama yetkisi bulunmuyor."),
            KpsProfileQueryStatus.InvalidIdentityNumber => Problem(
                StatusCodes.Status400BadRequest,
                result.Code ?? "kps_invalid_identity_number",
                result.Detail ?? "Geçerli bir T.C. kimlik numarası giriniz."),
            KpsProfileQueryStatus.BirthDateMismatch => Problem(
                StatusCodes.Status422UnprocessableEntity,
                result.Code ?? "kps_identity_birth_date_mismatch",
                result.Detail ?? "T.C. kimlik numarası ile doğum tarihi eşleşmiyor."),
            KpsProfileQueryStatus.AddressOutsideServiceArea => Problem(
                StatusCodes.Status422UnprocessableEntity,
                result.Code ?? "kps_address_outside_service_area",
                result.Detail ?? "Adres kurumun hizmet alanı dışında."),
            KpsProfileQueryStatus.UpstreamInvalidRequest => Problem(
                StatusCodes.Status400BadRequest,
                result.Code ?? "kps_invalid_request",
                result.Detail ?? "KPS sorgu bilgileri eksik veya geçersiz."),
            KpsProfileQueryStatus.UpstreamUnavailable => Problem(
                StatusCodes.Status503ServiceUnavailable,
                result.Code ?? "kps_unavailable",
                result.Detail ?? "KPS servisine şu anda ulaşılamıyor."),
            KpsProfileQueryStatus.InvalidUpstreamResponse => Problem(
                StatusCodes.Status502BadGateway,
                result.Code ?? "kps_invalid_response",
                result.Detail ?? "KPS servisinden beklenen biçimde cevap alınamadı."),
            _ => Problem(
                StatusCodes.Status500InternalServerError,
                "kps_query_error",
                "KPS sorgusu tamamlanamadı."),
        };
    }

    private static KpsLookupCriteria? ReadCriteria(
        string? identityNumber,
        int? birthYear,
        int? birthMonth,
        int? birthDay,
        IDictionary<string, string[]> errors)
    {
        var normalizedIdentityNumber = identityNumber?.Trim() ?? string.Empty;
        if (normalizedIdentityNumber.Length != 11 ||
            normalizedIdentityNumber.Any(value => !char.IsAsciiDigit(value)))
        {
            errors["tcKimlikNo"] = ["T.C. kimlik numarası 11 rakam olmalıdır."];
        }

        if (birthYear is null || birthMonth is null || birthDay is null)
        {
            errors["dogumTarihi"] = ["Doğum yılı, ayı ve günü zorunludur."];
            return null;
        }

        try
        {
            return new KpsLookupCriteria(
                normalizedIdentityNumber,
                new DateOnly(birthYear.Value, birthMonth.Value, birthDay.Value));
        }
        catch (ArgumentOutOfRangeException)
        {
            errors["dogumTarihi"] = ["Geçerli bir doğum tarihi girilmelidir."];
            return null;
        }
    }

    private static KpsProfileActor? ReadActor(HttpContext context)
    {
        var userId = context.User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var municipalityIdValue = context.User.FindFirstValue(CustomClaimTypes.MunicipalityId);
        var membershipIdValue = context.User.FindFirstValue(
            CustomClaimTypes.MunicipalityMembershipId);

        if (string.IsNullOrWhiteSpace(userId) ||
            !int.TryParse(
                municipalityIdValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var municipalityId) || municipalityId <= 0 ||
            !long.TryParse(
                membershipIdValue,
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out var membershipId) || membershipId <= 0)
        {
            return null;
        }

        return new KpsProfileActor(userId, membershipId, municipalityId);
    }

    private static IResult Problem(int status, string code, string title) =>
        Results.Problem(
            statusCode: status,
            title: title,
            extensions: new Dictionary<string, object?> { ["code"] = code });
}
