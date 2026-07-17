# Shared guard fixture library -- one case table consumed by BOTH Guard.Tests.ps1 (single-surface
# behaviour) and TwinParity.Tests.ps1 (.ps1 vs .sh same-decision). Each case is content-only; the
# harness's New-ClaudeEvent / New-CopilotEvent wrap it into each surface's field names, so the twins
# and surfaces all receive identical logical input.
$GuardCases = @(
    @{ n='cs #pragma warning disable';         f='src/Foo.cs';                c='#pragma warning disable CS8602';                       block=$true }
    @{ n='cs [Fact(Skip=...)]';                f='tests/FooTests.cs';         c='[Fact(Skip="flaky")] public void T(){}';               block=$true }
    @{ n='cs Assert.True(true) tautology';     f='tests/FooTests.cs';         c='Assert.True(true);';                                   block=$true }
    @{ n='ts eslint-disable';                  f='src/app.ts';                c='// eslint-disable-next-line';                          block=$true }
    @{ n='ts @ts-ignore';                      f='src/app.ts';                c='// @ts-ignore';                                        block=$true }
    @{ n='spec fit() focused';                 f='src/app.spec.ts';           c="fit('x', () => { expect(1).toBe(1); });";              block=$true }
    @{ n='spec xit() skipped';                 f='src/app.spec.ts';           c="xit('x', () => {});";                                  block=$true }
    @{ n='spec expect(true).toBe(true)';       f='src/app.spec.ts';           c='expect(true).toBe(true);';                             block=$true }
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
    @{ n='credential in *Tests* file (allow)'; f='tests/AuthServiceTests.cs'; c='var password = "hunter2hunter2";';                     block=$false }
    @{ n='passwordless connection string';     f='src/AuthService.cs';        c='var connectionString = "Server=localhost;Trusted_Connection=True";'; block=$false }
    @{ n='near-miss fine-grained PAT';         f='src/deploy.cs';             c='var t = "github_pat_too_short";';                       block=$false }
)
