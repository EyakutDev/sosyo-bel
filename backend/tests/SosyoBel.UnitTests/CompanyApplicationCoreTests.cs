using SosyoBel.Application.Applications;
using SosyoBel.Application.Kps;
using SosyoBel.Application.References;
using SosyoBel.Infrastructure.Kps;
using SosyoBel.Infrastructure.Persistence;
using Microsoft.Extensions.Logging.Abstractions;

namespace SosyoBel.UnitTests;

public sealed class CompanyApplicationCoreTests
{
    [Theory]
    [InlineData("Hanımınçiftliği Mah.", "HANIMINÇİFTLİĞİ")]
    [InlineData("HANIMINÇİFTLİĞİ MAHALLESİ", "HANIMINÇİFTLİĞİ")]
    public void NeighborhoodNormalizationMatchesCompanyWebRules(
        string source,
        string expected)
    {
        Assert.Equal(
            expected,
            CompanyKpsAddressMatcher.NormalizeNeighborhoodName(source));
    }

    [Theory]
    [InlineData("Malazgirt Sk.", "MALAZGİRT")]
    [InlineData("MALAZGİRT SOKAK", "MALAZGİRT")]
    [InlineData("Atatürk Caddesi", "ATATÜRK")]
    public void StreetNormalizationMatchesCompanyWebRules(
        string source,
        string expected)
    {
        Assert.Equal(
            expected,
            CompanyKpsAddressMatcher.NormalizeStreetName(source));
    }

    [Fact]
    public void DetailedKpsAddressMapsCompanyApplicationFields()
    {
        const string json = """
        {
          "Success": true,
          "RawData": {
            "SorguSonucu": [
              {
                "KimlikNo": 12345678901,
                "YerlesimYeriAdresi": {
                  "AcikAdres": " ÖRNEK MAH. TEST SK. NO: 1 ",
                  "AdresNo": 5085115540,
                  "IlIlceMerkezAdresi": {
                    "IlKodu": 44,
                    "IlceKodu": 1772,
                    "Mahalle": " ÖRNEK MAH. ",
                    "MahalleKodu": 165013,
                    "Csbm": " TEST SK. ",
                    "CsbmKodu": 612199,
                    "DisKapiNo": "83/1",
                    "IcKapiNo": "2"
                  }
                }
              }
            ]
          }
        }
        """;

        var result = KpsResponseReader.ReadAddress(json, "12345678901");

        Assert.Equal("ÖRNEK MAH. TEST SK. NO: 1", result.FullAddress);
        Assert.Equal(5085115540, result.AddressNumber);
        Assert.Equal(44, result.ProvinceCode);
        Assert.Equal(1772, result.DistrictCode);
        Assert.Equal(165013, result.NeighborhoodCode);
        Assert.Equal(612199, result.StreetCode);
        Assert.Equal("ÖRNEK MAH.", result.Neighborhood);
        Assert.Equal("TEST SK.", result.Street);
        Assert.Equal("83/1", result.ExteriorDoorNumber);
        Assert.Equal("2", result.InteriorDoorNumber);
    }

    [Fact]
    public void PendingRecordUsesExactCompanyApplicationFields()
    {
        var draft = new ApplicationDraftData(
            "12345678901",
            new DateOnly(1986, 9, 14),
            "5551112233",
            "YARDIM_TURU:12",
            true,
            "ENGEL_TURU:7",
            40,
            "Talep açıklaması",
            "İstemciden gelen ad kullanılmaz",
            "İstemciden gelen soyad kullanılmaz",
            "İstemciden gelen adres kullanılmaz",
            null);
        var profile = new KpsProfile(
            "12345678901",
            "Nuri",
            "Ersoy",
            "Baba",
            "Anne",
            new DateOnly(1986, 9, 14),
            "Balıkesir",
            "Erkek",
            "Evli",
            "Açık",
            "HANIMINÇİFTLİĞİ MAH. MALAZGİRT SK. NO: 83/1",
            5085115540,
            44,
            1772,
            165013,
            612199,
            "HANIMINÇİFTLİĞİ MAH.",
            "MALAZGİRT SK.",
            "83/1",
            "2");
        var applicationDate = new DateTime(2026, 8, 28, 12, 30, 0);
        const string token = "0123456789abcdef0123456789abcdef";

        var record = CompanyApplicationRecord.CreatePending(
            1,
            12,
            7,
            3,
            25,
            61,
            "identity-user-id",
            applicationDate,
            token,
            draft,
            profile,
            citizenId: 42);

        Assert.Equal(42, record.CitizenId);
        Assert.Equal(applicationDate, record.ApplicationDate);
        Assert.Equal("Nuri", record.ApplicantFirstName);
        Assert.Equal("Ersoy", record.ApplicantLastName);
        Assert.Equal("14.09.1986", record.ApplicantBirthDate);
        Assert.Equal(profile.FullAddress, record.ApplicationAddress);
        Assert.Equal(25, record.NeighborhoodId);
        Assert.Equal(61, record.StreetId);
        Assert.Equal(44, record.ProvinceCode);
        Assert.Equal(1772, record.DistrictCode);
        Assert.Equal(165013, record.NeighborhoodCode);
        Assert.Equal(612199, record.StreetCode);
        Assert.Equal(5085115540, record.AddressNumber);
        Assert.Equal(token, record.PublicToken);
        Assert.Null(record.HouseholdPhotoPath);
        Assert.Null(record.CancellationDate);
    }

