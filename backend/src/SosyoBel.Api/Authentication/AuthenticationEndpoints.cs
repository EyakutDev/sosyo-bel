using System.IdentityModel.Tokens.Jwt;
using System.Net.Mail;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using SosyoBel.Application.Authentication;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Api.Authentication;

internal static class AuthenticationEndpoints
{
    public static IEndpointRouteBuilder MapAuthenticationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/auth").WithTags("Kimlik Doğrulama");

        group.MapPost("/login", LoginAsync)
            .WithSummary("Kullanıcı oturumu açar")
            .WithDescription(
                "E-posta ve şifreyi doğrular; kullanıcı birden fazla belediyeye bağlıysa " +
                "belediye seçimi ister. Başarılı sonuç erişim ve yenileme anahtarlarını içerir. " +
                "İstemci cihaz kimliğini isteğe bağlı X-Device-Id başlığında gönderebilir.")
            .AllowAnonymous()
            .RequireRateLimiting(AuthenticationRateLimiting.PolicyName);
        group.MapPost("/refresh", RefreshAsync)
            .WithSummary("Oturum anahtarlarını yeniler")
            .WithDescription(
                "Geçerli refresh token ile yeni erişim ve refresh token üretir. Güvenlik için " +
                "eski refresh token tekrar kullanılamaz; varsa X-Device-Id değeri oturumla eşleştirilir.")
            .AllowAnonymous()
            .RequireRateLimiting(AuthenticationRateLimiting.PolicyName);
        group.MapPost("/logout", LogoutAsync)
            .WithSummary("Kullanıcı oturumunu kapatır")
            .WithDescription(
                "Gönderilen refresh tokenı iptal eder. Erişim tokenının süresi dolmuş olsa bile " +
                "oturum kapatılabilmesi için bu uç anonim çağrı kabul eder.")
            .AllowAnonymous()
            .RequireRateLimiting(AuthenticationRateLimiting.PolicyName);
        group.MapGet("/me", CurrentUser)
            .WithSummary("Aktif kullanıcı bilgilerini getirir")
            .WithDescription(
                "Bearer erişim tokenındaki kullanıcı, belediye üyeliği ve rol bilgilerini döndürür. " +
                "İstemci aktif oturumun kapsamını bu uçla doğrulayabilir.");

