using Application;
using Infrastructure;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models; // <<— for JWT in Swagger
using Serilog;
using SharedLibrary.Configs;
using SharedLibrary.Middleware;
using SharedLibrary.Utils;

var solutionDirectory = Directory.GetParent(Directory.GetCurrentDirectory())?.FullName ?? "";
if (solutionDirectory != null)
{
    DotNetEnv.Env.Load(Path.Combine(solutionDirectory, ".env"));
}

// Update appsettings files before building the app
AutoScaffold.UpdateAppSettingsFile("appsettings.json", "default");
AutoScaffold.UpdateAppSettingsFile("appsettings.Development.json", "default");

var builder = WebApplication.CreateBuilder(args);
var environment = builder.Environment;

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// --- Swagger with JWT "Authorize" button ---
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "User API",
        Version = "v1"
    });

    // Add the JWT bearer definition so Swagger UI shows the "Authorize" button
    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        Scheme = "bearer",
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Description = "Put **_ONLY_** your JWT token here (no need to type 'Bearer ').",
        Reference = new OpenApiReference
        {
            Id = "Bearer",
            Type = ReferenceType.SecurityScheme
        }
    };

    c.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);

    // Apply the bearer auth globally to all operations.
    // (If you want to require it only on [Authorize] endpoints, add an IOperationFilter that checks attributes.)
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

// Health check endpoints
app.MapGet("/health", () => new { status = "ok" });
app.MapGet("/api/health", () => new { status = "ok" });

// Always enable Swagger in microservices; gateway controls external exposure
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "User API V1");
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

// Only use HTTPS redirection in production with proper certificates
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// Your custom JWT middleware validates token and sets HttpContext.User
app.UseMiddleware<JwtMiddleware>();

app.UseAuthorization();

app.MapControllers();

// Log startup information
var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("User microservice started on port {Port}",
    Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "5002");

app.Run();
