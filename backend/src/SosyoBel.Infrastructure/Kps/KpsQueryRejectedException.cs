namespace SosyoBel.Infrastructure.Kps;

/// <summary>
/// KPS'nin teknik olarak okunabilen fakat iş kuralı nedeniyle başarısız olan
/// cevabını sınıflandırır. Ham kurum mesajı yerine yalnızca bilinen neden taşınır.
/// </summary>
internal sealed class KpsQueryRejectedException(KpsQueryRejectionReason reason)
    : Exception("KPS sorgusu kurum servisi tarafından reddedildi.")
{
    public KpsQueryRejectionReason Reason { get; } = reason;
}

internal enum KpsQueryRejectionReason
{
    InvalidIdentityNumber,
    BirthDateMismatch,
    AddressOutsideServiceArea,
}
