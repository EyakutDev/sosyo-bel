using Microsoft.EntityFrameworkCore;

namespace SosyoBel.Infrastructure.Persistence;

/// <summary>
/// Şirketin değiştirilemeyen dbo başvuru şemasını izole biçimde kullanan çalışma
/// zamanı contextidir. Bütün tablolar migration dışında bırakıldığı için API
/// şirket veritabanında CREATE veya ALTER üretmez.
/// </summary>
internal sealed class CompanyApplicationDbContext(
    DbContextOptions<CompanyApplicationDbContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        CompanyApplicationModelConfiguration.Configure(modelBuilder);
    }
}