        return endpoints;
    }

    private static async Task<IResult> LoginAsync(
        LoginRequest request,
        HttpContext httpContext,
        IAuthenticationService authenticationService,
        CancellationToken cancellationToken)
    {
        var errors = ValidateLogin(request);
        var deviceId = ReadDeviceId(httpContext, errors);
        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await authenticationService.LoginAsync(
            new LoginInput(
                request.Email,
                request.Password,
                request.MunicipalityCode,
                deviceId,
                ReadRemoteIp(httpContext)),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> RefreshAsync(
        RefreshRequest request,
        HttpContext httpContext,
        IAuthenticationService authenticationService,
        CancellationToken cancellationToken)
    {
        var errors = ValidateRefresh(request);
        var deviceId = ReadDeviceId(httpContext, errors);
        if (errors.Count > 0)
        {
            return Results.ValidationProblem(errors);
        }

        var result = await authenticationService.RefreshAsync(
            new RefreshInput(
                request.RefreshToken,
                request.MunicipalityCode,
                deviceId,
                ReadRemoteIp(httpContext)),
            cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> LogoutAsync(
        LogoutRequest request,
        HttpContext httpContext,
        IAuthenticationService authenticationService,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken) || request.RefreshToken.Length > 500)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["refreshToken"] = ["Geçerli bir refresh token gönderilmelidir."],
            });
        }

        await authenticationService.LogoutAsync(
            new LogoutInput(request.RefreshToken, ReadRemoteIp(httpContext)),
            cancellationToken);
        return Results.NoContent();
    }

    private static IResult CurrentUser(ClaimsPrincipal principal)
    {
        return Results.Ok(new
        {
            userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub),
            email = principal.FindFirstValue(JwtRegisteredClaimNames.Email),
            displayName = principal.FindFirstValue(JwtRegisteredClaimNames.Name),
            municipalityId = principal.FindFirstValue(CustomClaimTypes.MunicipalityId),
            municipalityCode = principal.FindFirstValue(CustomClaimTypes.MunicipalityCode),
            municipalityMembershipId = principal.FindFirstValue(
                CustomClaimTypes.MunicipalityMembershipId),
            roles = principal.FindAll("role").Select(claim => claim.Value).ToArray(),
        });
    }

    private static IResult ToHttpResult(AuthenticationResult result) => result.Status switch
    {
        AuthenticationStatus.Succeeded => Results.Ok(result.Session),
        AuthenticationStatus.InvalidCredentials => Results.Problem(
            statusCode: StatusCodes.Status401Unauthorized,
            title: "E-posta veya şifre hatalı.",
            extensions: new Dictionary<string, object?> { ["code"] = "invalid_credentials" }),
        AuthenticationStatus.LockedOut => Results.Problem(
            statusCode: StatusCodes.Status423Locked,
            title: "Giriş geçici olarak kullanılamıyor. Daha sonra tekrar deneyin.",
            extensions: new Dictionary<string, object?> { ["code"] = "account_locked" }),
        AuthenticationStatus.AccessDenied => Results.Problem(
            statusCode: StatusCodes.Status403Forbidden,
            title: "Bu hesap için aktif belediye erişimi bulunamadı.",
            extensions: new Dictionary<string, object?> { ["code"] = "municipality_access_denied" }),
        AuthenticationStatus.MunicipalitySelectionRequired => Results.Conflict(new
        {
            code = "municipality_selection_required",
            municipalities = result.Municipalities,
        }),
        AuthenticationStatus.RefreshTokenReuseDetected => Results.Problem(
            statusCode: StatusCodes.Status401Unauthorized,
            title: "Oturum güvenlik nedeniyle kapatıldı. Tekrar giriş yapın.",
            extensions: new Dictionary<string, object?> { ["code"] = "refresh_token_reused" }),
        _ => Results.Problem(
            statusCode: StatusCodes.Status401Unauthorized,
            title: "Oturum geçersiz veya süresi dolmuş.",
            extensions: new Dictionary<string, object?> { ["code"] = "invalid_refresh_token" }),
    };

    private static Dictionary<string, string[]> ValidateLogin(LoginRequest request)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(request.Email) || request.Email.Length > 256 ||
            !MailAddress.TryCreate(request.Email.Trim(), out _))
        {
            errors["email"] = ["Geçerli bir e-posta adresi girilmelidir."];
        }

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length > 256)
        {
            errors["password"] = ["Şifre boş olamaz."];
        }

        ValidateMunicipalityCode(request.MunicipalityCode, errors);
        return errors;
    }

    private static Dictionary<string, string[]> ValidateRefresh(RefreshRequest request)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(request.RefreshToken) || request.RefreshToken.Length > 500)
        {
            errors["refreshToken"] = ["Geçerli bir refresh token gönderilmelidir."];
        }

        ValidateMunicipalityCode(request.MunicipalityCode, errors);
        return errors;
    }

    private static void ValidateMunicipalityCode(
        string? municipalityCode,
        IDictionary<string, string[]> errors)
    {
        if (municipalityCode?.Length > 50)
        {
            errors["municipalityCode"] = ["Belediye kodu en fazla 50 karakter olabilir."];
        }
    }

    private static string? ReadDeviceId(
        HttpContext httpContext,
        IDictionary<string, string[]> errors)
    {
        var deviceId = httpContext.Request.Headers["X-Device-Id"].FirstOrDefault();
        if (deviceId?.Length > 200)
        {
            errors["X-Device-Id"] = ["Cihaz kimliği en fazla 200 karakter olabilir."];
            return null;
        }

        return string.IsNullOrWhiteSpace(deviceId) ? null : deviceId.Trim();
    }

    private static string? ReadRemoteIp(HttpContext context) =>
        context.Connection.RemoteIpAddress?.ToString();

    private sealed record LoginRequest(
        string Email,
        string Password,
        string? MunicipalityCode);

    private sealed record RefreshRequest(string RefreshToken, string? MunicipalityCode);

    private sealed record LogoutRequest(string RefreshToken);
}
