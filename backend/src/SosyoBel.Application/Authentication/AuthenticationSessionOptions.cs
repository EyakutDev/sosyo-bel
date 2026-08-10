namespace SosyoBel.Application.Authentication;

public sealed class AuthenticationSessionOptions
{
    public const string SectionName = "Authentication:Session";

    public int RefreshTokenDays { get; init; } = 30;
}
