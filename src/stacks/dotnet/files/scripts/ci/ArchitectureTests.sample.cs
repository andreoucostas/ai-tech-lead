// Sample NetArchTest architecture tests — copy into your test project and adjust the namespaces.
// Makes SOLID's dependency-direction (DIP / Clean Architecture) a BUILD-BREAKING gate, complementing
// the semantic `solid-check` agent. Requires the `NetArchTest.Rules` NuGet package.
//
// Scaffolded by the `enforce-architecture` skill. See CLAUDE.md > SOLID.
using NetArchTest.Rules;
using Xunit;

public class ArchitectureTests
{
    // Adjust to your solution's root namespaces.
    private const string Domain = "MyApp.Domain";
    private const string Application = "MyApp.Application";
    private const string Infrastructure = "MyApp.Infrastructure";
    private const string Api = "MyApp.Api";

    [Fact]
    public void Domain_should_not_depend_on_outer_layers()
    {
        var result = Types.InCurrentDomain()
            .That().ResideInNamespace(Domain)
            .ShouldNot().HaveDependencyOnAny(Application, Infrastructure, Api)
            .GetResult();

        Assert.True(result.IsSuccessful,
            "Domain depends on an outer layer: " + string.Join(", ", result.FailingTypeNames ?? new string[0]));
    }

    [Fact]
    public void Application_should_not_depend_on_infrastructure_or_api()
    {
        var result = Types.InCurrentDomain()
            .That().ResideInNamespace(Application)
            .ShouldNot().HaveDependencyOnAny(Infrastructure, Api)
            .GetResult();

        Assert.True(result.IsSuccessful,
            "Application depends on Infrastructure/API: " + string.Join(", ", result.FailingTypeNames ?? new string[0]));
    }
}
