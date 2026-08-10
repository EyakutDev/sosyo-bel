using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Auditing;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class AuditEventQuery(SosyoBelDbContext dbContext) : IAuditEventQuery
{
    public Task<IReadOnlyCollection<AuditEventSummary>> GetAllAsync(
        string? municipalityCode,
        int limit,
        CancellationToken cancellationToken)
    {
        ValidateLimit(limit);
        var normalizedCode = string.IsNullOrWhiteSpace(municipalityCode)
            ? null
            : municipalityCode.Trim().ToUpperInvariant();

        var query = dbContext.Database.SqlQuery<AuditEventRow>($"""
            SELECT TOP ({limit})
                audit.Id AS AuditId,
                belediye.Kod AS MunicipalityCode,
                audit.VarlikTuru AS EntityType,
                audit.VarlikPublicId AS EntityPublicId,
                audit.IslemKodu AS OperationCode,
                audit.Aciklama AS Description,
                audit.Gerekce AS Reason,
                audit.OlusturanUserId AS ActorUserId,
                NULLIF(LTRIM(RTRIM(CONCAT(actor.Ad, N' ', actor.Soyad))), N'') AS ActorDisplayName,
                audit.HedefUserId AS TargetUserId,
                NULLIF(LTRIM(RTRIM(CONCAT(target.Ad, N' ', target.Soyad))), N'') AS TargetDisplayName,
                audit.OlusturulmaTarihiUtc AS OccurredAtUtc,
                audit.CorrelationId AS CorrelationId
            FROM sosyobel.IslemGecmisleri AS audit
            INNER JOIN sosyobel.Belediyeler AS belediye
                ON belediye.Id = audit.BelediyeId
            LEFT JOIN dbo.AspNetUsers AS actor
                ON actor.Id = audit.OlusturanUserId
            LEFT JOIN dbo.AspNetUsers AS target
                ON target.Id = audit.HedefUserId
            WHERE {normalizedCode} IS NULL OR belediye.Kod = {normalizedCode}
            ORDER BY audit.OlusturulmaTarihiUtc DESC, audit.Id DESC
            """);

        return MaterializeAsync(query, cancellationToken);
    }

    public Task<IReadOnlyCollection<AuditEventSummary>> GetMunicipalityAsync(
        int municipalityId,
        int limit,
        CancellationToken cancellationToken)
    {
        ValidateScope(municipalityId, limit);
        var query = dbContext.Database.SqlQuery<AuditEventRow>($"""
            SELECT TOP ({limit})
                audit.Id AS AuditId,
                belediye.Kod AS MunicipalityCode,
                audit.VarlikTuru AS EntityType,
                audit.VarlikPublicId AS EntityPublicId,
                audit.IslemKodu AS OperationCode,
                audit.Aciklama AS Description,
                audit.Gerekce AS Reason,
                audit.OlusturanUserId AS ActorUserId,
                NULLIF(LTRIM(RTRIM(CONCAT(actor.Ad, N' ', actor.Soyad))), N'') AS ActorDisplayName,
                audit.HedefUserId AS TargetUserId,
                NULLIF(LTRIM(RTRIM(CONCAT(target.Ad, N' ', target.Soyad))), N'') AS TargetDisplayName,
                audit.OlusturulmaTarihiUtc AS OccurredAtUtc,
                audit.CorrelationId AS CorrelationId
            FROM sosyobel.IslemGecmisleri AS audit
            INNER JOIN sosyobel.Belediyeler AS belediye
                ON belediye.Id = audit.BelediyeId
            LEFT JOIN dbo.AspNetUsers AS actor
                ON actor.Id = audit.OlusturanUserId
            LEFT JOIN dbo.AspNetUsers AS target
                ON target.Id = audit.HedefUserId
            WHERE audit.BelediyeId = {municipalityId}
            ORDER BY audit.OlusturulmaTarihiUtc DESC, audit.Id DESC
            """);

        return MaterializeAsync(query, cancellationToken);
    }

    public Task<IReadOnlyCollection<AuditEventSummary>> GetOwnAsync(
        int municipalityId,
        string userId,
        int limit,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        ValidateScope(municipalityId, limit);
        var query = dbContext.Database.SqlQuery<AuditEventRow>($"""
            SELECT TOP ({limit})
                audit.Id AS AuditId,
                belediye.Kod AS MunicipalityCode,
                audit.VarlikTuru AS EntityType,
                audit.VarlikPublicId AS EntityPublicId,
                audit.IslemKodu AS OperationCode,
                audit.Aciklama AS Description,
                audit.Gerekce AS Reason,
                audit.OlusturanUserId AS ActorUserId,
                NULLIF(LTRIM(RTRIM(CONCAT(actor.Ad, N' ', actor.Soyad))), N'') AS ActorDisplayName,
                audit.HedefUserId AS TargetUserId,
                NULLIF(LTRIM(RTRIM(CONCAT(target.Ad, N' ', target.Soyad))), N'') AS TargetDisplayName,
                audit.OlusturulmaTarihiUtc AS OccurredAtUtc,
                audit.CorrelationId AS CorrelationId
            FROM sosyobel.IslemGecmisleri AS audit
            INNER JOIN sosyobel.Belediyeler AS belediye
                ON belediye.Id = audit.BelediyeId
            LEFT JOIN dbo.AspNetUsers AS actor
                ON actor.Id = audit.OlusturanUserId
            LEFT JOIN dbo.AspNetUsers AS target
                ON target.Id = audit.HedefUserId
            WHERE audit.BelediyeId = {municipalityId}
              AND audit.OlusturanUserId = {userId}
            ORDER BY audit.OlusturulmaTarihiUtc DESC, audit.Id DESC
            """);

        return MaterializeAsync(query, cancellationToken);
    }

    private static async Task<IReadOnlyCollection<AuditEventSummary>> MaterializeAsync(
        IQueryable<AuditEventRow> query,
        CancellationToken cancellationToken)
    {
        var rows = await query.ToArrayAsync(cancellationToken);
        return rows.Select(row => new AuditEventSummary(
                row.AuditId,
                row.MunicipalityCode,
                row.EntityType,
                row.EntityPublicId,
                row.OperationCode,
                row.Description,
                row.Reason,
                row.ActorUserId,
                row.ActorDisplayName,
                row.TargetUserId,
                row.TargetDisplayName,
                row.OccurredAtUtc,
                row.CorrelationId))
            .ToArray();
    }

    private static void ValidateScope(int municipalityId, int limit)
    {
        if (municipalityId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(municipalityId));
        }

        ValidateLimit(limit);
    }

    private static void ValidateLimit(int limit)
    {
        if (limit is < 1 or > 200)
        {
            throw new ArgumentOutOfRangeException(nameof(limit));
        }
    }

    private sealed class AuditEventRow
    {
        public long AuditId { get; init; }

        public string MunicipalityCode { get; init; } = string.Empty;

        public string EntityType { get; init; } = string.Empty;

        public Guid? EntityPublicId { get; init; }

        public string OperationCode { get; init; } = string.Empty;

        public string? Description { get; init; }

        public string? Reason { get; init; }

        public string? ActorUserId { get; init; }

        public string? ActorDisplayName { get; init; }

        public string? TargetUserId { get; init; }

        public string? TargetDisplayName { get; init; }

        public DateTime OccurredAtUtc { get; init; }

        public Guid? CorrelationId { get; init; }
    }
}
