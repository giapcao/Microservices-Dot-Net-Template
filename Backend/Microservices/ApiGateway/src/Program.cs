using System.Collections;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MMLib.SwaggerForOcelot.DependencyInjection;
using Ocelot.DependencyInjection;
using Ocelot.Middleware;
using SharedLibrary.Authentication;
using SharedLibrary.Middleware;
using Microsoft.AspNetCore.HttpOverrides;

DotNetEnv.Env.Load();

var builder = WebApplication.CreateBuilder(args);

string GetEnv(string key, string def) => Environment.GetEnvironmentVariable(key) ?? def;
int GetEnvInt(string key, int def) => int.TryParse(Environment.GetEnvironmentVariable(key), out var v) ? v : def;

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedProto |
                               ForwardedHeaders.XForwardedHost;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var routes = new JsonArray();

string ToServiceSegment(string prefix)
{
    var lower = prefix.ToLowerInvariant();
    var parts = lower.Split(new[] { '_', '-' }, StringSplitOptions.RemoveEmptyEntries);
    return string.Concat(parts.Select(p => char.ToUpperInvariant(p[0]) + p.Substring(1)));
}

void AddRoute(string prefix, string serviceSegment, string host, int port)
{
    var swaggerKey = prefix.ToLowerInvariant();

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
        ["DownstreamPathTemplate"] = $"/api/{serviceSegment}/{{everything}}",
        ["SwaggerKey"] = swaggerKey
    });
}

var defaultServices = new[]
{
    new { Prefix = "USER",  Service = "User",  Host = "user-microservice",  Port = 5002 },
    new { Prefix = "GUEST", Service = "Guest", Host = "guest-microservice", Port = 5001 }
};

var addedServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var s in defaultServices)
{
    var envHost = Environment.GetEnvironmentVariable($"{s.Prefix}_MICROSERVICE_HOST");
    var envPortStr = Environment.GetEnvironmentVariable($"{s.Prefix}_MICROSERVICE_PORT");
    var host = string.IsNullOrWhiteSpace(envHost) ? s.Host : envHost;
    var port = int.TryParse(envPortStr, out var p) ? p : s.Port;

    AddRoute(s.Prefix, s.Service, host, port);
    addedServices.Add(s.Service);
}

var envVars = Environment.GetEnvironmentVariables();
var prefixes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (DictionaryEntry entry in envVars)
{
    var key = entry.Key?.ToString();
    if (string.IsNullOrEmpty(key)) continue;
    if (key.EndsWith("_MICROSERVICE_HOST", StringComparison.OrdinalIgnoreCase))
        prefixes.Add(key[..^"_MICROSERVICE_HOST".Length]);
    else if (key.EndsWith("_MICROSERVICE_PORT", StringComparison.OrdinalIgnoreCase))
        prefixes.Add(key[..^"_MICROSERVICE_PORT".Length]);
}

