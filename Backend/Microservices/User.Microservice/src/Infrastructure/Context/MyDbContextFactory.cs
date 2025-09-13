using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace Infrastructure.Context;

public class MyDbContextFactory : IDesignTimeDbContextFactory<MyDbContext>
{
    public MyDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<MyDbContext>();
        
        // Use production connection string for migrations
        var connectionString = "Host=pg-2-database25812.g.aivencloud.com;Port=19217;Database=defaultdb;Username=avnadmin;Password=AVNS_vsIotPLRrxJUhcJlM0m;SslMode=Require";
        optionsBuilder.UseNpgsql(connectionString);
        
        return new MyDbContext(optionsBuilder.Options);
    }
}

