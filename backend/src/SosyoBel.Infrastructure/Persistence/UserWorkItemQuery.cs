using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.WorkItems;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Personelin kendi oluşturduğu başvuruları şirketin dbo iş kaydı ile Sosyo-Bel
/// metadata kaydını birleştirerek mobil iş listesi modeline dönüştürür.
/// </summary>
internal sealed class UserWorkItemQuery(
    SosyoBelDbContext dbContext) : IUserWorkItemQuery
{
    public async Task<IReadOnlyCollection<UserWorkItemSummary>> GetMineAsync(
        string userId,
        int municipalityId,
        long municipalityMembershipId,
        int limit,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (municipalityId <= 0 || municipalityMembershipId <= 0)
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        if (limit is < 1 or > 100)
            throw new ArgumentOutOfRangeException(nameof(limit));

        // Şirketin başvuru iş verisi dbo.Basvurular'da, mobil kimlik ve audit
        // alanları ise bire bir sosyobel uzantısında tutulur. Eski, bağımsız
        // sosyobel.Basvurular modeline dönülmez.
        //
        // Şirketin görev atama tablosu henüz kesin eşlenmediği için bu sorgu
        // yalnız personelin kendi oluşturduğu başvuruları listeler. Doğrulanmamış
        // bir SahaGorevleri tablosu varsaymak yerine görev kaynağı daha sonra
        // aynı DTO'ya UNION edilecektir.
        var rows = await dbContext.Database.SqlQuery<UserWorkItemRow>($"""
            SELECT TOP ({limit})
                metadata.PublicId AS ApplicationPublicId,
                CAST(NULL AS uniqueidentifier) AS TaskPublicId,
                COALESCE(
                    NULLIF(metadata.BasvuruNo, N''),
                    CONCAT(N'#', CONVERT(nvarchar(20), application.Id)))
                    AS ApplicationNumber,
                NULLIF(LTRIM(RTRIM(CONCAT(
                    COALESCE(NULLIF(application.BasvuranAd, N''), N''),
                    N' ',
                    COALESCE(NULLIF(application.BasvuranSoyad, N''), N'')))), N'')
                    AS ApplicantFullName,
                NULLIF(application.BasvuruAcikAdres, N'') AS Address,
                CAST(N'OWN_APPLICATION' AS nvarchar(30)) AS SourceCode,
                statusCode.Kod AS StatusCode,
                CAST(CASE WHEN statusCode.Kod = N'TAMAMLANDI'
                          THEN 1 ELSE 0 END AS bit) AS IsCompleted,
                CAST(CASE WHEN statusCode.Kod = N'TASLAK'
                          THEN 1 ELSE 0 END AS bit) AS IsEditable,
                NULLIF(application.TalepAciklamasi, N'') AS Description,
                COALESCE(
                    metadata.GuncellenmeTarihiUtc,
                    metadata.KurulaGonderilmeTarihiUtc,
                    application.BasvuruTarihi,
                    metadata.OlusturulmaTarihiUtc) AS ActivityAtUtc
            FROM dbo.Basvurular AS application
            INNER JOIN sosyobel.BasvuruUygulamaBilgileri AS metadata
                ON metadata.BasvuruId = application.Id
            INNER JOIN sosyobel.ReferansKodlari AS statusCode
                ON statusCode.ReferansTuruKodu = N'BASVURU_DURUMU'
               AND statusCode.KaynakId = application.BasvuruDurumuId
            INNER JOIN sosyobel.KullaniciBelediyeleri AS membership
                ON membership.Id = {municipalityMembershipId}
               AND membership.BelediyeId = {municipalityId}
               AND membership.UserId = application.OlusturanUserId
            INNER JOIN sosyobel.Belediyeler AS municipality
                ON municipality.Id = membership.BelediyeId
            INNER JOIN sosyobel.KullaniciUygulamaBilgileri AS userInfo
                ON userInfo.UserId = membership.UserId
            WHERE application.OlusturanUserId = {userId}
              AND membership.UserId = {userId}
              AND membership.AktifMi = CAST(1 AS bit)
              AND membership.RolKodu = {RoleCodes.Personnel}
              AND municipality.AktifMi = CAST(1 AS bit)
              AND userInfo.AktifMi = CAST(1 AS bit)
            ORDER BY IsCompleted, ActivityAtUtc DESC
            """)
            .ToArrayAsync(cancellationToken);

        return rows.Select(row => new UserWorkItemSummary(
            row.ApplicationPublicId,
            row.TaskPublicId,
            row.ApplicationNumber,
            row.ApplicantFullName,
            row.Address,
            row.SourceCode,
            row.StatusCode,
            row.IsCompleted,
            row.IsEditable,
            row.Description,
            row.ActivityAtUtc)).ToArray();
    }

    private sealed class UserWorkItemRow
    {
        public Guid ApplicationPublicId { get; init; }
        public Guid? TaskPublicId { get; init; }
        public string ApplicationNumber { get; init; } = string.Empty;
        public string? ApplicantFullName { get; init; }
        public string? Address { get; init; }
        public string SourceCode { get; init; } = string.Empty;
        public string StatusCode { get; init; } = string.Empty;
        public bool IsCompleted { get; init; }
        public bool IsEditable { get; init; }
        public string? Description { get; init; }
        public DateTime ActivityAtUtc { get; init; }
    }
}
