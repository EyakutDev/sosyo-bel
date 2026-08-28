using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.FieldTasks;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Atanmış saha görevlerini şirketin mevcut dbo.SahaAktiviteleri tablosundan okur.
/// Personel eşlemesi, doğrulanmış JWT'deki dbo.AspNetUsers.Id ile yapılır.
/// </summary>
internal sealed class AssignedFieldTaskQuery(
    SosyoBelDbContext dbContext) : IAssignedFieldTaskQuery
{
    public async Task<IReadOnlyCollection<AssignedFieldTaskSummary>> GetAssignedAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (limit is < 1 or > 100)
        {
            throw new ArgumentOutOfRangeException(nameof(limit));
        }

        // SahaAktiviteleri.PersonelId şirket şemasında doğrudan AspNetUsers.Id'ye
        // foreign key ile bağlıdır; ayrıca belediye veya üyelik tablosu yoktur.
        var rows = await dbContext.Database.SqlQuery<AssignedFieldTaskRow>($"""
            SELECT TOP ({limit})
                gorev.Id AS TaskId,
                gorev.VatandasId AS CitizenId,
                LTRIM(RTRIM(CONCAT(
                    COALESCE(vatandas.Ad, N''),
                    N' ',
                    COALESCE(vatandas.Soyad, N''))))
                    AS ApplicantFullName,
                NULLIF(vatandas.AcikAdres, N'') AS Address,
                gorev.Durum AS CompanyStatus,
                NULLIF(gorev.Aciklama, N'') AS Description,
                gorev.OlusturulmaTarihi AS ActivityAtUtc
            FROM dbo.SahaAktiviteleri AS gorev
            INNER JOIN dbo.Vatandaslar AS vatandas
                ON vatandas.Id = gorev.VatandasId
            WHERE gorev.PersonelId = {userId}
            ORDER BY gorev.OlusturulmaTarihi DESC, gorev.Id DESC
            """)
            .ToArrayAsync(cancellationToken);

        return rows
            .Select(row =>
            {
                var statusCode = CompanyWorkflowStatusMapper.MapFieldTask(
                    row.CompanyStatus);
                return new AssignedFieldTaskSummary(
                    row.TaskId,
                    row.CitizenId,
                    row.ApplicantFullName,
                    row.Address,
                    statusCode,
                    CompanyWorkflowStatusMapper.IsFieldTaskCompleted(statusCode),
                    row.Description,
                    row.ActivityAtUtc);
            })
            .ToArray();
    }

    private sealed class AssignedFieldTaskRow
    {
        public int TaskId { get; init; }

        public int CitizenId { get; init; }

        public string ApplicantFullName { get; init; } = string.Empty;

        public string? Address { get; init; }

        public string CompanyStatus { get; init; } = string.Empty;

        public string? Description { get; init; }

        public DateTime ActivityAtUtc { get; init; }
    }
}
