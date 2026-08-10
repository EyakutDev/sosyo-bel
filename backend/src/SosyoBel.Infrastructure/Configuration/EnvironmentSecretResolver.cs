using SosyoBel.Application.Abstractions;

namespace SosyoBel.Infrastructure.Configuration;

internal sealed class EnvironmentSecretResolver : ISecretResolver
{
    private const string EnvironmentPrefix = "env://";
    private const string VaultPrefix = "vault://";

    public ValueTask<string> ResolveAsync(
        string secretReference,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ArgumentException.ThrowIfNullOrWhiteSpace(secretReference);

        if (secretReference.StartsWith(EnvironmentPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var variableName = secretReference[EnvironmentPrefix.Length..];
            if (string.IsNullOrWhiteSpace(variableName))
            {
                throw new InvalidOperationException("Secret ortam değişkeni adı boş olamaz.");
            }

            var value = Environment.GetEnvironmentVariable(variableName);
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException(
                    $"Secret ortam değişkeni bulunamadı: {variableName}");
            }

            return ValueTask.FromResult(value);
        }

        if (secretReference.StartsWith(VaultPrefix, StringComparison.OrdinalIgnoreCase))
        {
            throw new NotSupportedException(
                "vault:// çözümleyicisi bulut sağlayıcısı seçildikten sonra eklenecektir.");
        }

        throw new InvalidOperationException("Desteklenmeyen secret referansı.");
    }
}
