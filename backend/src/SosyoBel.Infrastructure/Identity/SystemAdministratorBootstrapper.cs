using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SosyoBel.Application.Administration;
using SosyoBel.Application.Authorization;

namespace SosyoBel.Infrastructure.Identity;

/// <summary>
/// İlk Cats sistem yöneticisini public bir HTTP endpoint açmadan oluşturur.
/// Tekrar çalıştırma mevcut hesabın parolasını veya profilini değiştirmez.
/// </summary>
internal sealed class SystemAdministratorBootstrapper(
    UserManager<ApplicationUser> userManager,
    RoleManager<IdentityRole> roleManager,
    AuthenticationDbContext dbContext,
    TimeProvider timeProvider) : ISystemAdministratorBootstrapper
{
    public async Task<SystemAdministratorBootstrapResult> BootstrapAsync(
        SystemAdministratorBootstrapInput input,
        CancellationToken cancellationToken)
    {
        if (!IsValid(input))
        {
            return new SystemAdministratorBootstrapResult(
                SystemAdministratorBootstrapStatus.InvalidInput,
                null,
                "Bootstrap alanları doğrulanamadı.");
        }

        var email = input.Email.Trim().ToLowerInvariant();

        try
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            var role = await roleManager.FindByNameAsync(RoleCodes.SystemAdministrator);
            if (role is null)
            {
                var roleResult = await roleManager.CreateAsync(new IdentityRole(
                    RoleCodes.SystemAdministrator));
                if (!roleResult.Succeeded)
                {
                    return IdentityFailure(roleResult);
                }
            }

            var existingAdministrators = await userManager.GetUsersInRoleAsync(
                RoleCodes.SystemAdministrator);
            var sameEmailUser = await userManager.FindByEmailAsync(email);

            if (existingAdministrators.Count > 0)
            {
                var isSingleMatchingActiveAdministrator =
                    existingAdministrators.Count == 1 &&
                    sameEmailUser is not null &&
                    sameEmailUser.IsActive &&
                    string.Equals(
                        existingAdministrators[0].Id,
                        sameEmailUser.Id,
                        StringComparison.Ordinal);

                await transaction.CommitAsync(cancellationToken);
                return isSingleMatchingActiveAdministrator
                    ? new SystemAdministratorBootstrapResult(
                        SystemAdministratorBootstrapStatus.AlreadyExists,
                        sameEmailUser!.Id,
                        "Sistem yöneticisi zaten mevcut; hiçbir bilgi değiştirilmedi.")
                    : new SystemAdministratorBootstrapResult(
                        SystemAdministratorBootstrapStatus.Conflict,
                        null,
                        "Başka veya tutarsız bir sistem yöneticisi kaydı mevcut; bootstrap kapalı kaldı.");
            }

            // Aynı e-posta başka bir amaçla kullanılıyorsa otomatik rol yükseltme yapılmaz.
            if (sameEmailUser is not null)
            {
                await transaction.CommitAsync(cancellationToken);
                return new SystemAdministratorBootstrapResult(
                    SystemAdministratorBootstrapStatus.Conflict,
                    null,
                    "E-posta mevcut ancak sistem yöneticisi rolünde değil; otomatik yükseltme yapılmadı.");
            }

            var administrator = ApplicationUser.Create(
                email,
                input.FirstName,
                input.LastName,
                timeProvider.GetUtcNow().UtcDateTime);
            var createResult = await userManager.CreateAsync(administrator, input.Password);
            if (!createResult.Succeeded)
            {
                return IdentityFailure(createResult);
            }

            var addRoleResult = await userManager.AddToRoleAsync(
                administrator,
                RoleCodes.SystemAdministrator);
            if (!addRoleResult.Succeeded)
            {
                return IdentityFailure(addRoleResult);
            }

            await transaction.CommitAsync(cancellationToken);
            return new SystemAdministratorBootstrapResult(
                SystemAdministratorBootstrapStatus.Created,
                administrator.Id,
                "İlk Cats sistem yöneticisi oluşturuldu.");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (DbUpdateException)
        {
            return new SystemAdministratorBootstrapResult(
                SystemAdministratorBootstrapStatus.Conflict,
                null,
                "Eşzamanlı bootstrap işlemiyle çakışma oluştu; veriler değiştirilmedi.");
        }
    }

    private static bool IsValid(SystemAdministratorBootstrapInput input) =>
        IsValidText(input.Email, 256) &&
        IsValidText(input.FirstName, 100) &&
        IsValidText(input.LastName, 100) &&
        !string.IsNullOrWhiteSpace(input.Password) &&
        input.Password.Length is >= 10 and <= 256;

    private static bool IsValidText(string value, int maxLength) =>
        !string.IsNullOrWhiteSpace(value) && value.Trim().Length <= maxLength;

    private static SystemAdministratorBootstrapResult IdentityFailure(
        IdentityResult identityResult) =>
        new(
            SystemAdministratorBootstrapStatus.InvalidInput,
            null,
            "Identity doğrulaması başarısız oldu.",
            identityResult.Errors
                .Select(error => error.Description)
                .Distinct(StringComparer.Ordinal)
                .ToArray());
}
