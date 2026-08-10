using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.WorkItems;

namespace SosyoBel.Infrastructure.Persistence;

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

        // Önce iki meşru kaynak birleştirilir. ROW_NUMBER aynı başvurunun hem
        // personele atanmış görev hem kendi başvurusu olması durumunda görev satırını seçer.
        var rows = await dbContext.Database.SqlQuery<UserWorkItemRow>($"""
            WITH Birlesik AS
            (
                SELECT
                    basvuru.PublicId AS ApplicationPublicId,
                    gorev.PublicId AS TaskPublicId,
                    basvuru.BasvuruNo AS ApplicationNumber,
                    NULLIF(LTRIM(RTRIM(CONCAT(
                        COALESCE(NULLIF(basvuru.BasvuranAd, N''), vatandas.Ad, N''),
                        N' ',
                        COALESCE(NULLIF(basvuru.BasvuranSoyad, N''), vatandas.Soyad, N'')))), N'')
                        AS ApplicantFullName,
                    COALESCE(NULLIF(basvuru.BasvuruAcikAdres, N''), NULLIF(vatandas.AcikAdres, N''))
                        AS Address,
                    CAST(N'ASSIGNED_TASK' AS nvarchar(30)) AS SourceCode,
                    CASE WHEN basvuruDurumu.Kod = N'TAMAMLANDI'
                         THEN basvuruDurumu.Kod ELSE gorev.DurumKodu END AS StatusCode,
                    CAST(CASE WHEN gorev.TamamlanmaTarihiUtc IS NOT NULL
                                   OR gorev.DurumKodu = N'TAMAMLANDI'
                                   OR basvuruDurumu.Kod = N'TAMAMLANDI'
                              THEN 1 ELSE 0 END AS bit) AS IsCompleted,
                    CAST(CASE WHEN basvuruDurumu.Kod = N'TASLAK'
                                   AND basvuru.OlusturanUserId = {userId}
                              THEN 1 ELSE 0 END AS bit) AS IsEditable,
                    COALESCE(NULLIF(gorev.Aciklama, N''), NULLIF(basvuru.TalepAciklamasi, N''))
                        AS Description,
                    COALESCE(gorev.TamamlanmaTarihiUtc, gorev.BaslamaTarihiUtc,
                             gorev.AtanmaTarihiUtc) AS ActivityAtUtc,
                    CAST(1 AS tinyint) AS SourcePriority
                FROM sosyobel.SahaGorevleri AS gorev
                INNER JOIN sosyobel.Basvurular AS basvuru
                    ON basvuru.BelediyeId = gorev.BelediyeId
                   AND basvuru.Id = gorev.BasvuruId
                INNER JOIN sosyobel.BasvuruDurumlari AS basvuruDurumu
                    ON basvuruDurumu.Id = basvuru.BasvuruDurumuId
                LEFT JOIN sosyobel.Vatandaslar AS vatandas
                    ON vatandas.BelediyeId = basvuru.BelediyeId
                   AND vatandas.Id = basvuru.VatandasId
                INNER JOIN sosyobel.KullaniciBelediyeleri AS uyelik
                    ON uyelik.BelediyeId = gorev.BelediyeId
                   AND uyelik.Id = gorev.AtananKullaniciBelediyesiId
                   AND uyelik.UserId = gorev.AtananUserId
                INNER JOIN sosyobel.Belediyeler AS belediye ON belediye.Id = uyelik.BelediyeId
                INNER JOIN dbo.AspNetUsers AS kullanici ON kullanici.Id = uyelik.UserId
                WHERE gorev.BelediyeId = {municipalityId}
                  AND gorev.AtananKullaniciBelediyesiId = {municipalityMembershipId}
                  AND gorev.AtananUserId = {userId}
                  AND uyelik.AktifMi = CAST(1 AS bit)
                  AND uyelik.RolKodu = {RoleCodes.Personnel}
                  AND belediye.AktifMi = CAST(1 AS bit)
                  AND kullanici.AktifMi = CAST(1 AS bit)

                UNION ALL

                SELECT
                    basvuru.PublicId AS ApplicationPublicId,
                    CAST(NULL AS uniqueidentifier) AS TaskPublicId,
                    basvuru.BasvuruNo AS ApplicationNumber,
                    NULLIF(LTRIM(RTRIM(CONCAT(
                        COALESCE(NULLIF(basvuru.BasvuranAd, N''), vatandas.Ad, N''),
                        N' ',
                        COALESCE(NULLIF(basvuru.BasvuranSoyad, N''), vatandas.Soyad, N'')))), N'')
                        AS ApplicantFullName,
                    COALESCE(NULLIF(basvuru.BasvuruAcikAdres, N''), NULLIF(vatandas.AcikAdres, N''))
                        AS Address,
                    CAST(N'OWN_APPLICATION' AS nvarchar(30)) AS SourceCode,
                    basvuruDurumu.Kod AS StatusCode,
                    CAST(CASE WHEN basvuruDurumu.Kod = N'TAMAMLANDI'
                              THEN 1 ELSE 0 END AS bit) AS IsCompleted,
                    CAST(CASE WHEN basvuruDurumu.Kod = N'TASLAK'
                              THEN 1 ELSE 0 END AS bit) AS IsEditable,
                    NULLIF(basvuru.TalepAciklamasi, N'') AS Description,
                    COALESCE(basvuru.GuncellenmeTarihiUtc,
                             basvuru.OlusturulmaTarihiUtc) AS ActivityAtUtc,
                    CAST(2 AS tinyint) AS SourcePriority
                FROM sosyobel.Basvurular AS basvuru
                INNER JOIN sosyobel.BasvuruDurumlari AS basvuruDurumu
                    ON basvuruDurumu.Id = basvuru.BasvuruDurumuId
                LEFT JOIN sosyobel.Vatandaslar AS vatandas
                    ON vatandas.BelediyeId = basvuru.BelediyeId
                   AND vatandas.Id = basvuru.VatandasId
                INNER JOIN sosyobel.KullaniciBelediyeleri AS uyelik
                    ON uyelik.Id = {municipalityMembershipId}
                   AND uyelik.BelediyeId = basvuru.BelediyeId
                   AND uyelik.UserId = basvuru.OlusturanUserId
                INNER JOIN sosyobel.Belediyeler AS belediye ON belediye.Id = uyelik.BelediyeId
                INNER JOIN dbo.AspNetUsers AS kullanici ON kullanici.Id = uyelik.UserId
                WHERE basvuru.BelediyeId = {municipalityId}
                  AND basvuru.OlusturanUserId = {userId}
                  AND uyelik.AktifMi = CAST(1 AS bit)
                  AND uyelik.RolKodu = {RoleCodes.Personnel}
                  AND belediye.AktifMi = CAST(1 AS bit)
                  AND kullanici.AktifMi = CAST(1 AS bit)
            ),
            Tekil AS
            (
                SELECT *, ROW_NUMBER() OVER
                    (PARTITION BY ApplicationPublicId
                     ORDER BY SourcePriority, ActivityAtUtc DESC) AS DedupRowNumber
                FROM Birlesik
            )
            SELECT TOP ({limit})
                ApplicationPublicId, TaskPublicId, ApplicationNumber,
                ApplicantFullName, Address, SourceCode, StatusCode,
                IsCompleted, IsEditable, Description, ActivityAtUtc
            FROM Tekil
            WHERE DedupRowNumber = 1
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
