using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirket lookup tablolarındaki sayısal kimlikleri, mobil API'nin değişmez
/// kodlarıyla birleştiren ortak sorguları içerir.
/// </summary>
internal static class ApplicationReferenceCodeQueries
{
    public const string ApplicationStatus = "BASVURU_DURUMU";
    public const string EmploymentStatus = "CALISMA_DURUMU";
    public const string EducationStatus = "EGITIM_DURUMU";
    public const string DisabilityType = "ENGEL_TURU";
    public const string RequestChannel = "TALEP_GELIS_KANALI";
    public const string Relationship = "YAKINLIK";
    public const string HelpType = "YARDIM_TURU";

    public static IQueryable<ReferenceCodeRecord> Mapped<TSource>(
        this DbContext context,
        string referenceTypeCode)
        where TSource : class, ICompanyReferenceSource =>
        from mapping in context.Set<ReferenceCodeRecord>().AsNoTracking()
        join source in context.Set<TSource>().AsNoTracking()
            on mapping.SourceId equals source.Id
        where mapping.ReferenceTypeCode == referenceTypeCode
        select mapping;

    public static IQueryable<ReferenceCodeRecord> Active<TSource>(
        this DbContext context,
        string referenceTypeCode)
        where TSource : class, ICompanyReferenceSource =>
        from mapping in context.Set<ReferenceCodeRecord>().AsNoTracking()
        join source in context.Set<TSource>().AsNoTracking()
            on mapping.SourceId equals source.Id
        where mapping.ReferenceTypeCode == referenceTypeCode &&
              !source.IsDeleted
        select mapping;
}
