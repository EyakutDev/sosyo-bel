namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// KPS cevabı beklenen başarılı sözleşmeye uymadığında oluşur. Mesajlara ham
/// JSON, T.C. kimlik numarası veya adres eklenmez.
/// </summary>
internal sealed class KpsResponseContractException(string code, string message)
    : Exception(message)
{
    public string Code { get; } = code;
}
