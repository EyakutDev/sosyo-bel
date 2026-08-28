using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Applications;
using SosyoBel.Application.Kps;

namespace SosyoBel.Infrastructure.Persistence;

internal sealed record CompanyApplicationCoreInput(
    ApplicationDraftData Draft,
    KpsProfile KpsProfile,
    string PublicToken);

internal enum CompanyApplicationCoreWriteStatus
{
    Created,
    InvalidInput,
    ReferenceNotFound,
    AddressNotMatched,
    CitizenNotFound,
    CitizenConflict,
}

internal sealed record CompanyApplicationCoreWriteResult(
    CompanyApplicationCoreWriteStatus Status,
    int? ApplicationId = null,
    int? CitizenId = null,
    string? PublicToken = null,
    string? Code = null,
    IReadOnlyDictionary<string, string[]>? Errors = null);

/// <summary>
/// Tamamlanmış mobil başvurunun çekirdek alanlarını yalnız şirketin mevcut
/// dbo.Basvurular tablosuna yazar. Transaction sınırı üstteki tamamlanmış
/// başvuru servisindedir; bu sınıf tek başına endpoint olarak yayımlanmaz.
/// </summary>
internal sealed class CompanyApplicationCoreWriter(
    CompanyApplicationDbContext context,
    TimeProvider timeProvider)
{
    public async Task<CompanyApplicationCoreWriteResult> CreatePendingAsync(
        string actorUserId,
        CompanyApplicationCoreInput input,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(input);
        var now = timeProvider.GetLocalNow();
        if (string.IsNullOrWhiteSpace(actorUserId))
        {
            return Invalid("actor", "Doğrulanmış kullanıcı kimliği bulunamadı.");
        }

        if (!ApplicationDraftValidation.TryNormalize(
                input.Draft,
                DateOnly.FromDateTime(now.DateTime),
                out var draft,
                out var errors))
        {
            return new CompanyApplicationCoreWriteResult(
                CompanyApplicationCoreWriteStatus.InvalidInput,
                Code: "invalid_application",
                Errors: errors);
        }

        var profile = input.KpsProfile;
        if (!MatchesDraft(draft, profile))
        {
            return Invalid(
                "kpsProfile",
                "KPS profili başvuru kimlik ve doğum bilgileriyle eşleşmiyor.");
        }

        var status = await CompanyApplicationStatusResolver.FindActiveAsync(
            context,
            ApplicationStatusCodes.PendingBoard,
            cancellationToken);
        var requestChannelId =
            await CompanyRequestChannelResolver.ResolveFaceToFaceIdAsync(
                context,
                cancellationToken);
        var helpTypeId =
            await context.ResolveActiveCompanyReferenceIdAsync<HelpTypeReference>(
                ApplicationReferenceCodeQueries.HelpType,
                draft.HelpTypeCode,
                cancellationToken);
        int? disabilityTypeId = null;
        if (draft.HasDisability)
        {
            disabilityTypeId =
                await context.ResolveActiveCompanyReferenceIdAsync<DisabilityTypeReference>(
                    ApplicationReferenceCodeQueries.DisabilityType,
                    draft.DisabilityTypeCode,
                    cancellationToken);
        }

        if (status is null || requestChannelId is null || helpTypeId is null ||
            (draft.HasDisability && disabilityTypeId is null))
        {
            return new CompanyApplicationCoreWriteResult(
                CompanyApplicationCoreWriteStatus.ReferenceNotFound,
                Code: "company_reference_not_found");
        }

        var addressIds = await CompanyKpsAddressMatcher.ResolveAsync(
            context,
            profile,
            cancellationToken);
        if (addressIds.NeighborhoodId is null)
        {
            return new CompanyApplicationCoreWriteResult(
                CompanyApplicationCoreWriteStatus.AddressNotMatched,
                Code: "company_neighborhood_not_found");
        }

        var citizenMatch = await CompanyCitizenResolver.ResolveAsync(
            context,
            draft.IdentityNumber,
            cancellationToken);
        if (citizenMatch.Status == CompanyCitizenMatchStatus.Ambiguous)
        {
            return new CompanyApplicationCoreWriteResult(
                CompanyApplicationCoreWriteStatus.CitizenConflict,
                Code: "company_citizen_identity_conflict");
        }
        if (citizenMatch.Status == CompanyCitizenMatchStatus.NotFound ||
            citizenMatch.CitizenId is null)
        {
            // Mobil başvuru ve hane fotoğrafları şirketin mevcut vatandaş kaydına
            // bağlanır; bu akış yeni dbo.Vatandaslar satırı üretmez.
            return new CompanyApplicationCoreWriteResult(
                CompanyApplicationCoreWriteStatus.CitizenNotFound,
                Code: "company_citizen_not_found");
        }

        var application = CompanyApplicationRecord.CreatePending(
            status.Id,
            helpTypeId.Value,
            disabilityTypeId,
            requestChannelId.Value,
            addressIds.NeighborhoodId.Value,
            addressIds.StreetId,
            actorUserId.Trim(),
            now.DateTime,
            input.PublicToken,
            draft,
            profile,
            citizenMatch.CitizenId.Value);

        context.Add(application);
        await context.SaveChangesAsync(cancellationToken);
        return new CompanyApplicationCoreWriteResult(
            CompanyApplicationCoreWriteStatus.Created,
            application.Id,
            citizenMatch.CitizenId.Value,
            input.PublicToken);
    }

    private static bool MatchesDraft(ApplicationDraftData draft, KpsProfile profile) =>
        string.Equals(
            draft.IdentityNumber,
            profile.IdentityNumber,
            StringComparison.Ordinal) &&
        draft.BirthDate == profile.BirthDate &&
        !string.IsNullOrWhiteSpace(profile.FirstName) &&
        !string.IsNullOrWhiteSpace(profile.LastName) &&
        !string.IsNullOrWhiteSpace(profile.FullAddress);

    private static CompanyApplicationCoreWriteResult Invalid(
        string field,
        string message) =>
        new(
            CompanyApplicationCoreWriteStatus.InvalidInput,
            Code: "invalid_application",
            Errors: new Dictionary<string, string[]>
            {
                [field] = [message],
            });
}
