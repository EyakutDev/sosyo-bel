using SosyoBel.Application.Applications;

namespace SosyoBel.Infrastructure.Persistence;

internal enum CompanyApplicationFamilyPreparationStatus
{
    Prepared,
    InvalidInput,
    ReferenceNotFound,
}

internal sealed record CompanyApplicationFamilyPreparationResult(
    CompanyApplicationFamilyPreparationStatus Status,
    IReadOnlyCollection<CompanyApplicationFamilyMemberRecord>? Records = null,
    string? Code = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);

/// <summary>
/// Manuel aile verilerini doğrular ve yalnız mevcut dbo.BasvuruAileFertleri
/// kolonlarına yazılabilecek satırlara dönüştürür. SaveChanges çağırmaz; nihai
/// başvuru servisi bu satırları kendi transactionı içinde kaydedecektir.
/// </summary>
internal static class CompanyApplicationFamilyPreparer
{
    private static readonly IReadOnlySet<string> SupportedVitalStatusCodes =
        new HashSet<string>(StringComparer.Ordinal)
        {
            "SAG",
            "OLU",
        };

    public static async Task<CompanyApplicationFamilyPreparationResult> PrepareAsync(
        CompanyApplicationDbContext context,
        int applicationId,
        IReadOnlyCollection<ApplicationFamilyMemberData>? familyMembers,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(context);
        if (applicationId <= 0)
            throw new ArgumentOutOfRangeException(nameof(applicationId));

        if (!ApplicationFieldDataValidation.TryNormalize(
                familyMembers,
                [],
                saveToBeneficiaryDirectory: false,
                out var normalizedFamily,
                out _,
                out var errors))
        {
            return new CompanyApplicationFamilyPreparationResult(
                CompanyApplicationFamilyPreparationStatus.InvalidInput,
                Code: "invalid_application_family",
                Errors: errors);
        }

        var unsupportedVitalStatus = normalizedFamily
            .Select((member, index) => new { member.VitalStatusCode, Index = index })
            .FirstOrDefault(value =>
                !SupportedVitalStatusCodes.Contains(value.VitalStatusCode));
        if (unsupportedVitalStatus is not null)
        {
            return InvalidVitalStatus(unsupportedVitalStatus.Index);
        }

        var relationships = await ResolveRelationshipsAsync(
            context,
            normalizedFamily,
            cancellationToken);
        var employmentStatuses =
            await context.ResolveActiveCompanyReferenceIdsAsync<EmploymentStatusReference>(
                ApplicationReferenceCodeQueries.EmploymentStatus,
                normalizedFamily
                    .Select(value => value.EmploymentStatusCode)
                    .ToHashSet(StringComparer.Ordinal),
                cancellationToken);
        var educationStatuses =
            await context.ResolveActiveCompanyReferenceIdsAsync<EducationStatusReference>(
                ApplicationReferenceCodeQueries.EducationStatus,
                normalizedFamily
                    .Select(value => value.EducationStatusCode)
                    .ToHashSet(StringComparer.Ordinal),
                cancellationToken);
        var disabilityTypes =
            await context.ResolveActiveCompanyReferenceIdsAsync<DisabilityTypeReference>(
                ApplicationReferenceCodeQueries.DisabilityType,
                normalizedFamily
                    .Where(value => value.DisabilityTypeCode is not null)
                    .Select(value => value.DisabilityTypeCode!)
                    .ToHashSet(StringComparer.Ordinal),
                cancellationToken);

        if (normalizedFamily.Any(member =>
                !relationships.ContainsKey(member.RelationshipCode) ||
                !employmentStatuses.ContainsKey(member.EmploymentStatusCode) ||
                !educationStatuses.ContainsKey(member.EducationStatusCode) ||
                (member.DisabilityTypeCode is not null &&
                 !disabilityTypes.ContainsKey(member.DisabilityTypeCode))))
        {
            return new CompanyApplicationFamilyPreparationResult(
                CompanyApplicationFamilyPreparationStatus.ReferenceNotFound,
                Code: "company_family_reference_not_found");
        }

        var records = normalizedFamily
            .Select(member => CompanyApplicationFamilyMemberRecord.Create(
                applicationId,
                relationships[member.RelationshipCode],
                member.DisabilityTypeCode is null
                    ? null
                    : disabilityTypes[member.DisabilityTypeCode],
                employmentStatuses[member.EmploymentStatusCode],
                educationStatuses[member.EducationStatusCode],
                member))
            .ToArray();

        return new CompanyApplicationFamilyPreparationResult(
            CompanyApplicationFamilyPreparationStatus.Prepared,
            records);
    }

    private static async Task<IReadOnlyDictionary<string, int>>
        ResolveRelationshipsAsync(
            CompanyApplicationDbContext context,
            IReadOnlyCollection<ApplicationFamilyMemberData> familyMembers,
            CancellationToken cancellationToken)
    {
        var relationshipCodes = familyMembers
            .Select(value => value.RelationshipCode)
            .ToHashSet(StringComparer.Ordinal);
        var standardCodes = relationshipCodes
            .Where(value => !string.Equals(
                value,
                CompanyRelationshipReferenceResolver.OtherCode,
                StringComparison.Ordinal))
            .ToHashSet(StringComparer.Ordinal);
        var resolved =
            await context.ResolveActiveCompanyReferenceIdsAsync<RelationshipReference>(
                ApplicationReferenceCodeQueries.Relationship,
                standardCodes,
                cancellationToken);
        var result = resolved.ToDictionary(
            value => value.Key,
            value => value.Value,
            StringComparer.Ordinal);

        if (relationshipCodes.Contains(CompanyRelationshipReferenceResolver.OtherCode))
        {
            var otherId =
                await CompanyRelationshipReferenceResolver.ResolveOtherIdAsync(
                    context,
                    cancellationToken);
            if (otherId is not null)
                result[CompanyRelationshipReferenceResolver.OtherCode] = otherId.Value;
        }

        return result;
    }

    private static CompanyApplicationFamilyPreparationResult InvalidVitalStatus(
        int index) =>
        new(
            CompanyApplicationFamilyPreparationStatus.InvalidInput,
            Code: "invalid_application_family",
            Errors: new Dictionary<string, string[]>
            {
                [$"familyMembers[{index}].vitalStatusCode"] =
                    ["Yaşam durumu SAG veya OLU olmalıdır."],
            });
}
