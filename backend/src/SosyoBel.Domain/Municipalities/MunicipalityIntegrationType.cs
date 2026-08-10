namespace SosyoBel.Domain.Municipalities;

/// <summary>
/// Belediye verisinin hangi teknik sınır üzerinden alınacağını belirtir.
/// Bu enum sunucu adresi veya sağlayıcı adı içermez; dağıtım ayarları sonradan bağlanır.
/// </summary>
public enum MunicipalityIntegrationType
{
    SqlServer,
    RestApi,
    Csv,
    Demo,
}
