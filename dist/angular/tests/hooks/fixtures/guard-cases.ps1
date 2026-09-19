# Shared guard fixture library. Each case is content-only; the harness's New-ClaudeEvent /
# New-CopilotEvent wrap it into each surface's field names, so both supported surfaces receive
# identical logical input.
$azureKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8' + 'gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+Pw' + '=='
$GuardCases = @(
    @{ n='cs #pragma warning disable';         f='src/Foo.cs';                c='#pragma warning disable CS8602';                       block=$true; policy='test-defeat/suppression' }
    @{ n='cs [Fact(Skip=...)]';                f='tests/FooTests.cs';         c='[Fact(Skip="flaky")] public void T(){}';               block=$true }
    # MULTI-LINE ATTRIBUTE LISTS. The table had no multi-line content at all, which is why a real
    # a historical implementation divergence survived: .NET's [^]]* spans a newline, while a
    # line-oriented implementation allowed the split forms. These cases preserve the fixed
    # PowerShell behavior. Measured 2026-08-22.
    # The third case is the one that matters most: a legitimate split attribute list must still pass,
    # because a false positive on correct work is what teaches people to bypass the guard entirely.
    @{ n='cs [Test,<nl>Ignore(...)] split';    f='tests/FooTests.cs'; c="[Test,`n Ignore(`"flaky`")] public void T(){}";                          block=$true }
    @{ n='cs [Fact(<nl>Skip=...)] split';      f='tests/FooTests.cs'; c="[Fact(`n  Skip=`"flaky`")] public void T(){}";                           block=$true }
    @{ n='cs legit split attribute list';      f='tests/FooTests.cs'; c="[Theory,`n InlineData(1),`n InlineData(2)] public void T(int x){}";      block=$false }
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
    @{ n='secret private key block';           f='src/deploy.cs';             c='-----BEGIN RSA PRIVATE KEY-----';                       block=$true; policy='secret' }
    @{ n='hardcoded credential literal';       f='src/AuthService.cs';        c='var password = "hunter2hunter2";';                     block=$true }
    @{ n='connection string Password';         f='src/AuthService.cs';        c='var connectionString = "Server=db;User Id=sa;Password=hunter2;Database=app";'; block=$true }
    @{ n='connection string URI userinfo';     f='src/AuthService.cs';        c='var connectionString = "postgres://user:hunter2@host/db";'; block=$true }
    # The test/sample exemption is anchored to whole path tokens: "test" inside Latest and "spec"
    # inside Specification no longer exempt production code from the credential check.
    # $azureKey is assembled from two halves at load time: a literal 88-character key in the
    # committed bytes is rejected by GitHub push protection as an Azure Storage account key
    # (observed 2026-09-20), the same reason the OutgoingCommits fixture builds its token at runtime.
    @{ n='credential in LatestRatesClient.cs'; f='src/LatestRatesClient.cs';  c='var password = "hunter2hunter2";';                     block=$true }
    @{ n='credential in Specification.cs';     f='src/Specification.cs';      c='var password = "hunter2hunter2";';                     block=$true }
    @{ n='Azure storage AccountKey';           f='src/Storage.cs';            c="var cs = `"DefaultEndpointsProtocol=https;AccountName=acct;AccountKey=$azureKey;EndpointSuffix=core.windows.net`";"; block=$true }
    @{ n='Azure AccountKey in a test path';    f='tests/StorageTests.cs';     c="var cs = `"AccountName=acct;AccountKey=$azureKey`";"; block=$true }
    @{ n='Azure SAS token sig=';               f='src/Storage.cs';            c='var url = "https://acct.blob.core.windows.net/c/b?sv=2022-11-02&ss=b&srt=o&sp=r&se=2026-01-01T00:00:00Z&sig=AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8%3D";'; block=$true }

    @{ n='clean .cs (allow)';                  f='src/Foo.cs';                c='public int Add(int a, int b) => a + b;';               block=$false }
    @{ n='clean .spec.ts real assertion';      f='src/app.spec.ts';           c="it('adds', () => { expect(add(1,2)).toBe(3); });";     block=$false }
    @{ n='RxJS skip() not a test-skip';        f='src/stream.spec.ts';        c='source$.pipe(skip(1)).subscribe();';                   block=$false }
    @{ n='cs [JsonIgnore] near-miss (allow)';  f='src/Dto.cs';                c='[JsonIgnore] public int Id { get; set; }';             block=$false }
    @{ n='cs enum Ignore member (allow)';      f='src/Mode.cs';               c='public enum Mode { None, Ignore, All }';               block=$false }
    @{ n='cs lowercase ignore arg (allow)';    f='src/Handler.cs';            c='Handle(evt, ignore, ctx);';                            block=$false }
    @{ n='cs NUnit [Explicit] (allow by design)'; f='tests/FooTests.cs';      c='[Test, Explicit] public void T(){}';                   block=$false }
    @{ n='credential in *Tests* file (allow)'; f='tests/AuthServiceTests.cs'; c='var password = "hunter2hunter2";';                     block=$false }
    @{ n='credential in Api.UnitTests dir (allow)'; f='src/Api.UnitTests/AuthClient.cs'; c='var password = "hunter2hunter2";';           block=$false }
    @{ n='credential in __mocks__ (allow)';    f='src/__mocks__/auth.ts';     c="const password = 'hunter2hunter2';";                   block=$false }
    @{ n='credential in appsettings.Development.json (allow)'; f='src/Api/appsettings.Development.json'; c='"Password": "hunter2hunter2"'; block=$false }
    @{ n='Azurite well-known dev key (allow)'; f='src/Storage.cs';            c='var cs = "AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==";'; block=$false }
    @{ n='SAS sig= without a token (allow)';   f='src/Storage.cs';            c='var q = "?sv=2022-11-02&sig=";';                        block=$false }
    @{ n='passwordless connection string';     f='src/AuthService.cs';       c='var connectionString = "Server=localhost;Trusted_Connection=True";'; block=$false }
    @{ n='near-miss fine-grained PAT';         f='src/deploy.cs';             c='var t = "github_pat_too_short";';                       block=$false }
    # Tagged `secret` so the invalid-regex red test observes both fail-closed directions: the
    # private-key case must still block, while this near-miss must turn red if every secret probe
    # is conservatively blocked. A policy filter containing only blocking cases is an inert oracle.
    @{ n='public key block near-miss';          f='src/deploy.cs';             c='-----BEGIN PUBLIC KEY-----';                            block=$false; policy='secret' }
    @{ n='case-sensitive ASSERT near-miss';    f='tests/FooTests.cs';         c='ASSERT.True(true);';                                   block=$false }
    @{ n='case-sensitive ESLINT near-miss';    f='src/app.ts';                c='// ESLINT-DISABLE-next-line';                          block=$false }
)