foreach (var prefix in prefixes)
{
    var serviceSegment = ToServiceSegment(prefix);
    if (addedServices.Contains(serviceSegment)) continue;

    var host = GetEnv($"{prefix}_MICROSERVICE_HOST", $"{prefix.ToLowerInvariant()}-microservice");
    var port = GetEnvInt($"{prefix}_MICROSERVICE_PORT", 80);

    AddRoute(prefix, serviceSegment, host, port);
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

var endpointData = new List<(string Key, string Name, string Url)>();
var addedSwaggerServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

foreach (var s in defaultServices)
{
    var envHost = Environment.GetEnvironmentVariable($"{s.Prefix}_MICROSERVICE_HOST");
    var envPortStr = Environment.GetEnvironmentVariable($"{s.Prefix}_MICROSERVICE_PORT");
    var host = string.IsNullOrWhiteSpace(envHost) ? s.Host : envHost;
    var port = int.TryParse(envPortStr, out var p) ? p : s.Port;

    var key = s.Prefix.ToLowerInvariant();
    var name = $"{s.Service} API";
    var url = $"http://{host}:{port}/swagger/v1/swagger.json";

    endpointData.Add((key, name, url));
    addedSwaggerServices.Add(s.Service);
}

foreach (var prefix in prefixes)
{
    var serviceSegment = ToServiceSegment(prefix);
    if (addedSwaggerServices.Contains(serviceSegment)) continue;

    var host = GetEnv($"{prefix}_MICROSERVICE_HOST", $"{prefix.ToLowerInvariant()}-microservice");
    var port = GetEnvInt($"{prefix}_MICROSERVICE_PORT", 80);

    var key = prefix.ToLowerInvariant();
    var name = $"{serviceSegment} API";
    var url = $"http://{host}:{port}/swagger/v1/swagger.json";

    endpointData.Add((key, name, url));
    addedSwaggerServices.Add(serviceSegment);
}

JsonArray BuildSwaggerEndpoints()
{
    var endpoints = new JsonArray();
    foreach (var (key, name, url) in endpointData)
    {
        endpoints.Add(new JsonObject
        {
            ["Key"] = key,
            ["TransformByOcelotConfig"] = true,
            ["Config"] = new JsonArray(new JsonObject
            {
                ["Name"] = name,
                ["Version"] = "v1",
                ["Url"] = url
            })
        });
    }
    return endpoints;
}

var swaggerConfig = new JsonObject
{
    ["SwaggerForOcelot"] = new JsonObject
    {
        ["SwaggerEndPoints"] = BuildSwaggerEndpoints()
    },
    ["SwaggerEndPoints"] = BuildSwaggerEndpoints()
};

var contentRoot = builder.Environment.ContentRootPath;
var ocelotFileName = "ocelot.runtime.json";
var swaggerFileName = "swagger.runtime.json";
var runtimeConfigPath = Path.Combine(contentRoot, ocelotFileName);
var swaggerConfigPath = Path.Combine(contentRoot, swaggerFileName);

File.WriteAllText(runtimeConfigPath, ocelotConfig.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
File.WriteAllText(swaggerConfigPath, swaggerConfig.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));

builder.Configuration
    .SetBasePath(contentRoot)
    .AddJsonFile(ocelotFileName, optional: false, reloadOnChange: true)
    .AddJsonFile(swaggerFileName, optional: false, reloadOnChange: true)
    .AddEnvironmentVariables();

builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerForOcelot(builder.Configuration);
builder.Services.AddOcelot(builder.Configuration);

bool enableSwaggerUi = string.Equals(
    Environment.GetEnvironmentVariable("ENABLE_SWAGGER_UI") ?? "false",
    "true",
    StringComparison.OrdinalIgnoreCase);

var app = builder.Build();

app.UseForwardedHeaders();

app.Use(async (ctx, next) =>
{
    var p = ctx.Request.Path.Value ?? "";
    if (p.Equals("/health", StringComparison.OrdinalIgnoreCase) ||
        p.Equals("/api/health", StringComparison.OrdinalIgnoreCase))
    {
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(new { status = "ok" }));
        return;
    }
    await next();
});

if (enableSwaggerUi || app.Environment.IsDevelopment())
{
    app.UseSwaggerForOcelotUI(
        ocelotUi =>
        {
            ocelotUi.PathToSwaggerGenerator = "/swagger/docs";
            ocelotUi.ReConfigureUpstreamSwaggerJson = AlterUpstreamSwaggerJson;
        },
        swaggerUi =>
        {
            swaggerUi.RoutePrefix = "swagger";
            swaggerUi.DocumentTitle = "API Gateway - Swagger";
            swaggerUi.ConfigObject.AdditionalItems["persistAuthorization"] = true;
        }
    );
}

app.UseWhen(ctx =>
    !ctx.Request.Path.StartsWithSegments("/swagger") &&
    !ctx.Request.Path.StartsWithSegments("/health") &&
    !ctx.Request.Path.StartsWithSegments("/api/health"),
    branch => branch.UseMiddleware<JwtMiddleware>());

await app.UseOcelot();
app.Run();

static string AlterUpstreamSwaggerJson(HttpContext context, string swaggerJson)
{
    var swagger = Newtonsoft.Json.JsonConvert.DeserializeObject<Newtonsoft.Json.Linq.JObject>(swaggerJson);
    if (swagger != null)
    {
        var servers = new Newtonsoft.Json.Linq.JArray
        {
            new Newtonsoft.Json.Linq.JObject
            {
                ["url"] = $"{context.Request.Scheme}://{context.Request.Host}"
            }
        };
        swagger["servers"] = servers;
        return swagger.ToString();
    }
    return swaggerJson;
}
