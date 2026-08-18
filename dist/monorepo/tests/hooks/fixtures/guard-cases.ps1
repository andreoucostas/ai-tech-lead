# Shared guard fixture library -- one case table consumed by BOTH Guard.Tests.ps1 (single-surface
# behaviour) and TwinParity.Tests.ps1 (.ps1 vs .sh same-decision). Each case is content-only; the
# harness's New-ClaudeEvent / New-CopilotEvent wrap it into each surface's field names, so the twins
# and surfaces all receive identical logical input.
$GuardCases = @(
    @{ n='cs #pragma warning disable';         f='src/Foo.cs';                c='#pragma warning disable CS8602';                       block=$true }
    @{ n='cs [Fact(Skip=...)]';                f='tests/FooTests.cs';         c='[Fact(Skip="flaky")] public void T(){}';               block=$true }
    @{ n='cs NUnit [Test, Ignore(...)]';       f='tests/FooTests.cs';         c='[Test, Ignore("flaky")] public void T(){}';            block=$true }
    @{ n='cs MSTest [Ignore] attribute';       f='tests/FooTests.cs';         c='[Ignore]';                                             block=$true }
    @{ n='cs NUnit [TestCase(.. Ignore = ..)]';f='tests/FooTests.cs';         c='[TestCase(1, Ignore = "flaky")]';                      block=$true }
    @{ n='cs Assert.True(true) tautology';     f='tests/FooTests.cs';         c='Assert.True(true);';                                   block=$true }
    @{ n='ts eslint-disable';                  f='src/app.ts';                c='// eslint-disable-next-line';                          block=$true }
    @{ n='ts @ts-ignore';                      f='src/app.ts';                c='// @ts-ignore';                                        block=$true }
    @{ n='spec fit() focused';                 f='src/app.spec.ts';           c="fit('x', () => { expect(1).toBe(1); });";              block=$true }
    @{ n='spec xit() skipped';                 f='src/app.spec.ts';           c="xit('x', () => {});";                                  block=$true }
    @{ n='spec expect(true).toBe(true)';       f='src/app.spec.ts';           c='expect(true).toBe(true);';                             block=$true }
    @{ n='mixed-case .CS filename routes';     f='src/Foo.CS';                c='#pragma warning disable CS8602';                       block=$true }
    @{ n='uppercase .TS filename routes';      f='src/app.TS';                c='// eslint-disable-next-line';                          block=$true }
    @{ n='uppercase .SPEC.TS filename routes'; f='src/app.SPEC.TS';           c="fit('x', () => {});";                                  block=$true }
    @{ n='multiline C# test class';            f='tests/WholeFileTests.cs';   c="using Xunit;`npublic class WholeFileTests`n{`n    [Fact(Skip=`"flaky`")]`n    public void T() { }`n}"; block=$true }
    @{ n='multiline TS spec';                  f='src/whole.spec.ts';         c="describe('whole', () => {`n  xit('skipped', () => {});`n});"; block=$true }
    @{ n='offending construct mid-file';       f='src/middle.ts';             c="const before = 1;`n// eslint-disable-next-line`nconst after = 2;"; block=$true }
    @{ n='secret AWS access key id';           f='src/deploy.cs';             c='var k = "AKIAIOSFODNN7EXAMPLE";';                       block=$true }
    @{ n='classic GitHub ghp token';           f='src/deploy.cs';             c='var t = "ghp_0123456789abcdefghijklmnopqrstuvwxyz";';   block=$true }
    @{ n='classic GitHub gho token';           f='src/deploy.cs';             c='var t = "gho_0123456789abcdefghijklmnopqrstuvwxyz";';   block=$true }
    @{ n='classic GitHub ghu token';           f='src/deploy.cs';             c='var t = "ghu_0123456789abcdefghijklmnopqrstuvwxyz";';   block=$true }
    @{ n='classic GitHub ghs token';           f='src/deploy.cs';             c='var t = "ghs_0123456789abcdefghijklmnopqrstuvwxyz";';   block=$true }
    @{ n='classic GitHub ghr token';           f='src/deploy.cs';             c='var t = "ghr_0123456789abcdefghijklmnopqrstuvwxyz";';   block=$true }
    @{ n='fine-grained GitHub token';          f='src/deploy.cs';             c='var t = "github_pat_1234567890123456789012_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567";'; block=$true }
    @{ n='secret private key block';           f='src/deploy.cs';             c='-----BEGIN RSA PRIVATE KEY-----';                       block=$true }
    @{ n='hardcoded credential literal';       f='src/AuthService.cs';        c='var password = "hunter2hunter2";';                     block=$true }
    @{ n='connection string Password';         f='src/AuthService.cs';        c='var connectionString = "Server=db;User Id=sa;Password=hunter2;Database=app";'; block=$true }
    @{ n='connection string URI userinfo';     f='src/AuthService.cs';        c='var connectionString = "postgres://user:hunter2@host/db";'; block=$true }

    @{ n='clean .cs (allow)';                  f='src/Foo.cs';                c='public int Add(int a, int b) => a + b;';               block=$false }
    @{ n='clean .spec.ts real assertion';      f='src/app.spec.ts';           c="it('adds', () => { expect(add(1,2)).toBe(3); });";     block=$false }
    @{ n='RxJS skip() not a test-skip';        f='src/stream.spec.ts';        c='source$.pipe(skip(1)).subscribe();';                   block=$false }
    @{ n='cs [JsonIgnore] near-miss (allow)';  f='src/Dto.cs';                c='[JsonIgnore] public int Id { get; set; }';             block=$false }
    @{ n='cs enum Ignore member (allow)';      f='src/Mode.cs';               c='public enum Mode { None, Ignore, All }';               block=$false }
    @{ n='cs lowercase ignore arg (allow)';    f='src/Handler.cs';            c='Handle(evt, ignore, ctx);';                            block=$false }
    @{ n='cs NUnit [Explicit] (allow by design)'; f='tests/FooTests.cs';      c='[Test, Explicit] public void T(){}';                   block=$false }
    @{ n='credential in *Tests* file (allow)'; f='tests/AuthServiceTests.cs'; c='var password = "hunter2hunter2";';                     block=$false }
    @{ n='passwordless connection string';     f='src/AuthService.cs';        c='var connectionString = "Server=localhost;Trusted_Connection=True";'; block=$false }
    @{ n='near-miss fine-grained PAT';         f='src/deploy.cs';             c='var t = "github_pat_too_short";';                       block=$false }
    @{ n='case-sensitive ASSERT near-miss';    f='tests/FooTests.cs';         c='ASSERT.True(true);';                                   block=$false }
    @{ n='case-sensitive ESLINT near-miss';    f='src/app.ts';                c='// ESLINT-DISABLE-next-line';                          block=$false }
)
