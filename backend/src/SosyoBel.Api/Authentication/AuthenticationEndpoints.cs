using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using SosyoBel.Application.Authentication;

namespace SosyoBel.Api.Authentication;

/// <summary>
/// Kimlik doğrulamanın HTTP sınırıdır. İstek biçimini ve başlıkları doğrular,
/// oturum yaşam döngüsünü IAuthenticationService'e devreder ve sonucu HTTP'ye çevirir.
/// </summary>
internal static class AuthenticationEndpoints
{
    public static IEndpointRouteBuilder MapAuthenticationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/auth").WithTags("Kimlik Doğrulama");

        group.MapPost("/login", LoginAsync)
            .WithSummary("Kullanıcı oturumu açar")
            .WithDescription(
                "Mevcut ASP.NET Identity kullanıcı adı ve şifresini doğrular. Admin, Kurul veya " +
                "Personel rolüne sahip hesaplara erişim ve yenileme anahtarlarını döndürür. " +
                "İstemci cihaz kimliğini isteğe bağlı X-Device-Id başlığında gönderebilir.")
            .Produces<AuthenticationSession>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status423Locked)
            .AllowAnonymous()
            .RequireRateLimiting(AuthenticationRateLimiting.PolicyName);
        group.MapPost("/refresh", RefreshAsync)
            .WithSummary("Oturum anahtarlarını yeniler")
            .WithDescription(
                "Geçerli refresh token ile yeni erişim ve refresh token üretir. Güvenlik için " +
                "eski refresh token tekrar kullanılamaz; varsa X-Device-Id değeri oturumla eşleştirilir.")
            .Produces<AuthenticationSession>(StatusCodes.Status200OK)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .AllowAnonymous()
            .RequireRateLimiting(AuthenticationRateLimiting.PolicyName);
        group.MapPost("/logout", LogoutAsync)
            .WithSummary("Kullanıcı oturumunu kapatır")
            .WithDescription(
                "Gönderilen refresh tokenı iptal eder. Erişim tokenının süresi dolmuş olsa bile " +
                "oturum kapatılabilmesi için bu uç anonim çağrı kabul eder.")
            .Produces(StatusCodes.Status204NoContent)
            .ProducesValidationProblem(StatusCodes.Status400BadRequest)
            .AllowAnonymous()
            .RequireRateLimiting(AuthenticationRateLimiting.PolicyName);
        group.MapGet("/me", CurrentUser)
            .WithSummary("Aktif kullanıcı bilgilerini getirir")
            .WithDescription(
                "Bearer erişim tokenındaki mevcut Identity kullanıcısını ve rollerini döndürür. " +
                "İstemci aktif oturumu bu uçla doğrulayabilir.")
            .Produces(StatusCodes.Status200OK)
            .ProducesProblem(StatusCodes.Status401Unauthorized);

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
                request.Username,
                request.Password,
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
        if (string.IsNullOrWhiteSpace(request.RefreshToken) || request.RefreshToken.Length > 1024)
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
            username = principal.FindFirstValue(JwtRegisteredClaimNames.PreferredUsername),
            email = principal.FindFirstValue(JwtRegisteredClaimNames.Email),
            displayName = principal.FindFirstValue(JwtRegisteredClaimNames.Name),
            roles = principal.FindAll("role").Select(claim => claim.Value).ToArray(),
        });
    }

    private static IResult ToHttpResult(AuthenticationResult result) => result.Status switch
    {
        AuthenticationStatus.Succeeded => Results.Ok(result.Session),
        AuthenticationStatus.InvalidCredentials => Results.Problem(
            statusCode: StatusCodes.Status401Unauthorized,
            title: "Kullanıcı adı veya şifre hatalı.",
            extensions: new Dictionary<string, object?> { ["code"] = "invalid_credentials" }),
        AuthenticationStatus.LockedOut => Results.Problem(
            statusCode: StatusCodes.Status423Locked,
            title: "Giriş geçici olarak kullanılamıyor. Daha sonra tekrar deneyin.",
            extensions: new Dictionary<string, object?> { ["code"] = "account_locked" }),
        AuthenticationStatus.AccessDenied => Results.Problem(
            statusCode: StatusCodes.Status403Forbidden,
            title: "Bu hesabın mobil uygulama erişimi bulunmuyor.",
            extensions: new Dictionary<string, object?> { ["code"] = "mobile_access_denied" }),
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
        if (string.IsNullOrWhiteSpace(request.Username) || request.Username.Length > 256)
        {
            errors["username"] = ["Kullanıcı adı boş olamaz ve en fazla 256 karakter olabilir."];
        }

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length > 256)
        {
            errors["password"] = ["Şifre boş olamaz."];
        }

        return errors;
    }

    private static Dictionary<string, string[]> ValidateRefresh(RefreshRequest request)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(request.RefreshToken) || request.RefreshToken.Length > 1024)
        {
            errors["refreshToken"] = ["Geçerli bir refresh token gönderilmelidir."];
        }

        return errors;
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
        string Username,
        string Password);

    private sealed record RefreshRequest(string RefreshToken);

    private sealed record LogoutRequest(string RefreshToken);
}
