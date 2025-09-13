using Ocelot.DependencyInjection;
using Ocelot.Middleware;
using System.Collections;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using SharedLibrary.Authentication;
using SharedLibrary.Middleware;

DotNetEnv.Env.Load();

var builder = WebApplication.CreateBuilder(args);

// Helper accessors with defaults
string GetEnv(string key, string def) => Environment.GetEnvironmentVariable(key) ?? def;
int GetEnvInt(string key, int def) => int.TryParse(Environment.GetEnvironmentVariable(key), out var v) ? v : def;

// Build Ocelot configuration dynamically from environment variables
var routes = new JsonArray();

// Helper to convert ENV prefix (e.g., USER, ORDER_HISTORY) into path segment (User, OrderHistory)
string ToServiceSegment(string prefix)
{
    var lower = prefix.ToLowerInvariant();
    var parts = lower.Split(new[] { '_', '-' }, StringSplitOptions.RemoveEmptyEntries);
    return string.Concat(parts.Select(p => char.ToUpperInvariant(p[0]) + p.Substring(1)));
}

void AddRoute(string serviceSegment, string host, int port)
{
    routes.Add(new JsonObject
    {
        ["UpstreamPathTemplate"] = $"/api/{serviceSegment}/{{everything}}",
        ["UpstreamHttpMethod"] = new JsonArray("Get", "Post", "Put", "Delete"),
        ["DownstreamScheme"] = "http",
        ["DownstreamHostAndPorts"] = new JsonArray(new JsonObject
        {
            ["Host"] = host,
            ["Port"] = port
        }),
        ["DownstreamPathTemplate"] = $"/api/{serviceSegment}/{{everything}}"
    });
}

// Defaults when ENV is not provided
var defaultServices = new[]
{
    new { Prefix = "USER", Service = "User", Host = "user-microservice", Port = 5002 },
    new { Prefix = "GUEST", Service = "Guest", Host = "guest-microservice", Port = 5001 }
};

// Track added services to prevent duplicates
var addedServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

// 1) Add defaults first (can be overridden by ENV later)
foreach (var s in defaultServices)
{
    var envHost = Environment.GetEnvironmentVariable($"{s.Prefix}_MICROSERVICE_HOST");
    var envPortStr = Environment.GetEnvironmentVariable($"{s.Prefix}_MICROSERVICE_PORT");
    var host = string.IsNullOrWhiteSpace(envHost) ? s.Host : envHost;
    var port = int.TryParse(envPortStr, out var p) ? p : s.Port;
    AddRoute(s.Service, host, port);
    addedServices.Add(s.Service);
}

// 2) Discover any additional services from ENV
var envVars = Environment.GetEnvironmentVariables();
var prefixes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (DictionaryEntry entry in envVars)
{
    var key = entry.Key?.ToString();
    if (string.IsNullOrEmpty(key)) continue;
    if (key.EndsWith("_MICROSERVICE_HOST", StringComparison.OrdinalIgnoreCase))
    {
        prefixes.Add(key[..^"_MICROSERVICE_HOST".Length]);
    }
    else if (key.EndsWith("_MICROSERVICE_PORT", StringComparison.OrdinalIgnoreCase))
    {
        prefixes.Add(key[..^"_MICROSERVICE_PORT".Length]);
    }
}

foreach (var prefix in prefixes)
{
    var serviceSegment = ToServiceSegment(prefix);
    if (addedServices.Contains(serviceSegment))
    {
        // Already added via defaults above; defaults already considered ENV override.
        continue;
    }

    var host = GetEnv($"{prefix}_MICROSERVICE_HOST", $"{prefix.ToLowerInvariant()}-microservice");
    var port = GetEnvInt($"{prefix}_MICROSERVICE_PORT", 80);
    AddRoute(serviceSegment, host, port);
    addedServices.Add(serviceSegment);
}

var ocelotConfig = new JsonObject
{
    ["Routes"] = routes,
    ["GlobalConfiguration"] = new JsonObject
    {
        ["BaseUrl"] = GetEnv("BASE_URL", "http://localhost:2406")
    }
};

// Persist generated config to a runtime file and load it
var runtimeConfigPath = Path.Combine(builder.Environment.ContentRootPath, "ocelot.runtime.json");
File.WriteAllText(runtimeConfigPath, ocelotConfig.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

builder.Configuration
    .SetBasePath(builder.Environment.ContentRootPath)
    .AddJsonFile(runtimeConfigPath, optional: false, reloadOnChange: true)
    .AddEnvironmentVariables();

// Add authentication services
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();

builder.Services.AddOcelot(builder.Configuration);

var app = builder.Build();

// Add JWT middleware
app.UseMiddleware<JwtMiddleware>();

// Short-circuit health endpoints BEFORE Ocelot so they don't go through Ocelot pipeline
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value;
    if (string.Equals(path, "/health", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(path, "/api/health", StringComparison.OrdinalIgnoreCase))
    {
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(JsonSerializer.Serialize(new { status = "ok" }));
        return;
    }

    await next();
});

await app.UseOcelot();
app.Run();
