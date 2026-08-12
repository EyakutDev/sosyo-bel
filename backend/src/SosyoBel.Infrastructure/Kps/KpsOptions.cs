namespace SosyoBel.Infrastructure.Kps;

internal sealed class KpsOptions
{
    public const string SectionName = "Kps";

    public string BaseUrl { get; init; } = string.Empty;

    public int TimeoutSeconds { get; init; } = 30;
}