    [Theory]
    [InlineData((int)CompanyCitizenMatchStatus.NotFound, null)]
    [InlineData((int)CompanyCitizenMatchStatus.Found, 42)]
    public void CitizenMatchUsesTheSingleExistingIdentityRecord(
        int expectedStatusValue,
        int? existingCitizenId)
    {
        var ids = existingCitizenId is null
            ? Array.Empty<int>()
            : [existingCitizenId.Value];

        var result = CompanyCitizenResolver.Classify(ids);

        Assert.Equal((CompanyCitizenMatchStatus)expectedStatusValue, result.Status);
        Assert.Equal(existingCitizenId, result.CitizenId);
    }

    [Fact]
    public void CitizenMatchRejectsAmbiguousIdentityRecords()
    {
        var result = CompanyCitizenResolver.Classify([42, 84]);

        Assert.Equal(CompanyCitizenMatchStatus.Ambiguous, result.Status);
        Assert.Null(result.CitizenId);
    }

    [Theory]
    [InlineData("Diğer")]
    [InlineData("DİĞER")]
    [InlineData(" diger ")]
    public void OtherRelationshipIsResolvedWithoutHardcodedCompanyId(string name)
    {
        Assert.True(CompanyRelationshipReferenceResolver.IsOther(name));
    }

    [Fact]
    public void FamilyRecordUsesOnlyExistingCompanyColumns()
    {
        var member = FamilyMember(
            relationshipCode: "YAKINLIK:4",
            vitalStatusCode: "SAG");

        var record = CompanyApplicationFamilyMemberRecord.Create(
            17,
            4,
            7,
            2,
            3,
            member);

        Assert.Equal(17, record.ApplicationId);
        Assert.Equal("Ayşe Yılmaz", record.FullName);
        Assert.Equal(42, record.Age);
        Assert.True(record.HasDisability);
        Assert.Equal(7, record.DisabilityTypeId);
        Assert.Equal(2, record.EmploymentStatusId);
        Assert.Equal(3, record.EducationStatusId);
        Assert.Equal(4, record.RelationshipId);
    }

    [Fact]
    public void FamilyExtraInformationIsAppendedToRequestDescription()
    {
        var members = new[]
        {
            FamilyMember(
                relationshipCode: "DIGER",
                vitalStatusCode: "OLU",
                otherRelationship: "Teyze"),
            FamilyMember(
                fullName: "Emel Yılmaz",
                relationshipCode: "YAKINLIK:1",
                vitalStatusCode: "SAG"),
        };

        var result = CompanyApplicationDescriptionComposer.Compose(
            "Talep açıklaması",
            members);

        Assert.NotNull(result);
        Assert.Contains("Talep açıklaması", result, StringComparison.Ordinal);
        Assert.Contains("--------------------", result, StringComparison.Ordinal);
        Assert.Contains(
            "Ayşe Yılmaz | Ölü/Sağ: Ölü | Diğer yakınlık: Teyze",
            result,
            StringComparison.Ordinal);
        Assert.Contains(
            "Emel Yılmaz | Ölü/Sağ: Sağ",
            result,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "Emel Yılmaz | Ölü/Sağ: Sağ | Diğer yakınlık:",
            result,
            StringComparison.Ordinal);
    }

