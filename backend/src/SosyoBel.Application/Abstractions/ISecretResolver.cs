namespace SosyoBel.Application.Abstractions;

/// <summary>
/// Kodun bulut sağlayıcısına bağlanmasını önler; env ve vault uygulamaları aynı
/// sözleşmenin arkasında değiştirilebilir.
/// </summary>
public interface ISecretResolver
{
    ValueTask<string> ResolveAsync(string secretReference, CancellationToken cancellationToken);
}
