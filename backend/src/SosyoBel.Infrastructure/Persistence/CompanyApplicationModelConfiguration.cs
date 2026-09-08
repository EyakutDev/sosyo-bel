using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirketin sağladığı dbo şema snapshotının EF karşılığıdır. Bütün tablolar
/// migration dışında bırakılır; API bu model üzerinden CREATE/ALTER üretmez.
/// </summary>
internal static class CompanyApplicationModelConfiguration
{
    public static void Configure(ModelBuilder builder)
    {
        ConfigureCitizen(builder);
        ConfigureApplication(builder);
        ConfigureHouseholdAnswer(builder);
        ConfigureFamilyMember(builder);
        ConfigureHouseholdPhoto(builder);
        ConfigureAddressReferences(builder);
        ConfigureReferences(builder);
    }

    private static void ConfigureAddressReferences(ModelBuilder builder)
    {
        builder.Entity<CompanyNeighborhoodReference>(entity =>
        {
            entity.ToTable("Mahalleler", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.Name)
                .HasColumnName("Name")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });

        builder.Entity<CompanyStreetReference>(entity =>
        {
            entity.ToTable("Sokaklar", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.Name)
                .HasColumnName("Name")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.NeighborhoodId).HasColumnName("MahalleId");
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
            entity.HasOne<CompanyNeighborhoodReference>()
                .WithMany()
                .HasForeignKey(value => value.NeighborhoodId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }

    private static void ConfigureCitizen(ModelBuilder builder)
    {
        builder.Entity<CompanyCitizenRecord>(entity =>
        {
            entity.ToTable("Vatandaslar", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.IdentityNumber)
                .HasColumnName("TcKimlikNo")
                .HasMaxLength(11)
                .IsRequired();
            entity.Property(value => value.FirstName)
                .HasColumnName("Ad")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.LastName)
                .HasColumnName("Soyad")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.BirthDate).HasColumnName("DogumTarihi");
            entity.Property(value => value.Address)
                .HasColumnName("AcikAdres")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.PrimaryPhone)
                .HasColumnName("Telefon1")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.SecondaryPhone)
                .HasColumnName("Telefon2")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.Email)
                .HasColumnName("Email")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityRate).HasColumnName("EngelOrani");
            entity.Property(value => value.ChildCount).HasColumnName("CocukSayisi");
            entity.Property(value => value.RegisteredAt).HasColumnName("KayitTarihi");
            entity.Property(value => value.NeighborhoodId).HasColumnName("MahalleId");
            entity.Property(value => value.StreetId).HasColumnName("SokakId");
            entity.Property(value => value.CreatedByUserId)
                .HasColumnName("OlusturanUserId")
                .HasMaxLength(450);
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
            entity.Property(value => value.EmploymentStatusId).HasColumnName("CalismaDurumuId");
            entity.Property(value => value.EducationStatusId).HasColumnName("EgitimDurumuId");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.MaritalStatusId).HasColumnName("MedeniDurumId");
            entity.Property(value => value.Gender)
                .HasColumnName("Cinsiyet")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.BirthPlace)
                .HasColumnName("DogumYeri")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ProvinceCode).HasColumnName("IlKodu");
            entity.Property(value => value.DistrictCode).HasColumnName("IlceKodu");
            entity.Property(value => value.KpsNeighborhood)
                .HasColumnName("KpsMahalle")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.KpsStreet)
                .HasColumnName("KpsSokak")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.NeighborhoodCode).HasColumnName("MahalleKodu");
            entity.Property(value => value.StreetCode).HasColumnName("SokakKodu");
            entity.Property(value => value.AddressNumber).HasColumnName("AdresNo");
            entity.HasIndex(value => value.IdentityNumber).IsUnique();

            entity.HasOne<EmploymentStatusReference>()
                .WithMany()
                .HasForeignKey(value => value.EmploymentStatusId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<EducationStatusReference>()
                .WithMany()
                .HasForeignKey(value => value.EducationStatusId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<DisabilityTypeReference>()
                .WithMany()
                .HasForeignKey(value => value.DisabilityTypeId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }

    private static void ConfigureApplication(ModelBuilder builder)
    {
        builder.Entity<CompanyApplicationRecord>(entity =>
        {
            entity.ToTable("Basvurular", "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.CitizenId).HasColumnName("VatandasId");
            entity.Property(value => value.ApplicationDate).HasColumnName("BasvuruTarihi");
            entity.Property(value => value.Description)
                .HasColumnName("TalepAciklamasi")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicantFirstName)
                .HasColumnName("BasvuranAd")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.ApplicationAddress)
                .HasColumnName("BasvuruAcikAdres")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicantBirthDate)
                .HasColumnName("BasvuranDogumTarihi")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicantLastName)
                .HasColumnName("BasvuranSoyad")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.ApplicantIdentityNumber)
                .HasColumnName("BasvuranTcKimlikNo")
                .HasMaxLength(11)
                .IsRequired();
            entity.Property(value => value.ApplicantPhone)
                .HasColumnName("BasvuranTelefon")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.HouseholdPhotoPath)
                .HasColumnName("HaneFotografYolu")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.CancellationDescription)
                .HasColumnName("IptalAciklamasi")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.CancellationDate).HasColumnName("IptalTarihi");
            entity.Property(value => value.StatusId).HasColumnName("BasvuruDurumuId");
            entity.Property(value => value.NeighborhoodId).HasColumnName("MahalleId");
            entity.Property(value => value.StreetId).HasColumnName("SokakId");
            entity.Property(value => value.HelpTypeId).HasColumnName("YardimTuruId");
            entity.Property(value => value.RequestChannelId).HasColumnName("TalepGelisKanaliId");
            entity.Property(value => value.CreatedByUserId)
                .HasColumnName("OlusturanUserId")
                .HasMaxLength(450);
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityRate).HasColumnName("EngelOrani");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.PublicToken)
                .HasColumnName("PublicToken")
                .HasMaxLength(32)
                .IsRequired();
            entity.Property(value => value.ApplicantGender)
                .HasColumnName("BasvuranCinsiyet")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicantBirthPlace)
                .HasColumnName("BasvuranDogumYeri")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicantMaritalStatus)
                .HasColumnName("BasvuranMedeniHal")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicationNeighborhood)
                .HasColumnName("BasvuruMahalle")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ApplicationStreet)
                .HasColumnName("BasvuruSokak")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.ProvinceCode).HasColumnName("IlKodu");
            entity.Property(value => value.DistrictCode).HasColumnName("IlceKodu");
            entity.Property(value => value.NeighborhoodCode).HasColumnName("MahalleKodu");
            entity.Property(value => value.StreetCode).HasColumnName("SokakKodu");
            entity.Property(value => value.AddressNumber).HasColumnName("AdresNo");

            entity.HasOne<CompanyCitizenRecord>()
                .WithMany()
                .HasForeignKey(value => value.CitizenId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<ApplicationStatusReference>()
                .WithMany()
                .HasForeignKey(value => value.StatusId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<HelpTypeReference>()
                .WithMany()
                .HasForeignKey(value => value.HelpTypeId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<RequestChannelReference>()
                .WithMany()
                .HasForeignKey(value => value.RequestChannelId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<DisabilityTypeReference>()
                .WithMany()
                .HasForeignKey(value => value.DisabilityTypeId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }

    private static void ConfigureHouseholdAnswer(ModelBuilder builder)
    {
        builder.Entity<CompanyApplicationHouseholdAnswerRecord>(entity =>
        {
            entity.ToTable(
                "BasvuruHaneCevaplari",
                "dbo",
                table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.QuestionCode)
                .HasColumnName("SoruKodu")
                .HasMaxLength(80)
                .IsRequired();
            entity.Property(value => value.OptionCode)
                .HasColumnName("SecenekKodu")
                .HasMaxLength(80)
                .IsRequired();

            entity.HasIndex(value => new { value.ApplicationId, value.QuestionCode })
                .IsUnique()
                .HasDatabaseName(
                    "UQ_BasvuruHaneCevaplari_BasvuruId_SoruKodu");
            entity.HasOne<CompanyApplicationRecord>()
                .WithMany()
                .HasForeignKey(value => value.ApplicationId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }

    private static void ConfigureFamilyMember(ModelBuilder builder)
    {
        builder.Entity<CompanyApplicationFamilyMemberRecord>(entity =>
        {
            entity.ToTable(
                "BasvuruAileFertleri",
                "dbo",
                table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.ApplicationId).HasColumnName("BasvuruId");
            entity.Property(value => value.FullName)
                .HasColumnName("AdSoyad")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.Age).HasColumnName("Yas");
            entity.Property(value => value.HasDisability).HasColumnName("EngelDurumu");
            entity.Property(value => value.DisabilityTypeId).HasColumnName("EngelTuruId");
            entity.Property(value => value.EmploymentStatusId).HasColumnName("CalismaDurumuId");
            entity.Property(value => value.EducationStatusId).HasColumnName("EgitimDurumuId");
            entity.Property(value => value.RelationshipId).HasColumnName("YakinlikId");

            entity.HasOne<CompanyApplicationRecord>()
                .WithMany()
                .HasForeignKey(value => value.ApplicationId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<RelationshipReference>()
                .WithMany()
                .HasForeignKey(value => value.RelationshipId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<EmploymentStatusReference>()
                .WithMany()
                .HasForeignKey(value => value.EmploymentStatusId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<EducationStatusReference>()
                .WithMany()
                .HasForeignKey(value => value.EducationStatusId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<DisabilityTypeReference>()
                .WithMany()
                .HasForeignKey(value => value.DisabilityTypeId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }

    private static void ConfigureHouseholdPhoto(ModelBuilder builder)
    {
        builder.Entity<CompanyHouseholdPhotoRecord>(entity =>
        {
            entity.ToTable(
                "HaneFotograflari",
                "dbo",
                table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.CitizenId).HasColumnName("VatandasId");
            entity.Property(value => value.PhotoPath)
                .HasColumnName("FotografYolu")
                .HasColumnType("nvarchar(max)")
                .IsRequired();
            entity.Property(value => value.Description)
                .HasColumnName("Aciklama")
                .HasColumnType("nvarchar(max)");
            entity.Property(value => value.UploadedAt).HasColumnName("YuklenmeTarihi");

            // Şirket snapshotındaki FK davranışı Cascade olduğu için birebir korunur.
            entity.HasOne<CompanyCitizenRecord>()
                .WithMany()
                .HasForeignKey(value => value.CitizenId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }

    private static void ConfigureReferences(ModelBuilder builder)
    {
        ConfigureReference<ApplicationStatusReference>(builder, "BasvuruDurumlari");
        ConfigureReference<HelpTypeReference>(builder, "YardimTurleri");
        ConfigureReference<DisabilityTypeReference>(builder, "EngelTurleri");
        ConfigureReference<RequestChannelReference>(builder, "TalepGelisKanallari");
        ConfigureReference<RelationshipReference>(builder, "Yakinliklar");
        ConfigureReference<EmploymentStatusReference>(builder, "CalismaDurumlari");
        ConfigureReference<EducationStatusReference>(builder, "EgitimDurumlari");
    }

    private static void ConfigureReference<TEntity>(
        ModelBuilder builder,
        string tableName)
        where TEntity : class, ICompanyReferenceSource
    {
        builder.Entity<TEntity>(entity =>
        {
            entity.ToTable(tableName, "dbo", table => table.ExcludeFromMigrations());
            entity.HasKey(value => value.Id);
            entity.Property(value => value.Id).HasColumnName("Id");
            entity.Property(value => value.Name).HasColumnName("Name").HasMaxLength(50);
            entity.Property(value => value.IsDeleted).HasColumnName("Sil");
        });
    }
}
