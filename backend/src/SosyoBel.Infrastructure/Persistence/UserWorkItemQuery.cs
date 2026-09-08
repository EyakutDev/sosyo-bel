using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.FieldTasks;
using SosyoBel.Application.WorkItems;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Personelin görebildiği dbo başvuruları ile kendisine atanmış dbo saha
/// aktivitelerini mobil uygulamanın tek iş listesinde birleştirir.
/// </summary>
internal sealed class UserWorkItemQuery(
    CompanyApplicationDbContext dbContext,
    IAssignedFieldTaskQuery assignedFieldTaskQuery) : IUserWorkItemQuery
{
    public async Task<IReadOnlyCollection<UserWorkItemSummary>> GetVisibleAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken)
    {
        Validate(userId, limit);
        var assignedTasks = await assignedFieldTaskQuery.GetAssignedAsync(
            userId,
            limit,
            cancellationToken);
        var rows = await BuildVisibleApplicationsQuery(dbContext, userId, limit)
            .ToArrayAsync(cancellationToken);

        return Combine(
            assignedTasks,
            MapApplications(
                rows,
                userId,
                WorkItemSourceCodes.Application,
                requirePublicId: false,
                enableSubmittedApplicationEditing: true),
            limit);
    }

    public async Task<IReadOnlyCollection<UserWorkItemSummary>> GetMineAsync(
        string userId,
        int limit,
        CancellationToken cancellationToken)
    {
        Validate(userId, limit);
        var assignedTasks = await assignedFieldTaskQuery.GetAssignedAsync(
            userId,
            limit,
            cancellationToken);

        // Mobil başvuru kimliği mevcut dbo.Basvurular.PublicToken kolonunda 32
        // hexadecimal karakter olarak tutulur. Ek metadata tablosu veya migration
        // kullanılmadan yalnız şirketin doğrulanmış dbo modeli sorgulanır.
        var rows = await BuildOwnApplicationsQuery(dbContext, userId, limit)
            .ToArrayAsync(cancellationToken);

        return Combine(
            assignedTasks,
            MapApplications(
                rows,
                userId,
                WorkItemSourceCodes.OwnApplication,
                requirePublicId: true,
                enableSubmittedApplicationEditing: false),
            limit);
    }

    internal static IReadOnlyCollection<UserWorkItemSummary> MapApplications(
        IReadOnlyCollection<UserWorkItemRow> rows,
        string userId,
        string sourceCode,
        bool requirePublicId,
        bool enableSubmittedApplicationEditing)
    {
        var applications = new List<UserWorkItemSummary>(rows.Count);
        foreach (var row in rows)
        {
            Guid? applicationPublicId = Guid.TryParseExact(
                row.ApplicationPublicToken,
                "N",
                out var parsedPublicId)
                    ? parsedPublicId
                    : null;
            // Eski /mine sözleşmesi PublicId bekleyen mevcut mobil sürümler için
            // aynı davranışı korur. Yeni görünür liste dbo Id ile kayıtları açabilir.
            if (requirePublicId && applicationPublicId is null)
                continue;

            var statusCode =
                CompanyWorkflowStatusMapper.MapApplication(row.CompanyStatusName);
            var isOwnedByCurrentUser = string.Equals(
                row.CreatedByUserId?.Trim(),
                userId.Trim(),
                StringComparison.Ordinal);
            var applicantFullName = string.Join(
                ' ',
                new[] { row.ApplicantFirstName, row.ApplicantLastName }
                    .Where(value => !string.IsNullOrWhiteSpace(value))
                    .Select(value => value!.Trim()));

            applications.Add(new UserWorkItemSummary(
                ApplicationId: row.ApplicationId,
                ApplicationPublicId: applicationPublicId,
                TaskId: null,
                ApplicationNumber: $"#{row.ApplicationId}",
                ApplicantFullName: string.IsNullOrEmpty(applicantFullName)
                    ? null
                    : applicantFullName,
                Address: NullIfWhiteSpace(row.Address),
                SourceCode: sourceCode,
                StatusCode: statusCode,
                IsCompleted:
                    CompanyWorkflowStatusMapper.IsApplicationCompleted(statusCode),
                IsOwnedByCurrentUser: isOwnedByCurrentUser,
                IsEditable: enableSubmittedApplicationEditing &&
                    isOwnedByCurrentUser &&
                    statusCode == WorkItemStatusCodes.BoardPending,
                Description: NullIfWhiteSpace(row.Description),
                ActivityAtUtc: row.ActivityAtUtc));
        }

        return applications;
    }

    private static IReadOnlyCollection<UserWorkItemSummary> Combine(
        IReadOnlyCollection<AssignedFieldTaskSummary> assignedTasks,
        IReadOnlyCollection<UserWorkItemSummary> applications,
        int limit)
    {
        var assignedWorkItems = assignedTasks.Select(task => new UserWorkItemSummary(
            ApplicationId: null,
            ApplicationPublicId: null,
            task.TaskId,
            ApplicationNumber: $"#{task.TaskId}",
            task.ApplicantFullName,
            task.Address,
            WorkItemSourceCodes.AssignedTask,
            task.StatusCode,
            task.IsCompleted,
            IsOwnedByCurrentUser: false,
            IsEditable: false,
            task.Description,
            task.ActivityAtUtc));

        // İki dbo tablosu arasında başvuru foreign key'i bulunmadığından görev ve
        // başvuru kayıtları uydurma bir ilişkiyle tekilleştirilmez.
        return assignedWorkItems
            .Concat(applications)
            .OrderBy(item => item.IsCompleted)
            .ThenByDescending(item => item.ActivityAtUtc)
            .Take(limit)
            .ToArray();
    }

    private static void Validate(string userId, int limit)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        if (limit is < 1 or > 100)
            throw new ArgumentOutOfRangeException(nameof(limit));
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
                CreatedByUserId = application.CreatedByUserId,
                Description = application.Description,
                ActivityAtUtc = application.ApplicationDate,
            })
            .Take(limit);

    /// <summary>
    /// Kullanıcının kendi tüm başvurularını ve diğer kullanıcıların yalnız kurul
    /// işlemi bekleyen başvurularını getirir. Tamamlanmış başkasına ait kayıt açılmaz.
    /// </summary>
    internal static IQueryable<UserWorkItemRow> BuildVisibleApplicationsQuery(
        CompanyApplicationDbContext dbContext,
        string userId,
        int limit) =>
        (
            from application in dbContext.Set<CompanyApplicationRecord>()
                .AsNoTracking()
            join status in dbContext.Set<ApplicationStatusReference>()
                    .AsNoTracking()
                on application.StatusId equals status.Id
            where application.CreatedByUserId == userId ||
                status.Name == "Beklemede" ||
                status.Name == "Kurul Bekliyor"
            orderby application.ApplicationDate descending, application.Id descending
            select new UserWorkItemRow
            {
                ApplicationPublicToken = application.PublicToken,
                ApplicationId = application.Id,
                ApplicantFirstName = application.ApplicantFirstName,
                ApplicantLastName = application.ApplicantLastName,
                Address = application.ApplicationAddress,
                CompanyStatusName = status.Name,
                CreatedByUserId = application.CreatedByUserId,
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
        public string? CreatedByUserId { get; init; }
        public string? Description { get; init; }
        public DateTime ActivityAtUtc { get; init; }
    }
}
