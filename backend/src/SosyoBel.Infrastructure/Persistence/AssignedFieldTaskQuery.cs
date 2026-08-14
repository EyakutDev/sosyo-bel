using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Authorization;
using SosyoBel.Application.FieldTasks;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Atanmış saha görevlerini yalnız tokenla eşleşen aktif belediye ve personel
/// üyeliği kapsamında okur; kullanıcı kimliğini tek başına yeterli kabul etmez.
/// </summary>
internal sealed class AssignedFieldTaskQuery(
    SosyoBelDbContext dbContext) : IAssignedFieldTaskQuery
{
    public async Task<IReadOnlyCollection<AssignedFieldTaskSummary>> GetAssignedAsync(
        string userId,
        int municipalityId,
        long municipalityMembershipId,
        int limit,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (municipalityId <= 0 || municipalityMembershipId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        }

        if (limit is < 1 or > 100)
        {
            throw new ArgumentOutOfRangeException(nameof(limit));
        }

        // UserId tek başına yeterli değildir. Aynı sorgu; token'daki belediye ve
        // üyelik kimliğini, aktif PERSONEL üyeliğini ve görev atamasını eşleştirir.
        var rows = await dbContext.Database.SqlQuery<AssignedFieldTaskRow>($"""
            SELECT TOP ({limit})
                gorev.PublicId AS TaskPublicId,
                basvuru.PublicId AS ApplicationPublicId,
                basvuru.BasvuruNo AS ApplicationNumber,
                LTRIM(RTRIM(CONCAT(
                    COALESCE(NULLIF(basvuru.BasvuranAd, N''), vatandas.Ad, N''),
                    N' ',
                    COALESCE(NULLIF(basvuru.BasvuranSoyad, N''), vatandas.Soyad, N''))))
                    AS ApplicantFullName,
                COALESCE(
                    NULLIF(basvuru.BasvuruAcikAdres, N''),
                    NULLIF(vatandas.AcikAdres, N'')) AS Address,
                gorev.DurumKodu AS StatusCode,
                gorev.Aciklama AS Description,
                gorev.AtanmaTarihiUtc AS AssignedAtUtc,
                gorev.BaslamaTarihiUtc AS StartedAtUtc,
                gorev.TamamlanmaTarihiUtc AS CompletedAtUtc
            FROM sosyobel.SahaGorevleri AS gorev
            INNER JOIN sosyobel.Basvurular AS basvuru
                ON basvuru.BelediyeId = gorev.BelediyeId
               AND basvuru.Id = gorev.BasvuruId
            LEFT JOIN sosyobel.Vatandaslar AS vatandas
                ON vatandas.BelediyeId = basvuru.BelediyeId
               AND vatandas.Id = basvuru.VatandasId
            INNER JOIN sosyobel.KullaniciBelediyeleri AS uyelik
                ON uyelik.BelediyeId = gorev.BelediyeId
               AND uyelik.Id = gorev.AtananKullaniciBelediyesiId
               AND uyelik.UserId = gorev.AtananUserId
            INNER JOIN sosyobel.Belediyeler AS belediye
                ON belediye.Id = uyelik.BelediyeId
            INNER JOIN dbo.AspNetUsers AS kullanici
                ON kullanici.Id = uyelik.UserId
            WHERE gorev.BelediyeId = {municipalityId}
              AND gorev.AtananKullaniciBelediyesiId = {municipalityMembershipId}
              AND gorev.AtananUserId = {userId}
              AND uyelik.AktifMi = CAST(1 AS bit)
              AND uyelik.RolKodu = {RoleCodes.Personnel}
              AND belediye.AktifMi = CAST(1 AS bit)
              AND kullanici.AktifMi = CAST(1 AS bit)
            ORDER BY gorev.AtanmaTarihiUtc DESC
            """)
            .ToArrayAsync(cancellationToken);

        return rows
            .Select(row => new AssignedFieldTaskSummary(
                row.TaskPublicId,
                row.ApplicationPublicId,
                row.ApplicationNumber,
                row.ApplicantFullName,
                row.Address,
                row.StatusCode,
                row.Description,
                row.AssignedAtUtc,
                row.StartedAtUtc,
                row.CompletedAtUtc))
            .ToArray();
    }

    private sealed class AssignedFieldTaskRow
    {
        public Guid TaskPublicId { get; init; }

        public Guid ApplicationPublicId { get; init; }

        public string ApplicationNumber { get; init; } = string.Empty;

        public string ApplicantFullName { get; init; } = string.Empty;

        public string? Address { get; init; }

        public string StatusCode { get; init; } = string.Empty;

        public string? Description { get; init; }

        public DateTime AssignedAtUtc { get; init; }

        public DateTime? StartedAtUtc { get; init; }

        public DateTime? CompletedAtUtc { get; init; }
    }
}
