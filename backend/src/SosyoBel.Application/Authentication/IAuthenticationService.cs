namespace SosyoBel.Application.Authentication;

public interface IAuthenticationService
{
    Task<AuthenticationResult> LoginAsync(
        LoginInput input,
        CancellationToken cancellationToken);

    Task<AuthenticationResult> RefreshAsync(
        RefreshInput input,
        CancellationToken cancellationToken);

    Task LogoutAsync(LogoutInput input, CancellationToken cancellationToken);
}