    [Fact]
    public void CompletionNoteIsAppendedToRequestDescriptionWithSeparator()
    {
        var result = CompanyApplicationDescriptionComposer.Compose(
            "Talep açıklaması",
            [],
            "  Evde düzenli sıcak su bulunmuyor.  ");

        Assert.NotNull(result);
        Assert.Contains("Talep açıklaması", result, StringComparison.Ordinal);
        Assert.Contains("--------------------", result, StringComparison.Ordinal);
        Assert.Contains("Haneye ait ekstra not", result, StringComparison.Ordinal);
        Assert.EndsWith(
            "Evde düzenli sıcak su bulunmuyor.",
            result,
            StringComparison.Ordinal);
    }

    [Fact]
    public void CompanyDescriptionCanBeSplitForEditingWithoutDuplicatingSections()
    {
        var members = new[]
        {
            FamilyMember(
                relationshipCode: "DIGER",
                vitalStatusCode: "OLU",
                otherRelationship: "Teyze"),
        };
        var composed = CompanyApplicationDescriptionComposer.Compose(
            "Talep açıklaması",
            members,
            "Evde düzenli sıcak su bulunmuyor.");

        var parsed = CompanyApplicationDescriptionComposer.Parse(composed);

        Assert.Equal("Talep açıklaması", parsed.RequestDescription);
        Assert.Equal(
            "Evde düzenli sıcak su bulunmuyor.",
            parsed.ExtraNote);
        var family = Assert.Single(parsed.FamilyMembers);
        Assert.Equal("OLU", family.VitalStatusCode);
        Assert.Equal("Teyze", family.OtherRelationshipDescription);
    }

    [Fact]
    public void CompletedSubmissionPublicIdIsStablePerActorAndRequestKey()
    {
        var first = CompletedApplicationSubmissionService.CreatePublicId(
            "identity-user-id",
            "submit-board-123");
        var replay = CompletedApplicationSubmissionService.CreatePublicId(
            "identity-user-id",
            "submit-board-123");
        var otherRequest = CompletedApplicationSubmissionService.CreatePublicId(
            "identity-user-id",
            "submit-board-456");

        Assert.Equal(first, replay);
        Assert.NotEqual(first, otherRequest);
        Assert.Equal(32, first.ToString("N").Length);
    }

    [Fact]
    public void HouseholdContractContainsTheFiveRequiredDesignQuestions()
    {
        Assert.Equal(5, HouseholdFormContract.Questions.Count);
        Assert.All(
            HouseholdFormContract.Questions,
            question =>
            {
                Assert.True(question.IsRequired);
                Assert.Equal(
                    HouseholdFormContract.SingleChoiceAnswerType,
                    question.AnswerTypeCode);
                Assert.NotEmpty(question.Options);
            });
        Assert.Equal(
            [
                "MULKIYET_DURUMU",
                "MULK_TIPI",
                "EV_TEMIZLIGI",
                "BARINMA_DURUMU",
                "EV_ESYALARI",
            ],
            HouseholdFormContract.Questions.Select(value => value.Code).ToArray());
    }

    [Fact]
    public void HouseholdAnswersAreValidatedOrderedAndPreparedForDboTable()
    {
        ApplicationHouseholdAnswerData[] unorderedAnswers =
        [
            new("EV_ESYALARI", "KISMEN_YETERLI"),
            new("EV_TEMIZLIGI", "HAYIR"),
            new("MULKIYET_DURUMU", "KIRACI"),
            new("BARINMA_DURUMU", "ORTA"),
            new("MULK_TIPI", "APARTMAN_DAIRESI"),
        ];

        var preparation = CompanyApplicationHouseholdPreparer.Prepare(
            unorderedAnswers);

        Assert.Equal(
            CompanyApplicationHouseholdPreparationStatus.Prepared,
            preparation.Status);
        Assert.NotNull(preparation.Answers);
        Assert.Equal(
            HouseholdFormContract.Questions.Select(value => value.Code),
            preparation.Answers.Select(value => value.QuestionCode));

        var records = preparation.Answers
            .Select(answer =>
                CompanyApplicationHouseholdAnswerRecord.Create(42, answer))
            .ToArray();

        Assert.Equal(5, records.Length);
        Assert.All(records, record => Assert.Equal(42, record.ApplicationId));
        Assert.Equal(
            HouseholdFormContract.Questions.Select(value => value.Code),
            records.Select(value => value.QuestionCode));
        Assert.Equal(
            unorderedAnswers.ToDictionary(
                value => value.QuestionCode,
                value => value.OptionCode,
                StringComparer.Ordinal),
            records.ToDictionary(
                value => value.QuestionCode,
                value => value.OptionCode,
                StringComparer.Ordinal));

        var description = CompanyApplicationDescriptionComposer.Compose(
            "Talep açıklaması",
            []);
        Assert.Equal("Talep açıklaması", description);
        Assert.DoesNotContain(
            "Hane durumu bilgileri",
            description,
            StringComparison.Ordinal);
    }

