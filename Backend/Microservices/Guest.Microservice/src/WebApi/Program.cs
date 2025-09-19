using Application;
using Infrastructure;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models;
using Serilog;
using SharedLibrary.Configs;
using SharedLibrary.Middleware;
using SharedLibrary.Utils;

var solutionDirectory = Directory.GetParent(Directory.GetCurrentDirectory())?.FullName ?? "";
if (!string.IsNullOrWhiteSpace(solutionDirectory))
{
    DotNetEnv.Env.Load(Path.Combine(solutionDirectory, ".env"));
}

AutoScaffold.UpdateAppSettingsFile("appsettings.json", "default");
AutoScaffold.UpdateAppSettingsFile("appsettings.Development.json", "default");

var builder = WebApplication.CreateBuilder(args);
var environment = builder.Environment;

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Guest API",
        Version = "v1"
    });

    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        Scheme = "bearer",
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Description = "Paste your JWT token here (no need to type 'Bearer ').",
        Reference = new OpenApiReference
        {
            Id = "Bearer",
            Type = ReferenceType.SecurityScheme
        }
    };

    c.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { jwtSecurityScheme, Array.Empty<string>() }
    });

});

builder.Services.AddAuthorization();

builder.Host.UseSerilog((hostingContext, loggerConfiguration) =>
    loggerConfiguration.ReadFrom.Configuration(hostingContext.Configuration));

builder.Services.ConfigureOptions<DatabaseConfigSetup>();
builder.Services.AddDbContext<MyDbContext>((serviceProvider, options) =>
{
    var databaseConfig = serviceProvider.GetRequiredService<IOptions<DatabaseConfig>>().Value;
    options.UseNpgsql(databaseConfig.ConnectionString, actions =>
    {
        actions.EnableRetryOnFailure(databaseConfig.MaxRetryCount);
        actions.CommandTimeout(databaseConfig.CommandTimeout);
    });

    if (environment.IsDevelopment())
    {
        options.EnableDetailedErrors(databaseConfig.EnableDetailedErrors);
        options.EnableSensitiveDataLogging(databaseConfig.EnableSensitiveDataLogging);
    }
});

builder.Services
    .AddApplication()
    .AddInfrastructure();

var app = builder.Build();

app.MapGet("/health", () => new { status = "ok" });
app.MapGet("/api/health", () => new { status = "ok" });

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Guest API V1");
    c.RoutePrefix = "swagger";
});

if (app.Environment.IsDevelopment())
{
    app.MapGet("/", context =>
    {
        context.Response.Redirect("/swagger");
        return Task.CompletedTask;
    });
}

app.UseSerilogRequestLogging();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseMiddleware<JwtMiddleware>();

app.UseAuthorization();

app.MapControllers();

var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("Guest microservice started on port {Port}",
    Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "5001");

app.Run();
