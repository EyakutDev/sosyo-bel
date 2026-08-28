using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.References;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed class ApplicationReferenceQuery(SosyoBelDbContext dbContext)
    : IApplicationReferenceQuery
{
    public async Task<ApplicationReferenceCatalog> GetAsync(
        CancellationToken cancellationToken = default)
    {
        var helpTypes = await LoadCompanyOptionsAsync<HelpTypeReference>(
            ApplicationReferenceCodeQueries.HelpType,
            cancellationToken);
        var disabilityTypes = await LoadCompanyOptionsAsync<DisabilityTypeReference>(
            ApplicationReferenceCodeQueries.DisabilityType,
            cancellationToken);
        var relationships = await LoadRelationshipOptionsAsync(cancellationToken);
        var employmentStatuses = await LoadCompanyOptionsAsync<EmploymentStatusReference>(
            ApplicationReferenceCodeQueries.EmploymentStatus,
            cancellationToken);
        var educationStatuses = await LoadCompanyOptionsAsync<EducationStatusReference>(
            ApplicationReferenceCodeQueries.EducationStatus,
            cancellationToken);

        // "Yok" bir engel türü değil, formun engel yok seçeneğidir. Mobilin bu
        // iş kuralını metin karşılaştırmasıyla üretmemesi için sözleşmeye eklenir.
        var disabilityStatuses = new[]
        {
            new ApplicationReferenceOption("YOK", "Yok"),
        }.Concat(disabilityTypes).ToArray();

        // Bu iki seçenek uygulama sözleşmesinin parçasıdır; şirket veritabanında
        // karşılık gelen kolon veya lookup tablosu bulunmadığı için DB'den okunmaz.
        ApplicationReferenceOption[] vitalStatuses =
        [
            new("SAG", "Sağ"),
            new("OLU", "Ölü"),
        ];

        var householdQuestions = HouseholdFormContract.Questions;

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
        LoadRelationshipOptionsAsync(
            CancellationToken cancellationToken)
    {
        var rows = await dbContext.Set<RelationshipReference>()
            .AsNoTracking()
            .Where(source => !source.IsDeleted)
            .OrderBy(source => source.Id)
            .Select(source => new { source.Id, source.Name })
            .ToArrayAsync(cancellationToken);
        if (rows.Any(value => string.IsNullOrWhiteSpace(value.Name)))
            throw new InvalidOperationException("YAKINLIK referanslarında etiket eksik.");

        var otherRows = rows
            .Where(value => CompanyRelationshipReferenceResolver.IsOther(value.Name))
            .ToArray();
        if (otherRows.Length != 1)
        {
            throw new InvalidOperationException(
                "Etkin dbo.Yakinliklar kayıtlarında tek bir Diğer seçeneği bulunmalıdır.");
        }

        return rows
            .Select(value => new ApplicationReferenceOption(
                CompanyRelationshipReferenceResolver.IsOther(value.Name)
                    ? CompanyRelationshipReferenceResolver.OtherCode
                    : CompanyReferenceCode.Encode(
                        ApplicationReferenceCodeQueries.Relationship,
                        value.Id),
                value.Name))
            .ToArray();
    }

    private async Task<IReadOnlyCollection<ApplicationReferenceOption>>
        LoadCompanyOptionsAsync<TSource>(
            string referenceTypeCode,
            CancellationToken cancellationToken)
        where TSource : class, ICompanyReferenceSource
    {
        // Şirket lookup tablolarında ayrı bir kod kolonu bulunmuyor. Tür + gerçek
        // dbo kimliği kullanılarak ek eşleme tablosuna ihtiyaç duymayan kod üretilir.
        var rows = await dbContext.Set<TSource>()
            .AsNoTracking()
            .Where(source => !source.IsDeleted)
            .OrderBy(source => source.Id)
            .Select(source => new { source.Id, source.Name })
            .ToArrayAsync(cancellationToken);

        if (rows.Any(value => string.IsNullOrWhiteSpace(value.Name)))
        {
            throw new InvalidOperationException(
                $"{referenceTypeCode} referanslarında etiket eksik.");
        }

        return rows
            .Select(value => new ApplicationReferenceOption(
                CompanyReferenceCode.Encode(referenceTypeCode, value.Id),
                value.Name))
            .ToArray();
    }

}
