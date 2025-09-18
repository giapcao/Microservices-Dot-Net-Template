using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Infrastructure.Context;

public class MyDbContextFactory : IDesignTimeDbContextFactory<MyDbContext>
{
    public MyDbContext CreateDbContext(string[] args)
    {
        string? connectionString = null;
        foreach (var arg in args)
        {
            const string prefix = "--connection-string=";
            if (arg.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            {
                connectionString = arg.Substring(prefix.Length).Trim('"');
                break;
            }
        }

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            var host = Environment.GetEnvironmentVariable("DATABASE_HOST") ?? "localhost";
            var port = Environment.GetEnvironmentVariable("DATABASE_PORT") ?? "5432";
            var database = Environment.GetEnvironmentVariable("DATABASE_NAME") ?? "userservice_db";
            var username = Environment.GetEnvironmentVariable("DATABASE_USERNAME") ?? "postgres";
            var password = Environment.GetEnvironmentVariable("DATABASE_PASSWORD") ?? "password";
            var sslMode = Environment.GetEnvironmentVariable("DATABASE_SSLMODE") ?? "Prefer";
            connectionString = $"Host={host};Port={port};Database={database};Username={username};Password={password};SslMode={sslMode}";
        }

        var optionsBuilder = new DbContextOptionsBuilder<MyDbContext>();
        optionsBuilder.UseNpgsql(connectionString!);
        return new MyDbContext(optionsBuilder.Options);
    }
}

