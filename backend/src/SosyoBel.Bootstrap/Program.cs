using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SosyoBel.Application.Administration;
using SosyoBel.Infrastructure.Identity;

const string connectionVariable = "ConnectionStrings__SosyoBel";
const string emailVariable = "SOSYOBEL_BOOTSTRAP_EMAIL";
const string firstNameVariable = "SOSYOBEL_BOOTSTRAP_FIRST_NAME";
const string lastNameVariable = "SOSYOBEL_BOOTSTRAP_LAST_NAME";
const string passwordVariable = "SOSYOBEL_BOOTSTRAP_PASSWORD";

var connectionString = Environment.GetEnvironmentVariable(connectionVariable);
var email = Environment.GetEnvironmentVariable(emailVariable);
var firstName = Environment.GetEnvironmentVariable(firstNameVariable);
var lastName = Environment.GetEnvironmentVariable(lastNameVariable);
var password = Environment.GetEnvironmentVariable(passwordVariable);

if (string.IsNullOrWhiteSpace(password) && !Console.IsInputRedirected)
{
    Console.Error.Write("Bootstrap parolası: ");
    password = ReadHiddenPassword();
}

if (string.IsNullOrWhiteSpace(connectionString) ||
    string.IsNullOrWhiteSpace(email) ||
    string.IsNullOrWhiteSpace(firstName) ||
    string.IsNullOrWhiteSpace(lastName) ||
    string.IsNullOrWhiteSpace(password))
{
    Console.Error.WriteLine(
        "Bağlantı/e-posta/ad/soyad değişkenleri ve parola (env veya gizli giriş) zorunludur.");
    return 2;
}

var configuration = new ConfigurationManager
{
    ["ConnectionStrings:SosyoBel"] = connectionString,
};

var services = new ServiceCollection();
services.AddLogging();
services.AddSosyoBelIdentity(configuration);

await using var serviceProvider = services.BuildServiceProvider();
await using var scope = serviceProvider.CreateAsyncScope();
var bootstrapper = scope.ServiceProvider.GetRequiredService<
    ISystemAdministratorBootstrapper>();

var result = await bootstrapper.BootstrapAsync(
    new SystemAdministratorBootstrapInput(email, firstName, lastName, password),
    CancellationToken.None);

// Parola ve bağlantı bilgisi hiçbir koşulda terminal çıktısına yazılmaz.
Console.WriteLine(result.Message);
if (result.Errors is { Count: > 0 })
{
    foreach (var error in result.Errors)
    {
        Console.Error.WriteLine(error);
    }
}

return result.Status switch
{
    SystemAdministratorBootstrapStatus.Created => 0,
    SystemAdministratorBootstrapStatus.AlreadyExists => 0,
    SystemAdministratorBootstrapStatus.InvalidInput => 2,
    _ => 3,
};

static string ReadHiddenPassword()
{
    var passwordBuilder = new StringBuilder();
    while (true)
    {
        var key = Console.ReadKey(intercept: true);
        if (key.Key == ConsoleKey.Enter)
        {
            Console.Error.WriteLine();
            return passwordBuilder.ToString();
        }

        if (key.Key == ConsoleKey.Backspace && passwordBuilder.Length > 0)
        {
            passwordBuilder.Length--;
        }
        else if (!char.IsControl(key.KeyChar))
        {
            passwordBuilder.Append(key.KeyChar);
        }
    }
}
