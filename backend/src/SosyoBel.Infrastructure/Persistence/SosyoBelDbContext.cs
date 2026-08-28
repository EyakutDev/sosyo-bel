using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Başvuru servislerinin kalıcılık sınırıdır. Çoklu belediye modeli içermez.
/// Şirket dbo eşlemeleri ve mobil veri kararları ayrı yapılandırmada açıkça tanımlanır.
/// </summary>
public sealed class SosyoBelDbContext(DbContextOptions<SosyoBelDbContext> options)
    : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        ApplicationPersistenceModelConfiguration.Configure(modelBuilder);
    }
}
