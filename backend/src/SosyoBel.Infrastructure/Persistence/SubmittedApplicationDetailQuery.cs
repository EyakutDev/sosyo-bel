using System.Globalization;
using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Applications;
using SosyoBel.Application.References;
using SosyoBel.Application.WorkItems;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Yetkili personelin kendi dbo başvurusunu veya başka kullanıcıya ait yalnız
/// bekleyen başvuruyu okumasını sağlar. KPS çağrısı yapılmaz; saklanan kopya kullanılır.
/// </summary>
internal sealed class SubmittedApplicationDetailQuery(
    CompanyApplicationDbContext dbContext) : ISubmittedApplicationDetailQuery
{
    private const string CompanyWebUploadPrefix = "/uploads/hanefotograflari/";

    public async Task<ApplicationLifecycleResult<SubmittedApplicationDetails>> GetAsync(
        ApplicationActorContext actor,
        int applicationId,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(actor);
        if (applicationId <= 0)
        {
            return Invalid(new Dictionary<string, string[]>
            {
                ["applicationId"] = ["Başvuru kimliği sıfırdan büyük olmalıdır."],
            });
        }

        var application = await BuildApplicationQuery(
                dbContext,
                applicationId,
                actor.ActorUserId)
            .SingleOrDefaultAsync(cancellationToken);
        if (application is null)
        {
            return new(
                ApplicationLifecycleStatus.NotFound,
                Code: "application_not_found",
                Detail: "Başvuru bulunamadı.");
        }

        var familyMembers = await BuildFamilyQuery(dbContext, applicationId)
            .ToArrayAsync(cancellationToken);
        var householdAnswers =
            await BuildHouseholdAnswerQuery(dbContext, applicationId)
                .ToArrayAsync(cancellationToken);

        CompanyApplicationPhotoRow[] photos = [];
        var applicationPublicId = ParsePublicId(application.PublicToken);
        if (application.CitizenId is > 0 && applicationPublicId is not null)
        {
            var pathPrefix =
                $"{CompanyWebUploadPrefix}{applicationPublicId.Value:N}/";
            photos = await BuildPhotoQuery(
                    dbContext,
                    application.CitizenId.Value,
                    pathPrefix)
                .ToArrayAsync(cancellationToken);
        }

        return new(
            ApplicationLifecycleStatus.Succeeded,
            BuildDetails(
                actor,
                application,
                familyMembers,
                householdAnswers,
                photos));
    }

    internal static IQueryable<CompanyApplicationDetailRow> BuildApplicationQuery(
        CompanyApplicationDbContext context,
        int applicationId,
        string userId) =>
        from application in context.Set<CompanyApplicationRecord>().AsNoTracking()
        join status in context.Set<ApplicationStatusReference>().AsNoTracking()
            on application.StatusId equals status.Id
        join citizen in context.Set<CompanyCitizenRecord>().AsNoTracking()
                on application.CitizenId equals (int?)citizen.Id into citizens
        from citizen in citizens.DefaultIfEmpty()
        where application.Id == applicationId &&
            (
                application.CreatedByUserId == userId ||
                status.Name == "Beklemede" ||
                status.Name == "Kurul Bekliyor"
            )
        select new CompanyApplicationDetailRow
        {
            ApplicationId = application.Id,
            CitizenId = application.CitizenId,
            PublicToken = application.PublicToken,
            CompanyStatusName = status.Name,
            CreatedByUserId = application.CreatedByUserId,
            ApplicationDate = application.ApplicationDate,
            IdentityNumber = application.ApplicantIdentityNumber,
            FirstName = application.ApplicantFirstName,
            LastName = application.ApplicantLastName,
            BirthDateStorage = application.ApplicantBirthDate,
            CitizenBirthDate = citizen == null
                ? null
                : (DateTime?)citizen.BirthDate,
            PhoneNumber = application.ApplicantPhone,
            HelpTypeId = application.HelpTypeId,
            HasDisability = application.HasDisability,
            DisabilityTypeId = application.DisabilityTypeId,
            DisabilityRate = application.DisabilityRate,
            Description = application.Description,
            Address = application.ApplicationAddress,
            Gender = application.ApplicantGender,
            BirthPlace = application.ApplicantBirthPlace,
            MaritalStatus = application.ApplicantMaritalStatus,
            CancellationDescription = application.CancellationDescription,
            CancellationDate = application.CancellationDate,
        };

    internal static IQueryable<CompanyApplicationFamilyRow> BuildFamilyQuery(
        CompanyApplicationDbContext context,
        int applicationId) =>
        from member in context.Set<CompanyApplicationFamilyMemberRecord>()
            .AsNoTracking()
        join relationship in context.Set<RelationshipReference>().AsNoTracking()
            on member.RelationshipId equals relationship.Id
        where member.ApplicationId == applicationId
        orderby member.Id
        select new CompanyApplicationFamilyRow
        {
            Id = member.Id,
            FullName = member.FullName,
            Age = member.Age,
            HasDisability = member.HasDisability,
            DisabilityTypeId = member.DisabilityTypeId,
            EmploymentStatusId = member.EmploymentStatusId,
            EducationStatusId = member.EducationStatusId,
            RelationshipId = member.RelationshipId,
            RelationshipName = relationship.Name,
        };

    internal static IQueryable<CompanyApplicationHouseholdAnswerRow>
        BuildHouseholdAnswerQuery(
            CompanyApplicationDbContext context,
            int applicationId) =>
        context.Set<CompanyApplicationHouseholdAnswerRecord>()
            .AsNoTracking()
            .Where(answer => answer.ApplicationId == applicationId)
            .OrderBy(answer => answer.Id)
            .Select(answer => new CompanyApplicationHouseholdAnswerRow
            {
                Id = answer.Id,
                QuestionCode = answer.QuestionCode,
                OptionCode = answer.OptionCode,
            });

    internal static IQueryable<CompanyApplicationPhotoRow> BuildPhotoQuery(
        CompanyApplicationDbContext context,
        int citizenId,
        string pathPrefix) =>
        context.Set<CompanyHouseholdPhotoRecord>()
            .AsNoTracking()
            .Where(photo =>
                photo.CitizenId == citizenId &&
                photo.PhotoPath.StartsWith(pathPrefix))
            .OrderBy(photo => photo.Id)
            .Select(photo => new CompanyApplicationPhotoRow
            {
                Id = photo.Id,
                UrlPath = photo.PhotoPath,
                Description = photo.Description,
                UploadedAt = photo.UploadedAt,
            });

    internal static SubmittedApplicationDetails BuildDetails(
        ApplicationActorContext actor,
        CompanyApplicationDetailRow application,
        IReadOnlyCollection<CompanyApplicationFamilyRow> familyRows,
        IReadOnlyCollection<CompanyApplicationHouseholdAnswerRow> householdRows,
        IReadOnlyCollection<CompanyApplicationPhotoRow> photoRows)
    {
        ArgumentNullException.ThrowIfNull(actor);
        ArgumentNullException.ThrowIfNull(application);

        var statusCode =
            CompanyWorkflowStatusMapper.MapApplication(application.CompanyStatusName);
        var isOwnedByCurrentUser = string.Equals(
            application.CreatedByUserId?.Trim(),
            actor.ActorUserId.Trim(),
            StringComparison.Ordinal);
        var descriptionParts =
            CompanyApplicationDescriptionComposer.Parse(application.Description);

        var familyMembers = familyRows
            .OrderBy(row => row.Id)
            .Select((row, index) =>
            {
                var extra = index < descriptionParts.FamilyMembers.Count
                    ? descriptionParts.FamilyMembers[index]
                    : null;
                var isOtherRelationship =
                    CompanyRelationshipReferenceResolver.IsOther(
                        row.RelationshipName);
                return new ApplicationFamilyMemberSnapshot(
                    NullIfWhiteSpace(row.FullName) ?? string.Empty,
                    row.Age,
                    isOtherRelationship
                        ? CompanyRelationshipReferenceResolver.OtherCode
                        : Encode(
                            ApplicationReferenceCodeQueries.Relationship,
                            row.RelationshipId),
                    isOtherRelationship
                        ? extra?.OtherRelationshipDescription
                        : null,
                    row.HasDisability,
                    row.HasDisability
                        ? Encode(
                            ApplicationReferenceCodeQueries.DisabilityType,
                            row.DisabilityTypeId)
                        : null,
                    row.HasDisability ? extra?.DisabilityDescription : null,
                    Encode(
                        ApplicationReferenceCodeQueries.EmploymentStatus,
                        row.EmploymentStatusId),
                    Encode(
                        ApplicationReferenceCodeQueries.EducationStatus,
                        row.EducationStatusId),
                    extra?.VitalStatusCode);
            })
            .ToArray();

        var questionOrders = HouseholdFormContract.Questions
            .ToDictionary(question => question.Code, question => question.Order);
        var householdAnswers = householdRows
            .OrderBy(row => questionOrders.TryGetValue(
                row.QuestionCode,
                out var order)
                    ? order
                    : short.MaxValue)
            .ThenBy(row => row.Id)
            .Select(row => new ApplicationHouseholdAnswerData(
                row.QuestionCode,
                row.OptionCode))
            .ToArray();

        var photos = photoRows
            .OrderBy(row => row.Id)
            .Select(row => new SubmittedApplicationPhotoSnapshot(
                row.Id,
                row.UrlPath,
                NullIfWhiteSpace(row.Description),
                row.UploadedAt))
            .ToArray();

        return new SubmittedApplicationDetails(
            application.ApplicationId,
            ParsePublicId(application.PublicToken),
            $"#{application.ApplicationId}",
            statusCode,
            isOwnedByCurrentUser,
            isOwnedByCurrentUser &&
                statusCode == WorkItemStatusCodes.BoardPending,
            application.ApplicationDate,
            application.IdentityNumber.Trim(),
            application.FirstName.Trim(),
            application.LastName.Trim(),
            ParseBirthDate(
                application.BirthDateStorage,
                application.CitizenBirthDate),
            application.PhoneNumber.Trim(),
            CompanyReferenceCode.Encode(
                ApplicationReferenceCodeQueries.HelpType,
                application.HelpTypeId),
            application.HasDisability,
            application.HasDisability
                ? Encode(
                    ApplicationReferenceCodeQueries.DisabilityType,
                    application.DisabilityTypeId)
                : null,
            application.HasDisability ? application.DisabilityRate : null,
            descriptionParts.RequestDescription,
            descriptionParts.ExtraNote,
            NullIfWhiteSpace(application.Address),
            NullIfWhiteSpace(application.Gender),
            NullIfWhiteSpace(application.BirthPlace),
            NullIfWhiteSpace(application.MaritalStatus),
            NullIfWhiteSpace(application.CancellationDescription),
            application.CancellationDate,
            familyMembers,
            householdAnswers,
            photos);
    }

    private static ApplicationLifecycleResult<SubmittedApplicationDetails> Invalid(
        IReadOnlyDictionary<string, string[]> errors) =>
        new(
            ApplicationLifecycleStatus.InvalidInput,
            Code: "invalid_application_detail_request",
            Errors: errors);

    private static Guid? ParsePublicId(string? value) =>
        Guid.TryParseExact(value, "N", out var result) ? result : null;

    private static string? Encode(string referenceTypeCode, int? sourceId) =>
        sourceId is > 0
            ? CompanyReferenceCode.Encode(referenceTypeCode, sourceId.Value)
            : null;

    private static DateOnly? ParseBirthDate(
        string? value,
        DateTime? citizenBirthDate)
    {
        string[] formats = ["dd.MM.yyyy", "yyyy-MM-dd", "dd/MM/yyyy"];
        if (!string.IsNullOrWhiteSpace(value) &&
            DateOnly.TryParseExact(
                value.Trim(),
                formats,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var parsed))
        {
            return parsed;
        }

        return citizenBirthDate is null
            ? null
            : DateOnly.FromDateTime(citizenBirthDate.Value);
    }

    private static string? NullIfWhiteSpace(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    internal sealed class CompanyApplicationDetailRow
    {
        public int ApplicationId { get; init; }
        public int? CitizenId { get; init; }
        public string PublicToken { get; init; } = string.Empty;
        public string CompanyStatusName { get; init; } = string.Empty;
        public string? CreatedByUserId { get; init; }
        public DateTime ApplicationDate { get; init; }
        public string IdentityNumber { get; init; } = string.Empty;
        public string FirstName { get; init; } = string.Empty;
        public string LastName { get; init; } = string.Empty;
        public string? BirthDateStorage { get; init; }
        public DateTime? CitizenBirthDate { get; init; }
        public string PhoneNumber { get; init; } = string.Empty;
        public int HelpTypeId { get; init; }
        public bool HasDisability { get; init; }
        public int? DisabilityTypeId { get; init; }
        public int? DisabilityRate { get; init; }
        public string? Description { get; init; }
        public string? Address { get; init; }
        public string? Gender { get; init; }
        public string? BirthPlace { get; init; }
        public string? MaritalStatus { get; init; }
        public string? CancellationDescription { get; init; }
        public DateTime? CancellationDate { get; init; }
    }

    internal sealed class CompanyApplicationFamilyRow
    {
        public int Id { get; init; }
        public string FullName { get; init; } = string.Empty;
        public int Age { get; init; }
        public bool HasDisability { get; init; }
        public int? DisabilityTypeId { get; init; }
        public int? EmploymentStatusId { get; init; }
        public int? EducationStatusId { get; init; }
        public int RelationshipId { get; init; }
        public string RelationshipName { get; init; } = string.Empty;
    }

    internal sealed class CompanyApplicationHouseholdAnswerRow
    {
        public int Id { get; init; }
        public string QuestionCode { get; init; } = string.Empty;
        public string OptionCode { get; init; } = string.Empty;
    }

    internal sealed class CompanyApplicationPhotoRow
    {
        public int Id { get; init; }
        public string UrlPath { get; init; } = string.Empty;
        public string? Description { get; init; }
        public DateTime UploadedAt { get; init; }
    }
}
