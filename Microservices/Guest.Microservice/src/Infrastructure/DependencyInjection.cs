using System;
using Infrastructure.Utils;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Infrastructure.Configs;
using Domain.Repositories;
using Infrastructure.Repositories;
using Application.Abstractions.UnitOfWork;
using Domain.Common;
using Infrastructure.Common;
using MassTransit;
using Application.Consumers;

namespace Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructure(this IServiceCollection services)
        {

            services.AddScoped<IGuestRepository, GuestRepository>();
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
            services.AddSingleton<EnvironmentConfig>();
            var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
            using var serviceProvider = services.BuildServiceProvider();
            var logger = serviceProvider.GetRequiredService<ILogger<AutoScaffold>>();
            var config = serviceProvider.GetRequiredService<EnvironmentConfig>();
            var scaffold = new AutoScaffold(logger)
                .Configure(
                    config.DatabaseHost,
                    config.DatabasePort,
                    config.DatabaseName,
                    config.DatabaseUser,
                    config.DatabasePassword,
                    config.DatabaseProvider);

            scaffold.UpdateAppSettings();
            string solutionDirectory = Directory.GetParent(Directory.GetCurrentDirectory())?.FullName ?? "";
            if (solutionDirectory != null)
            {
                DotNetEnv.Env.Load(Path.Combine(solutionDirectory, ".env"));
            }
            services.AddMassTransit(busConfigurator => {
                busConfigurator.SetKebabCaseEndpointNameFormatter();
                busConfigurator.AddConsumer<UserCreatedConsumer>();
                busConfigurator.UsingRabbitMq((context, configurator) =>{
                    configurator.Host(new Uri($"rabbitmq://{config.RabbitMqHost}:{config.RabbitMqPort}/"), h=>{
                        h.Username(config.RabbitMqUser);
                        h.Password(config.RabbitMqPassword);
                    });
                    configurator.ConfigureEndpoints(context);
                });
                
            });

            if (environment == "Development")
            {

                var autoMigration = new AutoMigration(logger);

                string currentHash = SchemaComparer.GenerateDatabaseSchemaHash(
                    config.DatabaseHost,
                    config.DatabasePort,
                    config.DatabaseName,
                    config.DatabaseUser,
                    config.DatabasePassword
                );

                if (!SchemaComparer.TryGetStoredHash(out string storedHash) || currentHash != storedHash)
                {
                    logger.LogInformation("Database schema has changed. Performing scaffolding...");
                    SchemaComparer.SaveHash(currentHash);
                    scaffold.Run();
                    SchemaComparer.SetMigrationRequired(true);
                }
                else if (Environment.GetEnvironmentVariable("IS_SCAFFOLDING") != "true")
                {
                    if (SchemaComparer.IsMigrationRequired())
                    {
                        autoMigration.GenerateMigration();
                    }
                    SchemaComparer.SetMigrationRequired(false);
                }
            }
            return services;
        }
    }
}