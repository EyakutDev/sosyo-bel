using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.References;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class ApplicationReferenceQuery(SosyoBelDbContext dbContext)
    : IApplicationReferenceQuery
{
    private const string HelpTypeReferenceCode = "YARDIM_TURU";
    private const string DisabilityTypeReferenceCode = "ENGEL_TURU";
    private const string RelationshipReferenceCode = "YAKINLIK";
    private const string EmploymentStatusReferenceCode = "CALISMA_DURUMU";
    private const string EducationStatusReferenceCode = "EGITIM_DURUMU";

    public async Task<ApplicationReferenceCatalog> GetAsync(
        int municipalityId,
        CancellationToken cancellationToken = default)
    {
        if (municipalityId <= 0)
            throw new ArgumentOutOfRangeException(nameof(municipalityId));

        var helpTypes = await LoadCompanyOptionsAsync<HelpTypeReference>(
            HelpTypeReferenceCode,
            cancellationToken);
        var disabilityTypes = await LoadCompanyOptionsAsync<DisabilityTypeReference>(
            DisabilityTypeReferenceCode,
            cancellationToken);
        var relationships = await LoadCompanyOptionsAsync<RelationshipReference>(
            RelationshipReferenceCode,
            cancellationToken);
        var employmentStatuses = await LoadCompanyOptionsAsync<EmploymentStatusReference>(
            EmploymentStatusReferenceCode,
            cancellationToken);
        var educationStatuses = await LoadCompanyOptionsAsync<EducationStatusReference>(
            EducationStatusReferenceCode,
            cancellationToken);

        if (disabilityTypes.Any(value => value.Code == "YOK"))
        {
            throw new InvalidOperationException(
                "ENGEL_TURU referanslarında ayrılmış YOK kodu kullanılamaz.");
        }

        // "Yok" bir engel türü değil, formun engel yok seçeneğidir. Mobilin bu
        // iş kuralını metin karşılaştırmasıyla üretmemesi için sözleşmeye eklenir.
        var disabilityStatuses = new[]
        {
            new ApplicationReferenceOption("YOK", "Yok"),
        }.Concat(disabilityTypes).ToArray();

        var vitalStatuses = await dbContext.Set<VitalStatusReference>()
            .AsNoTracking()
            .Where(value => value.IsActive)
            .OrderBy(value => value.Order)
            .ThenBy(value => value.Id)
            .Select(value => new ApplicationReferenceOption(value.Code, value.Name))
            .ToArrayAsync(cancellationToken);

        var householdQuestions = await LoadHouseholdQuestionsAsync(
            municipalityId,
            cancellationToken);

        return new ApplicationReferenceCatalog(
            helpTypes,
            disabilityStatuses,
            relationships,
            employmentStatuses,
            educationStatuses,
            vitalStatuses,
            householdQuestions);
    }

    private async Task<IReadOnlyCollection<ApplicationReferenceOption>>
        LoadCompanyOptionsAsync<TSource>(
            string referenceTypeCode,
            CancellationToken cancellationToken)
        where TSource : class, ICompanyReferenceSource
    {
        var rows = await (
            from mapping in dbContext.Set<ReferenceCodeRecord>().AsNoTracking()
            join source in dbContext.Set<TSource>().AsNoTracking()
                on mapping.SourceId equals source.Id
            where mapping.ReferenceTypeCode == referenceTypeCode && !source.IsDeleted
            orderby mapping.SourceId
            select new { mapping.Code, source.Name })
            .ToArrayAsync(cancellationToken);

        if (rows.Any(value => string.IsNullOrWhiteSpace(value.Code) ||
                              string.IsNullOrWhiteSpace(value.Name)))
        {
            throw new InvalidOperationException(
                $"{referenceTypeCode} referanslarında kod veya etiket eksik.");
        }

        return rows
            .Select(value => new ApplicationReferenceOption(value.Code, value.Name))
            .ToArray();
    }

    private async Task<IReadOnlyCollection<HouseholdQuestionDefinition>>
        LoadHouseholdQuestionsAsync(
            int municipalityId,
            CancellationToken cancellationToken)
    {
        var candidates = await dbContext.Set<HouseholdQuestionReference>()
            .AsNoTracking()
            .Where(value => value.IsActive &&
                            (value.MunicipalityId == null ||
                             value.MunicipalityId == municipalityId))
            .ToArrayAsync(cancellationToken);

        // Aynı kodun hem global hem belediyeye özel kaydı varsa belediye kaydı
        // seçilir. Böylece mevcut global form bozulmadan yerel özelleştirme yapılabilir.
        var selectedQuestions = candidates
            .GroupBy(value => value.Code, StringComparer.Ordinal)
            .Select(group => group
                .OrderByDescending(value => value.MunicipalityId == municipalityId)
                .ThenBy(value => value.Id)
                .First())
            .OrderBy(value => value.Order)
            .ThenBy(value => value.Id)
            .ToArray();

        var questionIds = selectedQuestions.Select(value => value.Id).ToArray();
        var optionRows = await dbContext.Set<HouseholdQuestionOptionReference>()
            .AsNoTracking()
            .Where(value => value.IsActive && questionIds.Contains(value.QuestionId))
            .OrderBy(value => value.Order)
            .ThenBy(value => value.Id)
            .ToArrayAsync(cancellationToken);

        return selectedQuestions
            .Select(question => new HouseholdQuestionDefinition(
                question.Code,
                question.Label,
                question.AnswerTypeCode,
                question.IsRequired,
                question.Order,
                optionRows
                    .Where(option => option.QuestionId == question.Id)
                    .Select(option => new HouseholdQuestionOption(
                        option.Code,
                        option.Label,
                        option.Order))
                    .ToArray()))
            .ToArray();
    }
}