    [Fact]
    public void HouseholdPreparationRejectsMissingAndForeignOptions()
    {
        ApplicationHouseholdAnswerData[] answers =
        [
            new("MULKIYET_DURUMU", "EVET"),
        ];

        var result = CompanyApplicationHouseholdPreparer.Prepare(answers);

        Assert.Equal(
            CompanyApplicationHouseholdPreparationStatus.InvalidInput,
            result.Status);
        Assert.NotNull(result.Errors);
        Assert.Contains("householdAnswers[0].optionCode", result.Errors.Keys);
        Assert.Contains("householdAnswers.MULK_TIPI", result.Errors.Keys);
        Assert.Contains("householdAnswers.EV_ESYALARI", result.Errors.Keys);
    }

    [Fact]
    public async Task CompanyPhotosUseExistingCitizenAndCompanyWebPath()
    {
        var storage = new StubPhotoStorage();
        var timeProvider = new FixedTimeProvider(
            new DateTimeOffset(2026, 8, 28, 12, 30, 0, TimeSpan.FromHours(3)));
        var preparer = new CompanyApplicationPhotoPreparer(
            storage, timeProvider, NullLogger<CompanyApplicationPhotoPreparer>.Instance);
        var applicationPublicId = Guid.Parse("01234567-89ab-cdef-0123-456789abcdef");
        ApplicationPhotoUpload[] photos =
        [
            Photo(order: 2, fileName: "ikinci.png", contentType: "image/png"),
            Photo(order: 1, fileName: "birinci.jpg", contentType: "image/jpeg"),
        ];

        var result = await preparer.PrepareAsync(
            42,
            applicationPublicId,
            photos,
            CancellationToken.None);

        Assert.Equal(CompanyApplicationPhotoPreparationStatus.Prepared, result.Status);
        Assert.NotNull(result.Records);
        Assert.Equal(2, result.Records.Count);
        Assert.All(result.Records, record =>
        {
            Assert.Equal(42, record.CitizenId);
            Assert.StartsWith(
                "/uploads/hanefotograflari/",
                record.PhotoPath,
                StringComparison.Ordinal);
            Assert.Equal("Başvuru Formundan Yüklendi", record.Description);
            Assert.Equal(timeProvider.GetLocalNow().DateTime, record.UploadedAt);
        });
        Assert.Equal([1, 2], storage.SavedOrders);
        Assert.Equal(
            new[]
            {
                $"/uploads/hanefotograflari/{applicationPublicId:N}/01.jpg",
                $"/uploads/hanefotograflari/{applicationPublicId:N}/02.png",
            },
            result.Records.Select(record => record.PhotoPath));
    }

    [Fact]
    public async Task CompanyPhotoPreparationRejectsMoreThanFifteenWithoutWritingFiles()
    {
        var storage = new StubPhotoStorage();
        var preparer = new CompanyApplicationPhotoPreparer(
            storage,
            TimeProvider.System,
            NullLogger<CompanyApplicationPhotoPreparer>.Instance);
        var photos = Enumerable.Range(1, 16)
            .Select(index => Photo(
                checked((byte)index),
                $"{index}.jpg",
                "image/jpeg"))
            .ToArray();

        var result = await preparer.PrepareAsync(
            42,
            Guid.NewGuid(),
            photos,
            CancellationToken.None);

        Assert.Equal(
            CompanyApplicationPhotoPreparationStatus.InvalidInput,
            result.Status);
        Assert.Empty(storage.SavedOrders);
        Assert.NotNull(result.Errors);
        Assert.Contains("photos", result.Errors.Keys);
    }

