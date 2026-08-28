using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.FieldTasks;
using SosyoBel.Application.WorkItems;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Personelin kendi dbo başvuruları ile kendisine atanmış dbo saha aktivitelerini
/// mobil uygulamanın tek bekleyen/tamamlanan iş listesinde birleştirir.
/// </summary>
internal sealed class UserWorkItemQuery(
    CompanyApplicationDbContext dbContext,
    IAssignedFieldTaskQuery assignedFieldTaskQuery) : IUserWorkItemQuery
{
    public async Task<IReadOnlyCollection<UserWorkItemSummary>> GetMineAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (limit is < 1 or > 100)
            throw new ArgumentOutOfRangeException(nameof(limit));

        var assignedTasks = await assignedFieldTaskQuery.GetAssignedAsync(
            userId,
            limit,
            cancellationToken);

        // Mobil başvuru kimliği mevcut dbo.Basvurular.PublicToken kolonunda 32
        // hexadecimal karakter olarak tutulur. Ek metadata tablosu veya migration
        // kullanılmadan yalnız şirketin doğrulanmış dbo modeli sorgulanır.
        var rows = await BuildOwnApplicationsQuery(dbContext, userId, limit)
            .ToArrayAsync(cancellationToken);

        var ownApplications = new List<UserWorkItemSummary>(rows.Length);
        foreach (var row in rows)
        {
            // Şirketin web kayıtlarındaki farklı PublicToken biçimleri mobil
            // başvuru kimliği sayılmaz ve tüm liste isteğini hataya düşürmez.
            if (!Guid.TryParseExact(
                    row.ApplicationPublicToken,
                    "N",
                    out var applicationPublicId))
            {
                continue;
            }

            var statusCode =
                CompanyWorkflowStatusMapper.MapApplication(row.CompanyStatusName);
            var applicantFullName = string.Join(
                ' ',
                new[] { row.ApplicantFirstName, row.ApplicantLastName }
                    .Where(value => !string.IsNullOrWhiteSpace(value))
                    .Select(value => value!.Trim()));

            ownApplications.Add(new UserWorkItemSummary(
                ApplicationPublicId: applicationPublicId,
                TaskId: null,
                ApplicationNumber: $"#{row.ApplicationId}",
                ApplicantFullName: string.IsNullOrEmpty(applicantFullName)
                    ? null
                    : applicantFullName,
                Address: NullIfWhiteSpace(row.Address),
                SourceCode: WorkItemSourceCodes.OwnApplication,
                StatusCode: statusCode,
                IsCompleted:
                    CompanyWorkflowStatusMapper.IsApplicationCompleted(statusCode),
                // Sunucuya ulaşan kayıt atomik olarak kurula gönderilmiş ve kilitlidir.
                IsEditable: false,
                Description: NullIfWhiteSpace(row.Description),
                ActivityAtUtc: row.ActivityAtUtc));
        }

        var assignedWorkItems = assignedTasks.Select(task => new UserWorkItemSummary(
            ApplicationPublicId: null,
            task.TaskId,
            ApplicationNumber: $"#{task.TaskId}",
            task.ApplicantFullName,
            task.Address,
            WorkItemSourceCodes.AssignedTask,
            task.StatusCode,
            task.IsCompleted,
            IsEditable: false,
            task.Description,
            task.ActivityAtUtc));

        // İki dbo tablosu arasında başvuru foreign key'i bulunmadığından görev ve
        // başvuru kayıtları uydurma bir ilişkiyle tekilleştirilmez.
        return assignedWorkItems
            .Concat(ownApplications)
            .OrderBy(item => item.IsCompleted)
            .ThenByDescending(item => item.ActivityAtUtc)
            .Take(limit)
            .ToArray();
    }

    /// <summary>
    /// Kendi başvuruları sorgusunu şirket dbo modelinden kurar. Ayrı metoda
    /// çıkarılması, üretilen SQL'in canlı veriye ihtiyaç duymadan sınanmasını sağlar.
    /// </summary>
    internal static IQueryable<UserWorkItemRow> BuildOwnApplicationsQuery(
        CompanyApplicationDbContext dbContext,
        string userId,
        int limit) =>
        (
            from application in dbContext.Set<CompanyApplicationRecord>()
                .AsNoTracking()
            join status in dbContext.Set<ApplicationStatusReference>()
                    .AsNoTracking()
                on application.StatusId equals status.Id
            where application.CreatedByUserId == userId
                && application.PublicToken.Length == 32
            orderby application.ApplicationDate descending, application.Id descending
            select new UserWorkItemRow
            {
                ApplicationPublicToken = application.PublicToken,
                ApplicationId = application.Id,
                ApplicantFirstName = application.ApplicantFirstName,
                ApplicantLastName = application.ApplicantLastName,
                Address = application.ApplicationAddress,
                CompanyStatusName = status.Name,
                Description = application.Description,
                ActivityAtUtc = application.ApplicationDate,
            })
            .Take(limit);

    private static string? NullIfWhiteSpace(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    internal sealed class UserWorkItemRow
    {
        public string ApplicationPublicToken { get; init; } = string.Empty;
        public int ApplicationId { get; init; }
        public string? ApplicantFirstName { get; init; }
        public string? ApplicantLastName { get; init; }
        public string? Address { get; init; }
        public string CompanyStatusName { get; init; } = string.Empty;
        public string? Description { get; init; }
        public DateTime ActivityAtUtc { get; init; }
    }
}
