using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore.Storage;
using SosyoBel.Application.Applications;
using SosyoBel.Infrastructure.Identity;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Başvurunun taslaktan kurula gönderilmesine kadar olan kalıcı yaşam döngüsünü
/// yönetir. Belediye kapsamı, idempotency, RowVersion ve transaction kuralları bu
/// katmanda uygulanır; şirketin dbo verisi sosyobel teknik uzantılarıyla birlikte kullanılır.
/// </summary>
internal sealed class ApplicationLifecycleService(
    SosyoBelDbContext dbContext,
    TimeProvider timeProvider,
    ILogger<ApplicationLifecycleService> logger) : IApplicationLifecycleService
{
    private const string CreateEndpoint = "APPLICATION_CREATE_DRAFT";
    private const string SubmitEndpoint = "APPLICATION_SUBMIT_TO_BOARD";
    private const string MobileRequestChannelCode = "MOBIL_SAHA";
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    public Task<ApplicationLifecycleResult<ApplicationDetails>> CreateDraftAsync(
        CreateApplicationDraftCommand command,
        CancellationToken cancellationToken)
    {
        var actorIsValid = TryValidateActor(command.Actor, out var actorErrors);
        var draftIsValid = ApplicationDraftValidation.TryNormalize(
            command.Draft,
            DateOnly.FromDateTime(timeProvider.GetUtcNow().UtcDateTime),
            out var draft,
            out var draftErrors);
        if (!actorIsValid || !IsValidIdempotencyKey(command.IdempotencyKey) || !draftIsValid)
        {
            return Task.FromResult(Invalid(CombineErrors(actorErrors, draftErrors)));
        }

        var requestHash = SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(draft, JsonOptions));
        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            CreateEndpoint,
            command.IdempotencyKey,
            requestHash,
            (nowUtc, token) => CreateCoreAsync(command.Actor, draft, nowUtc, token),
            cancellationToken);
    }

    public async Task<ApplicationLifecycleResult<ApplicationDetails>> GetAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        CancellationToken cancellationToken)
    {
        if (!TryValidateActor(actor, out var errors) || applicationPublicId == Guid.Empty)
        {
            return Invalid(errors);
        }

        var application = await FindScopedApplicationAsync(
            actor,
            applicationPublicId,
            tracking: false,
            cancellationToken);
        return application is null
            ? NotFound()
            : Succeeded(await ToDetailsAsync(application, cancellationToken));
    }

    public async Task<ApplicationLifecycleResult<ApplicationDraftSnapshot>> GetDraftSnapshotAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        CancellationToken cancellationToken)
    {
        if (!TryValidateActor(actor, out var errors) || applicationPublicId == Guid.Empty)
        {
            return Invalid<ApplicationDraftSnapshot>(errors);
        }

        var application = await FindScopedApplicationAsync(
            actor,
            applicationPublicId,
            tracking: false,
            cancellationToken);
        if (application is null) return NotFound<ApplicationDraftSnapshot>();

        var familyRows = await dbContext.Set<ApplicationFamilyMemberRecord>()
            .AsNoTracking()
            .Where(value => value.ApplicationId == application.Id)
            .OrderBy(value => value.Id)
            .ToArrayAsync(cancellationToken);
        var householdRows = await dbContext.Set<ApplicationHouseholdAnswerRecord>()
            .AsNoTracking()
            .Where(value => value.MunicipalityId == actor.MunicipalityId &&
                            value.ApplicationId == application.Id)
            .OrderBy(value => value.Id)
            .ToArrayAsync(cancellationToken);
        var photoRows = await dbContext.Set<ApplicationPhotoRecord>()
            .AsNoTracking()
            .Where(value => value.MunicipalityId == actor.MunicipalityId &&
                            value.ApplicationId == application.Id &&
                            !value.IsDeleted)
            .OrderBy(value => value.Order)
            .ToArrayAsync(cancellationToken);

        // Şirket lookup tablolarındaki değişebilir Türkçe adlar yerine, mobil
        // sözleşmenin kararlı kodlarını tek seferde geri çözüyoruz.
        var relationshipCodes = await LoadMappedCodesAsync<RelationshipReference>(
            ApplicationReferenceCodeQueries.Relationship,
            familyRows.Select(value => value.RelationshipId),
            cancellationToken);
        var employmentCodes = await LoadMappedCodesAsync<EmploymentStatusReference>(
            ApplicationReferenceCodeQueries.EmploymentStatus,
            familyRows.Where(value => value.EmploymentStatusId.HasValue)
                .Select(value => value.EmploymentStatusId!.Value),
            cancellationToken);
        var educationCodes = await LoadMappedCodesAsync<EducationStatusReference>(
            ApplicationReferenceCodeQueries.EducationStatus,
            familyRows.Where(value => value.EducationStatusId.HasValue)
                .Select(value => value.EducationStatusId!.Value),
            cancellationToken);
        var disabilityCodes = await LoadMappedCodesAsync<DisabilityTypeReference>(
            ApplicationReferenceCodeQueries.DisabilityType,
            familyRows.Where(value => value.DisabilityTypeId.HasValue)
                .Select(value => value.DisabilityTypeId!.Value),
            cancellationToken);
        var vitalIds = familyRows.Select(value => value.VitalStatusId).ToHashSet();
        var vitalCodes = vitalIds.Count == 0
            ? new Dictionary<int, string>()
            : await dbContext.Set<VitalStatusReference>()
                .AsNoTracking()
                .Where(value => vitalIds.Contains(value.Id))
                .ToDictionaryAsync(value => value.Id, value => value.Code, cancellationToken);

        var questionIds = householdRows.Select(value => value.QuestionId).ToHashSet();
        var questionCodes = questionIds.Count == 0
            ? new Dictionary<int, string>()
            : await dbContext.Set<HouseholdQuestionReference>()
                .AsNoTracking()
                .Where(value => questionIds.Contains(value.Id))
                .ToDictionaryAsync(value => value.Id, value => value.Code, cancellationToken);
        var optionIds = householdRows
            .Where(value => value.OptionId.HasValue)
            .Select(value => value.OptionId!.Value)
            .ToHashSet();
        var optionCodes = optionIds.Count == 0
            ? new Dictionary<int, string>()
            : await dbContext.Set<HouseholdQuestionOptionReference>()
                .AsNoTracking()
                .Where(value => optionIds.Contains(value.Id))
                .ToDictionaryAsync(value => value.Id, value => value.Code, cancellationToken);

        var family = familyRows.Select(value => new ApplicationFamilyMemberSnapshot(
            value.FullName,
            value.Age,
            relationshipCodes.GetValueOrDefault(value.RelationshipId),
            value.OtherRelationshipDescription,
            value.HasDisability,
            value.DisabilityTypeId is null
                ? null
                : disabilityCodes.GetValueOrDefault(value.DisabilityTypeId.Value),
            value.DisabilityDescription,
            value.EmploymentStatusId is null
                ? null
                : employmentCodes.GetValueOrDefault(value.EmploymentStatusId.Value),
            value.EducationStatusId is null
                ? null
                : educationCodes.GetValueOrDefault(value.EducationStatusId.Value),
            vitalCodes.GetValueOrDefault(value.VitalStatusId)))
            .ToArray();
        var household = householdRows
            .Where(value => value.OptionId.HasValue &&
                            questionCodes.ContainsKey(value.QuestionId) &&
                            optionCodes.ContainsKey(value.OptionId.Value))
            .Select(value => new ApplicationHouseholdAnswerData(
                questionCodes[value.QuestionId],
                optionCodes[value.OptionId!.Value]))
            .ToArray();
        var photos = photoRows.Select(value => new ApplicationPhotoSnapshot(
            value.Id,
            value.OriginalFileName,
            value.ContentType,
            value.Length,
            value.Order))
            .ToArray();

        return Succeeded(new ApplicationDraftSnapshot(
            await ToDetailsAsync(application, cancellationToken),
            family,
            household,
            // Bu seçenek vatandaş profili bağlantısı kurulana kadar yazma katmanında
            // reddedildiği için kalıcı bir değer üretmez.
            SaveToBeneficiaryDirectory: false,
            photos));
    }

    public async Task<ApplicationLifecycleResult<ApplicationDetails>> UpdateDraftAsync(
        UpdateApplicationDraftCommand command,
        CancellationToken cancellationToken)
    {
        var actorIsValid = TryValidateActor(command.Actor, out var actorErrors);
        var draftIsValid = ApplicationDraftValidation.TryNormalize(
            command.Draft,
            DateOnly.FromDateTime(timeProvider.GetUtcNow().UtcDateTime),
            out var draft,
            out var draftErrors);
        var rowVersionIsValid = ApplicationDraftValidation.TryDecodeRowVersion(
            command.ExpectedRowVersion,
            out var expectedRowVersion);
        if (!actorIsValid || command.ApplicationPublicId == Guid.Empty ||
            !draftIsValid || !rowVersionIsValid)
        {
            return Invalid(CombineErrors(actorErrors, draftErrors));
        }

        var application = await FindScopedApplicationAsync(
            command.Actor,
            command.ApplicationPublicId,
            tracking: true,
            cancellationToken);
        if (application is null) return NotFound();

        var currentStatus = await FindStatusCodeAsync(application.StatusId, cancellationToken);
        if (!ApplicationStatusRules.IsEditable(currentStatus)) return Locked();
        if (!RowVersionsMatch(application.RowVersion, expectedRowVersion)) return ConcurrentConflict();

        var references = await ResolveDraftReferencesAsync(draft, cancellationToken);
        if (references.Error is not null) return references.Error;

        application.UpdateDraft(
            draft,
            references.HelpTypeId,
            references.DisabilityTypeId,
            command.Actor.ActorUserId,
            timeProvider.GetUtcNow().UtcDateTime);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return Succeeded(await ToDetailsAsync(application, cancellationToken));
        }
        catch (DbUpdateConcurrencyException)
        {
            return ConcurrentConflict();
        }
    }

    public Task<ApplicationLifecycleResult<ApplicationDetails>> SaveFieldDataAsync(
        SaveApplicationFieldDataCommand command,
        CancellationToken cancellationToken)
    {
        var actorIsValid = TryValidateActor(command.Actor, out var actorErrors);
        var rowVersionIsValid = ApplicationDraftValidation.TryDecodeRowVersion(
            command.ExpectedRowVersion,
            out var expectedRowVersion);
        var fieldDataIsValid = ApplicationFieldDataValidation.TryNormalize(
            command.FamilyMembers,
            command.HouseholdAnswers,
            command.SaveToBeneficiaryDirectory,
            out var familyMembers,
            out var householdAnswers,
            out var fieldErrors);
        if (!actorIsValid || command.ApplicationPublicId == Guid.Empty ||
            !rowVersionIsValid || !fieldDataIsValid)
        {
            return Task.FromResult(Invalid(CombineErrors(actorErrors, fieldErrors)));
        }

        return SaveFieldDataCoreAsync(
            command.Actor,
            command.ApplicationPublicId,
            expectedRowVersion,
            familyMembers,
            householdAnswers,
            cancellationToken);
    }

    public Task<ApplicationLifecycleResult<ApplicationDetails>> SubmitToBoardAsync(
        SubmitApplicationToBoardCommand command,
        CancellationToken cancellationToken)
    {
        var actorIsValid = TryValidateActor(command.Actor, out var actorErrors);
        var rowVersionIsValid = ApplicationDraftValidation.TryDecodeRowVersion(
            command.ExpectedRowVersion,
            out var expectedRowVersion);
        if (!actorIsValid || command.ApplicationPublicId == Guid.Empty ||
            !rowVersionIsValid || !IsValidIdempotencyKey(command.IdempotencyKey))
        {
            return Task.FromResult(Invalid(actorErrors));
        }

        var requestHash = SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(
            new { command.ApplicationPublicId, command.ExpectedRowVersion },
            JsonOptions));
        return ExecuteIdempotentAsync(
            command.Actor.ActorUserId,
            SubmitEndpoint,
            command.IdempotencyKey,
            requestHash,
            (nowUtc, token) => SubmitCoreAsync(
                command.Actor,
                command.ApplicationPublicId,
                expectedRowVersion,
                nowUtc,
                token),
            cancellationToken);
    }

    private async Task<ApplicationLifecycleResult<ApplicationDetails>> CreateCoreAsync(
        ApplicationActorContext actor,
        ApplicationDraftData draft,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var draftStatus = await FindActiveStatusAsync(
            ApplicationStatusCodes.Draft,
            cancellationToken);
        var requestChannel = await dbContext
            .Active<RequestChannelReference>(
                ApplicationReferenceCodeQueries.RequestChannel)
            .SingleOrDefaultAsync(
                value => value.Code == MobileRequestChannelCode,
                cancellationToken);
        if (draftStatus is null || requestChannel is null)
        {
            return ConfigurationConflict();
        }

        var references = await ResolveDraftReferencesAsync(draft, cancellationToken);
        if (references.Error is not null) return references.Error;

        // Kurumun başvuru numarası biçimi henüz doğrulanmadığı için BasvuruNo
        // uydurulmaz. API cevabında geçici gösterim olarak dbo kimliği kullanılır.
        var application = ApplicationRecord.Create(
            draftStatus.SourceId,
            references.HelpTypeId,
            references.DisabilityTypeId,
            requestChannel.SourceId,
            actor.ActorUserId,
            nowUtc,
            draft);
        dbContext.Set<ApplicationRecord>().Add(application);
        await dbContext.SaveChangesAsync(cancellationToken);

        dbContext.Set<ApplicationStatusHistoryRecord>().Add(
            ApplicationStatusHistoryRecord.Create(
                application.Id,
                previousStatusId: null,
                newStatusId: draftStatus.SourceId,
                actorUserId: actor.ActorUserId,
                nowUtc: nowUtc));
        await dbContext.SaveChangesAsync(cancellationToken);
        return Succeeded(await ToDetailsAsync(application, cancellationToken));
    }

    private async Task<ApplicationLifecycleResult<ApplicationDetails>> SubmitCoreAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        byte[] expectedRowVersion,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var application = await FindScopedApplicationAsync(
            actor,
            applicationPublicId,
            tracking: true,
            cancellationToken);
        if (application is null) return NotFound();

        var currentStatus = await FindStatusCodeAsync(application.StatusId, cancellationToken);
        if (!ApplicationStatusRules.CanSubmitToBoard(currentStatus)) return Locked();
        if (!RowVersionsMatch(application.RowVersion, expectedRowVersion)) return ConcurrentConflict();

        var pendingStatus = await FindActiveStatusAsync(
            ApplicationStatusCodes.PendingBoard,
            cancellationToken);
        if (pendingStatus is null) return ConfigurationConflict();

        var previousStatusId = application.StatusId;
        application.SubmitToBoard(pendingStatus.SourceId, actor.ActorUserId, nowUtc);
        dbContext.Set<ApplicationStatusHistoryRecord>().Add(
            ApplicationStatusHistoryRecord.Create(
                application.Id,
                previousStatusId,
                pendingStatus.SourceId,
                actor.ActorUserId,
                nowUtc));
        await dbContext.SaveChangesAsync(cancellationToken);
        return Succeeded(await ToDetailsAsync(application, cancellationToken));
    }

    private async Task<ApplicationLifecycleResult<ApplicationDetails>> SaveFieldDataCoreAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        byte[] expectedRowVersion,
        IReadOnlyCollection<ApplicationFamilyMemberData> familyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerData> householdAnswers,
        CancellationToken cancellationToken)
    {
        try
        {
            var executionStrategy = dbContext.Database.CreateExecutionStrategy();
            return await executionStrategy.ExecuteAsync(async () =>
            {
                await using var transaction = await dbContext.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);
                var application = await FindScopedApplicationAsync(
                    actor,
                    applicationPublicId,
                    tracking: true,
                    cancellationToken);
                if (application is null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return NotFound();
                }

                var currentStatus = await FindStatusCodeAsync(
                    application.StatusId,
                    cancellationToken);
                if (!ApplicationStatusRules.IsEditable(currentStatus))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return Locked();
                }
                if (!RowVersionsMatch(application.RowVersion, expectedRowVersion))
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return ConcurrentConflict();
                }

                var references = await ResolveFieldReferencesAsync(
                    actor.MunicipalityId,
                    familyMembers,
                    householdAnswers,
                    cancellationToken);
                if (references.Error is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return references.Error;
                }

                // Entity iki tabloya bolundugu icin toplu SQL DELETE kullanilmaz.
                // EF kayitlari dogru FK sirasiyla uzanti ve dbo tablosundan siler.
                var existingFamilyMembers = await dbContext
                    .Set<ApplicationFamilyMemberRecord>()
                    .Where(value => value.ApplicationId == application.Id)
                    .ToArrayAsync(cancellationToken);
                dbContext.RemoveRange(existingFamilyMembers);

                // PUT istegi aile ve hane koleksiyonlarini tam bir anlik kopya olarak
                // ele alir. Bos hane listesi de onceki cevaplari bilincli olarak temizler.
                await dbContext.Set<ApplicationHouseholdAnswerRecord>()
                    .Where(value => value.MunicipalityId == actor.MunicipalityId &&
                                    value.ApplicationId == application.Id)
                    .ExecuteDeleteAsync(cancellationToken);

                var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
                foreach (var member in familyMembers)
                {
                    int? disabilityTypeId = member.DisabilityTypeCode is null
                        ? null
                        : references.DisabilityTypes[member.DisabilityTypeCode];
                    dbContext.Set<ApplicationFamilyMemberRecord>().Add(
                        ApplicationFamilyMemberRecord.Create(
                            application.Id,
                            references.Relationships[member.RelationshipCode],
                            disabilityTypeId,
                            references.EmploymentStatuses[member.EmploymentStatusCode],
                            references.EducationStatuses[member.EducationStatusCode],
                            references.VitalStatuses[member.VitalStatusCode],
                            actor.ActorUserId,
                            nowUtc,
                            member));
                }

                foreach (var answer in householdAnswers)
                {
                    var question = references.Questions[answer.QuestionCode];
                    dbContext.Set<ApplicationHouseholdAnswerRecord>().Add(
                        ApplicationHouseholdAnswerRecord.CreateSingleChoice(
                            actor.MunicipalityId,
                            application.Id,
                            question.QuestionId,
                            question.Options[answer.OptionCode],
                            actor.ActorUserId,
                            nowUtc));
                }

                application.Touch(actor.ActorUserId, nowUtc);
                await dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return Succeeded(await ToDetailsAsync(application, cancellationToken));
            });
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (DbUpdateConcurrencyException)
        {
            return ConcurrentConflict();
        }
        catch (DbUpdateException exception)
        {
            // SQL ayrintisi istemciye sizdirilmaz; operasyon ekibi trace/log uzerinden
            // gercek constraint veya kolon hatasini yine de inceleyebilir.
            logger.LogError(
                exception,
                "Application field data persistence failed for {ApplicationPublicId}.",
                applicationPublicId);
            return Conflict<ApplicationDetails>(
                "field_data_conflict",
                "Aile veya hane bilgileri başka bir işlemle çakıştı.");
        }
    }

    private async Task<DraftReferenceResolution> ResolveDraftReferencesAsync(
        ApplicationDraftData draft,
        CancellationToken cancellationToken)
    {
        var helpTypeId = await dbContext
            .Active<HelpTypeReference>(ApplicationReferenceCodeQueries.HelpType)
            .Where(value => value.Code == draft.HelpTypeCode)
            .Select(value => value.SourceId)
            .SingleOrDefaultAsync(cancellationToken);
        if (helpTypeId == 0)
        {
            return DraftReferenceResolution.Failed(Invalid(
                new Dictionary<string, string[]>
                {
                    ["helpTypeCode"] = ["Aktif yardım türü bulunamadı."],
                }));
        }

        int? disabilityTypeId = null;
        if (draft.HasDisability)
        {
            disabilityTypeId = await dbContext
                .Active<DisabilityTypeReference>(
                    ApplicationReferenceCodeQueries.DisabilityType)
                .Where(value => value.Code == draft.DisabilityTypeCode)
                .Select(value => (int?)value.SourceId)
                .SingleOrDefaultAsync(cancellationToken);
            if (disabilityTypeId is null)
            {
                return DraftReferenceResolution.Failed(Invalid(
                    new Dictionary<string, string[]>
                    {
                        ["disabilityTypeCode"] = ["Aktif engel türü bulunamadı."],
                    }));
            }
        }

        return new DraftReferenceResolution(helpTypeId, disabilityTypeId, null);
    }

    private async Task<FieldReferenceResolution> ResolveFieldReferencesAsync(
        int municipalityId,
        IReadOnlyCollection<ApplicationFamilyMemberData> familyMembers,
        IReadOnlyCollection<ApplicationHouseholdAnswerData> householdAnswers,
        CancellationToken cancellationToken)
    {
        var relationshipCodes = familyMembers
            .Select(value => value.RelationshipCode)
            .ToHashSet(StringComparer.Ordinal);
        var employmentCodes = familyMembers
            .Select(value => value.EmploymentStatusCode)
            .ToHashSet(StringComparer.Ordinal);
        var educationCodes = familyMembers
            .Select(value => value.EducationStatusCode)
            .ToHashSet(StringComparer.Ordinal);
        var vitalCodes = familyMembers
            .Select(value => value.VitalStatusCode)
            .ToHashSet(StringComparer.Ordinal);
        var disabilityCodes = familyMembers
            .Where(value => value.DisabilityTypeCode is not null)
            .Select(value => value.DisabilityTypeCode!)
            .ToHashSet(StringComparer.Ordinal);
        var questionCodes = householdAnswers
            .Select(value => value.QuestionCode)
            .ToHashSet(StringComparer.Ordinal);

        var relationships = await dbContext
            .Active<RelationshipReference>(ApplicationReferenceCodeQueries.Relationship)
            .Where(value => relationshipCodes.Contains(value.Code))
            .ToDictionaryAsync(
                value => value.Code,
                value => value.SourceId,
                cancellationToken);
        var employmentStatuses = await dbContext
            .Active<EmploymentStatusReference>(
                ApplicationReferenceCodeQueries.EmploymentStatus)
            .Where(value => employmentCodes.Contains(value.Code))
            .ToDictionaryAsync(
                value => value.Code,
                value => value.SourceId,
                cancellationToken);
        var educationStatuses = await dbContext
            .Active<EducationStatusReference>(
                ApplicationReferenceCodeQueries.EducationStatus)
            .Where(value => educationCodes.Contains(value.Code))
            .ToDictionaryAsync(
                value => value.Code,
                value => value.SourceId,
                cancellationToken);
        var vitalStatuses = await dbContext.Set<VitalStatusReference>()
            .AsNoTracking()
            .Where(value => value.IsActive && vitalCodes.Contains(value.Code))
            .ToDictionaryAsync(value => value.Code, value => value.Id, cancellationToken);

        var disabilityTypes = await dbContext
            .Active<DisabilityTypeReference>(
                ApplicationReferenceCodeQueries.DisabilityType)
            .Where(value => disabilityCodes.Contains(value.Code))
            .ToDictionaryAsync(
                value => value.Code,
                value => value.SourceId,
                cancellationToken);

        // Gönderilmeyen zorunlu soruları da belirleyebilmek için belediyenin etkin
        // soru kümesi bütünüyle okunur; belediyeye özel kayıt global kaydı ezer.
        var questionRows = await dbContext.Set<HouseholdQuestionReference>()
            .AsNoTracking()
            .Where(value => value.IsActive &&
                            (value.MunicipalityId == null ||
                             value.MunicipalityId == municipalityId))
            .ToArrayAsync(cancellationToken);
        var selectedQuestions = questionRows
            .GroupBy(value => value.Code, StringComparer.Ordinal)
            .ToDictionary(
                group => group.Key,
                group => group
                    .OrderByDescending(value => value.MunicipalityId == municipalityId)
                    .First(),
                StringComparer.Ordinal);
        var selectedQuestionIds = selectedQuestions.Values
            .Select(value => value.Id)
            .ToHashSet();
        var optionCodes = householdAnswers
            .Select(value => value.OptionCode)
            .ToHashSet(StringComparer.Ordinal);
        HouseholdQuestionOptionReference[] optionRows = [];
        if (selectedQuestionIds.Count > 0 && optionCodes.Count > 0)
        {
            optionRows = await dbContext.Set<HouseholdQuestionOptionReference>()
                .AsNoTracking()
                .Where(value => value.IsActive &&
                                selectedQuestionIds.Contains(value.QuestionId) &&
                                optionCodes.Contains(value.Code))
                .ToArrayAsync(cancellationToken);
        }

        var errors = new Dictionary<string, string[]>();
        AddMissingCodes(relationshipCodes, relationships.Keys, "familyMembers.relationshipCode", errors);
        AddMissingCodes(employmentCodes, employmentStatuses.Keys, "familyMembers.employmentStatusCode", errors);
        AddMissingCodes(educationCodes, educationStatuses.Keys, "familyMembers.educationStatusCode", errors);
        AddMissingCodes(vitalCodes, vitalStatuses.Keys, "familyMembers.vitalStatusCode", errors);
        AddMissingCodes(disabilityCodes, disabilityTypes.Keys, "familyMembers.disabilityTypeCode", errors);
        AddMissingCodes(questionCodes, selectedQuestions.Keys, "householdAnswers.questionCode", errors);

        var missingRequiredQuestions = selectedQuestions.Values
            .Where(value => value.IsRequired && !questionCodes.Contains(value.Code))
            .OrderBy(value => value.Order)
            .ThenBy(value => value.Id)
            .Select(value => value.Label)
            .ToArray();
        if (missingRequiredQuestions.Length > 0)
        {
            errors["householdAnswers"] =
                [$"Zorunlu hane soruları cevaplanmalıdır: {string.Join(", ", missingRequiredQuestions)}"];
        }

        var questions = new Dictionary<string, HouseholdQuestionResolution>(
            StringComparer.Ordinal);
        foreach (var answer in householdAnswers)
        {
            if (!selectedQuestions.TryGetValue(answer.QuestionCode, out var question))
                continue;
            if (question.AnswerTypeCode != "TEK_SECIM")
            {
                errors["householdAnswers.questionCode"] =
                    ["Bu sürüm yalnız TEK_SECIM hane sorularını kabul eder."];
                continue;
            }

            var options = optionRows
                .Where(value => value.QuestionId == question.Id)
                .ToDictionary(value => value.Code, value => value.Id, StringComparer.Ordinal);
            if (!options.ContainsKey(answer.OptionCode))
            {
                errors["householdAnswers.optionCode"] =
                    [$"{answer.QuestionCode} sorusu için {answer.OptionCode} seçeneği bulunamadı."];
                continue;
            }
            questions[answer.QuestionCode] = new(question.Id, options);
        }

        return errors.Count > 0
            ? FieldReferenceResolution.Failed(Invalid(errors))
            : new(
                relationships,
                employmentStatuses,
                educationStatuses,
                vitalStatuses,
                disabilityTypes,
                questions,
                null);
    }

    private static void AddMissingCodes(
        IReadOnlySet<string> requested,
        IEnumerable<string> resolved,
        string field,
        IDictionary<string, string[]> errors)
    {
        var resolvedSet = resolved.ToHashSet(StringComparer.Ordinal);
        var missing = requested.Where(value => !resolvedSet.Contains(value)).ToArray();
        if (missing.Length > 0)
            errors[field] = [$"Aktif referans kodu bulunamadı: {string.Join(", ", missing)}"];
    }

    private Task<ApplicationRecord?> FindScopedApplicationAsync(
        ApplicationActorContext actor,
        Guid applicationPublicId,
        bool tracking,
        CancellationToken cancellationToken)
    {
        IQueryable<ApplicationRecord> query = dbContext.Set<ApplicationRecord>();
        if (!tracking) query = query.AsNoTracking();
        return query.SingleOrDefaultAsync(
            value => value.PublicId == applicationPublicId &&
                     value.CreatedByUserId == actor.ActorUserId,
            cancellationToken);
    }

    private Task<ReferenceCodeRecord?> FindActiveStatusAsync(
        string code,
        CancellationToken cancellationToken) =>
        dbContext
            .Active<ApplicationStatusReference>(
                ApplicationReferenceCodeQueries.ApplicationStatus)
            .SingleOrDefaultAsync(
                value => value.Code == code,
                cancellationToken);

    private Task<string?> FindStatusCodeAsync(
        int statusId,
        CancellationToken cancellationToken) =>
        dbContext
            .Mapped<ApplicationStatusReference>(
                ApplicationReferenceCodeQueries.ApplicationStatus)
            .Where(value => value.SourceId == statusId)
            .Select(value => value.Code)
            .SingleOrDefaultAsync(cancellationToken);

    private async Task<IReadOnlyDictionary<int, string>> LoadMappedCodesAsync<TSource>(
        string referenceTypeCode,
        IEnumerable<int> sourceIds,
        CancellationToken cancellationToken)
        where TSource : class, ICompanyReferenceSource
    {
        var ids = sourceIds.ToHashSet();
        if (ids.Count == 0) return new Dictionary<int, string>();

        return await dbContext.Mapped<TSource>(referenceTypeCode)
            .Where(value => ids.Contains(value.SourceId))
            .ToDictionaryAsync(value => value.SourceId, value => value.Code, cancellationToken);
    }

    private async Task<ApplicationDetails> ToDetailsAsync(
        ApplicationRecord application,
        CancellationToken cancellationToken)
    {
        var statusCode = await FindStatusCodeAsync(application.StatusId, cancellationToken)
            ?? throw new InvalidOperationException("Başvuru durum kodu bulunamadı.");
        var helpTypeCode = await dbContext
            .Mapped<HelpTypeReference>(ApplicationReferenceCodeQueries.HelpType)
            .Where(value => value.SourceId == application.HelpTypeId)
            .Select(value => value.Code)
            .SingleAsync(cancellationToken);
        var disabilityTypeCode = application.DisabilityTypeId is null
            ? null
            : await dbContext
                .Mapped<DisabilityTypeReference>(
                    ApplicationReferenceCodeQueries.DisabilityType)
                .Where(value => value.SourceId == application.DisabilityTypeId)
                .Select(value => value.Code)
                .SingleAsync(cancellationToken);

        return new ApplicationDetails(
            application.PublicId,
            application.ApplicationNumber ??
                application.Id.ToString(
                    System.Globalization.CultureInfo.InvariantCulture),
            statusCode,
            ApplicationStatusRules.IsEditable(statusCode),
            application.IdentityNumber,
            application.BirthDate,
            application.PhoneNumber,
            helpTypeCode,
            application.HasDisability,
            disabilityTypeCode,
            application.DisabilityRate is null
                ? null
                : checked((byte)application.DisabilityRate.Value),
            application.Description,
            application.ApplicantFirstName,
            application.ApplicantLastName,
            application.Address,
            application.FieldInspectionNote,
            application.CreatedAtUtc,
            application.UpdatedAtUtc,
            application.SubmittedAtUtc,
            Convert.ToBase64String(application.RowVersion));
    }

    private async Task<ApplicationLifecycleResult<T>> ExecuteIdempotentAsync<T>(
        string actorUserId,
        string endpointCode,
        string idempotencyKey,
        byte[] requestHash,
        Func<DateTime, CancellationToken, Task<ApplicationLifecycleResult<T>>> operation,
        CancellationToken cancellationToken)
        where T : class
    {
        try
        {
            var executionStrategy = dbContext.Database.CreateExecutionStrategy();
            return await executionStrategy.ExecuteAsync(async () =>
            {
                await using var transaction = await dbContext.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);
                var nowUtc = timeProvider.GetUtcNow().UtcDateTime;
                var normalizedKey = idempotencyKey.Trim();
                var records = dbContext.Set<IdempotencyRecord>();
                var existing = await records.SingleOrDefaultAsync(
                    value => value.ActorUserId == actorUserId &&
                             value.EndpointCode == endpointCode &&
                             value.IdempotencyKey == normalizedKey,
                    cancellationToken);
                if (existing is not null)
                {
                    var replay = Replay<T>(existing, requestHash, nowUtc);
                    await transaction.CommitAsync(cancellationToken);
                    return replay;
                }

                var reservation = IdempotencyRecord.Create(
                    actorUserId,
                    endpointCode,
                    normalizedKey,
                    requestHash,
                    nowUtc,
                    nowUtc.AddHours(24));
                records.Add(reservation);
                await dbContext.SaveChangesAsync(cancellationToken);

                var result = await operation(nowUtc, cancellationToken);
                if (result.Status is not ApplicationLifecycleStatus.Succeeded || result.Value is null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return result;
                }

                reservation.Complete(200, JsonSerializer.Serialize(result.Value, JsonOptions));
                await dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return result;
            });
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (DbUpdateConcurrencyException)
        {
            return ConcurrentConflict<T>();
        }
        catch (DbUpdateException)
        {
            return Conflict<T>("database_conflict", "Kayıt başka bir işlemle çakıştı.");
        }
    }

    private static ApplicationLifecycleResult<T> Replay<T>(
        IdempotencyRecord existing,
        byte[] requestHash,
        DateTime nowUtc)
        where T : class
    {
        if (existing.ExpiresAtUtc <= nowUtc)
        {
            return IdempotencyConflict<T>(
                "idempotency_key_expired",
                "Bu istek anahtarının süresi doldu; yeni bir anahtar kullanın.");
        }
        if (existing.RequestHash.Length != requestHash.Length ||
            !CryptographicOperations.FixedTimeEquals(existing.RequestHash, requestHash))
        {
            return IdempotencyConflict<T>(
                "idempotency_payload_mismatch",
                "Aynı istek anahtarı farklı içerikle kullanılamaz.");
        }
        if (!existing.IsCompleted || string.IsNullOrWhiteSpace(existing.ResultJson))
        {
            return IdempotencyConflict<T>(
                "idempotency_request_in_progress",
                "Bu istek halen işleniyor.");
        }

        try
        {
            var value = JsonSerializer.Deserialize<T>(existing.ResultJson, JsonOptions);
            return value is null
                ? IdempotencyConflict<T>(
                    "idempotency_result_invalid",
                    "Önceki işlem sonucu okunamadı.")
                : Succeeded(value);
        }
        catch (JsonException)
        {
            return IdempotencyConflict<T>(
                "idempotency_result_invalid",
                "Önceki işlem sonucu okunamadı.");
        }
    }

    private static bool TryValidateActor(
        ApplicationActorContext? actor,
        out IReadOnlyDictionary<string, string[]> errors)
    {
        if (actor is null || string.IsNullOrWhiteSpace(actor.ActorUserId) ||
            actor.MunicipalityId <= 0 || actor.MunicipalityMembershipId <= 0)
        {
            errors = new Dictionary<string, string[]>
            {
                ["actor"] = ["Doğrulanmış belediye personeli bulunamadı."],
            };
            return false;
        }

        errors = new Dictionary<string, string[]>();
        return true;
    }

    private static bool IsValidIdempotencyKey(string? value) =>
        !string.IsNullOrWhiteSpace(value) && value.Trim().Length is >= 8 and <= 100;

    private static IReadOnlyDictionary<string, string[]> CombineErrors(
        params IReadOnlyDictionary<string, string[]>[] sources)
    {
        var result = new Dictionary<string, string[]>();
        foreach (var source in sources)
        {
            foreach (var item in source) result[item.Key] = item.Value;
        }
        return result;
    }

    private static bool RowVersionsMatch(byte[] current, byte[] expected) =>
        current.Length == expected.Length &&
        CryptographicOperations.FixedTimeEquals(current, expected);

    private static ApplicationLifecycleResult<T> Succeeded<T>(T value) =>
        new(ApplicationLifecycleStatus.Succeeded, value);

    private static ApplicationLifecycleResult<ApplicationDetails> Invalid(
        IReadOnlyDictionary<string, string[]> errors) =>
        new(
            ApplicationLifecycleStatus.InvalidInput,
            Errors: errors.Count == 0
                ? new Dictionary<string, string[]>
                {
                    ["request"] = ["İstek alanları doğrulanamadı."],
                }
                : errors);

    private static ApplicationLifecycleResult<T> Invalid<T>(
        IReadOnlyDictionary<string, string[]> errors) =>
        new(
            ApplicationLifecycleStatus.InvalidInput,
            Errors: errors.Count == 0
                ? new Dictionary<string, string[]>
                {
                    ["request"] = ["İstek alanları doğrulanamadı."],
                }
                : errors);

    private static ApplicationLifecycleResult<ApplicationDetails> NotFound() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "application_not_found",
            Detail: "Başvuru bulunamadı.");

    private static ApplicationLifecycleResult<T> NotFound<T>() =>
        new(
            ApplicationLifecycleStatus.NotFound,
            Code: "application_not_found",
            Detail: "Başvuru bulunamadı.");

    private static ApplicationLifecycleResult<ApplicationDetails> Locked() =>
        new(
            ApplicationLifecycleStatus.Conflict,
            Code: "application_locked",
            Detail: "Kurula gönderilen başvuru artık düzenlenemez.");

    private static ApplicationLifecycleResult<ApplicationDetails> ConfigurationConflict() =>
        new(
            ApplicationLifecycleStatus.Conflict,
            Code: "reference_data_missing",
            Detail: "Başvuru referans verileri eksik.");

    private static ApplicationLifecycleResult<ApplicationDetails> ConcurrentConflict() =>
        ConcurrentConflict<ApplicationDetails>();

    private static ApplicationLifecycleResult<T> ConcurrentConflict<T>() =>
        Conflict<T>(
            "application_version_conflict",
            "Başvuru başka bir işlemde değişti; güncel kaydı tekrar açın.");

    private static ApplicationLifecycleResult<T> Conflict<T>(string code, string detail) =>
        new(ApplicationLifecycleStatus.Conflict, Code: code, Detail: detail);

    private static ApplicationLifecycleResult<T> IdempotencyConflict<T>(
        string code,
        string detail) =>
        new(ApplicationLifecycleStatus.IdempotencyConflict, Code: code, Detail: detail);

    private sealed record DraftReferenceResolution(
        int HelpTypeId,
        int? DisabilityTypeId,
        ApplicationLifecycleResult<ApplicationDetails>? Error)
    {
        public static DraftReferenceResolution Failed(
            ApplicationLifecycleResult<ApplicationDetails> error) =>
            new(0, null, error);
    }

    private sealed record HouseholdQuestionResolution(
        int QuestionId,
        IReadOnlyDictionary<string, int> Options);

    private sealed record FieldReferenceResolution(
        IReadOnlyDictionary<string, int> Relationships,
        IReadOnlyDictionary<string, int> EmploymentStatuses,
        IReadOnlyDictionary<string, int> EducationStatuses,
        IReadOnlyDictionary<string, int> VitalStatuses,
        IReadOnlyDictionary<string, int> DisabilityTypes,
        IReadOnlyDictionary<string, HouseholdQuestionResolution> Questions,
        ApplicationLifecycleResult<ApplicationDetails>? Error)
    {
        public static FieldReferenceResolution Failed(
            ApplicationLifecycleResult<ApplicationDetails> error) =>
            new(
                new Dictionary<string, int>(),
                new Dictionary<string, int>(),
                new Dictionary<string, int>(),
                new Dictionary<string, int>(),
                new Dictionary<string, int>(),
                new Dictionary<string, HouseholdQuestionResolution>(),
                error);
    }
}