    [Fact]
    public async Task CompanyPhotoPreparationDeletesCreatedFilesWhenStorageFails()
    {
        var storage = new StubPhotoStorage(failOnOrder: 2);
        var preparer = new CompanyApplicationPhotoPreparer(
            storage,
            TimeProvider.System,
            NullLogger<CompanyApplicationPhotoPreparer>.Instance);

        var result = await preparer.PrepareAsync(
            42,
            Guid.NewGuid(),
            [
                Photo(1, "bir.jpg", "image/jpeg"),
                Photo(2, "iki.jpg", "image/jpeg"),
            ],
            CancellationToken.None);

        Assert.Equal(
            CompanyApplicationPhotoPreparationStatus.StorageFailure,
            result.Status);
        Assert.Single(storage.DeletedKeys);
        Assert.EndsWith("/01.jpg", storage.DeletedKeys[0], StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("application/01-photo.jpg")]
    [InlineData("application\\01-photo.jpg")]
    [InlineData("/application/01-photo.jpg/")]
    public void CompanyPhotoPathUsesHouseholdPhotoSubdirectory(string storageKey)
    {
        Assert.Equal(
            "/uploads/hanefotograflari/application/01-photo.jpg",
            CompanyApplicationPhotoPreparer.ToCompanyWebPath(storageKey));
    }

    [Theory]
    [InlineData("../photo.jpg")]
    [InlineData("application\\..\\photo.jpg")]
    [InlineData("application/../photo.jpg")]
    [InlineData("/")]
    public void CompanyPhotoPathRejectsTraversalAndEmptyKeys(string storageKey)
    {
        Assert.Throws<InvalidDataException>(() =>
            CompanyApplicationPhotoPreparer.ToCompanyWebPath(storageKey));
    }

    private static ApplicationFamilyMemberData FamilyMember(
        string fullName = "Ayşe Yılmaz",
        string relationshipCode = "YAKINLIK:4",
        string vitalStatusCode = "SAG",
        string? otherRelationship = null) =>
        new(
            fullName,
            42,
            relationshipCode,
            otherRelationship,
            true,
            "ENGEL_TURU:7",
            null,
            "CALISMA_DURUMU:2",
            "EGITIM_DURUMU:3",
            vitalStatusCode);

    private static ApplicationPhotoUpload Photo(
        byte order,
        string fileName,
        string contentType)
    {
        var content = new byte[] { order, 2, 3 };
        return new(
            fileName,
            contentType,
            content.Length,
            order,
            new MemoryStream(content));
    }

    private sealed class StubPhotoStorage(byte? failOnOrder = null)
        : IApplicationPhotoStorage
    {
        public List<byte> SavedOrders { get; } = [];
        public List<string> DeletedKeys { get; } = [];

        public Task<StoredApplicationPhoto> SaveAsync(
            Guid applicationPublicId,
            ApplicationPhotoUpload photo,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            SavedOrders.Add(photo.Order);
            if (photo.Order == failOnOrder)
                throw new IOException("Test storage failure.");

            var extension = Path.GetExtension(photo.FileName);
            var key = $"{applicationPublicId:N}/{photo.Order:D2}{extension}";
            return Task.FromResult(new StoredApplicationPhoto(
                key,
                photo.FileName,
                photo.ContentType,
                photo.Length,
                [1, 2, 3],
                photo.Order,
                WasCreated: true));
        }

        public Task DeleteAsync(string storageKey, CancellationToken cancellationToken)
        {
            DeletedKeys.Add(storageKey);
            return Task.CompletedTask;
        }

        public Task<Stream> OpenReadAsync(
            string storageKey,
            CancellationToken cancellationToken) =>
            Task.FromResult<Stream>(new MemoryStream());
    }

    private sealed class FixedTimeProvider(DateTimeOffset value) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => value.ToUniversalTime();
        public override TimeZoneInfo LocalTimeZone { get; } =
            TimeZoneInfo.CreateCustomTimeZone(
                "CompanyPhotoTests",
                value.Offset,
                "CompanyPhotoTests",
                "CompanyPhotoTests");
    }
}
