# Shared guard fixture library. Each case is content-only; the harness's New-ClaudeEvent /
# New-CopilotEvent wrap it into each surface's field names, so both supported surfaces receive
# identical logical input.
$azureKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8' + 'gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+Pw' + '=='
# Synthetic sk- keys, assembled from halves for the same reason as $azureKey.
$openAiKey    = 'sk-proj-' + 'Qx7RkP2mVt9LwZ4nHc8JdB3sFy6GaE1u' + 'Ko5TiN0rXj2WqM7vLp4ShD9gCz3YbU8e'
$anthropicKey = 'sk-ant-api03-' + 'Hn4Rk8PqZ2xVt6LmW9cJ3dBsF7yGa1uE' + 'o5TiK0rNj2XqM7vLp4ShD9gCz3YbU8eQ'
# System.Text.Json's default escape for a quote, built in two pieces so no tool unescapes it.
$u22 = '\u' + '0022'
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
    # Vitest (the Angular unit-test builder's default runner from v21, which runs *.spec.* and *.test.*),
    # Jest, Mocha/Cypress and Playwright focus and skip forms, chained ones included; Cypress specs are *.cy.*.
    @{ n='spec test.only() focused';           f='src/app.spec.ts';           c="test.only('x', () => { expect(1).toBe(1); });";        block=$true }
    @{ n='spec suite.only() focused';          f='src/app.spec.ts';           c="suite.only('s', () => {});";                           block=$true }
    @{ n='spec it.concurrent.only() focused';  f='src/app.spec.ts';           c="it.concurrent.only('x', async () => { expect(1).toBe(1); });"; block=$true }
    @{ n='spec test.only.each() focused';      f='src/app.spec.ts';           c="test.only.each([1])('x %i', (n) => { expect(n).toBe(1); });"; block=$true }
    @{ n='spec fit.each() focused';            f='src/app.spec.ts';           c="fit.each([1])('x %i', () => {});";                      block=$true }
    @{ n='spec test.skip(title) skipped';      f='src/app.spec.ts';           c="test.skip('x', () => { expect(1).toBe(1); });";        block=$true }
    @{ n='spec xtest() skipped';               f='src/app.spec.ts';           c="xtest('x', () => {});";                                block=$true }
    @{ n='spec describe.skip.each() skipped';  f='src/app.spec.ts';           c="describe.skip.each([1])('x %i', () => {});";           block=$true }
    @{ n='playwright test.describe.only() focused'; f='e2e/home.spec.ts';     c="test.describe.only('home', () => {});";                block=$true }
    @{ n='test.ts it.only() focused';          f='src/app.test.ts';           c="it.only('x', () => { expect(1).toBe(1); });";          block=$true }
    @{ n='test.ts expect(true).toBe(true)';    f='src/app.test.ts';           c='expect(true).toBe(true);';                             block=$true }
    @{ n='cy.ts it.only() focused';            f='cypress/e2e/login.cy.ts';   c="it.only('logs in', () => { cy.visit('/'); });";        block=$true }
    @{ n='spec test.skip.concurrent() skipped'; f='src/app.spec.ts';          c="test.skip.concurrent('x', async () => {});";           block=$true }
    @{ n='spec test.skip.failing() skipped';   f='src/app.spec.ts';           c="test.skip.failing('x', () => {});";                    block=$true }
    @{ n='spec test.skip(X.name, body) skipped'; f='src/app.spec.ts';         c='test.skip(AppComponent.name, () => {});';              block=$true }
    @{ n='playwright test.fixme(title) skipped'; f='e2e/home.spec.ts';        c="test.fixme('x', async ({ page }) => {});";             block=$true }
    @{ n='playwright test.describe.fixme() skipped'; f='e2e/home.spec.ts';    c="test.describe.fixme('g', () => {});";                  block=$true }
    @{ n='playwright test.skip(true) skipped'; f='e2e/home.spec.ts';          c="test.skip(true, 'flaky');";                            block=$true }
    @{ n='playwright test.fail.only() focused'; f='e2e/home.spec.ts';         c="test.fail.only('x', async () => {});";                 block=$true }
    @{ n='playwright test.describe.serial.only() focused'; f='e2e/home.spec.ts'; c="test.describe.serial.only('g', () => {});";         block=$true }
    @{ n='mocha context.skip(title, body) skipped'; f='cypress/e2e/login.cy.ts'; c="context.skip('login', () => {});";                  block=$true }
    @{ n='test.mjs it.only() focused';         f='src/app.test.mjs';          c="it.only('x', () => {});";                              block=$true }
    @{ n='vitest it.fails.only() focused';     f='src/app.spec.ts';           c="it.fails.only('x', () => {});";                        block=$true }
    @{ n='vitest describe.shuffle.only() focused'; f='src/app.spec.ts';       c="describe.shuffle.only('x', () => {});";                block=$true }
    @{ n='vitest describe.shuffle.skip() skipped'; f='src/app.spec.ts';       c="describe.shuffle.skip('x', () => {});";                block=$true }
    @{ n='mocha xcontext() skipped';           f='cypress/e2e/login.cy.ts';   c="xcontext('login', () => {});";                         block=$true }
    @{ n='mocha xspecify() skipped';           f='cypress/e2e/login.cy.ts';   c="xspecify('x', () => {});";                             block=$true }
    @{ n='mocha specify.only() focused';       f='cypress/e2e/login.cy.ts';   c="specify.only('x', () => {});";                         block=$true }
    @{ n='vitest it.fails.skip() skipped';     f='src/app.spec.ts';           c="it.fails.skip('x', () => {});";                        block=$true }
    @{ n='vitest test.fails.skip() skipped';   f='src/app.spec.ts';           c="test.fails.skip('x', () => {});";                      block=$true }
    @{ n='vitest test.concurrent.fails.only() focused'; f='src/app.spec.ts';  c="test.concurrent.fails.only('x', async () => {});";      block=$true }
    # Leading horizontal whitespace other than space and tab (here a form feed, which reads the same under
    # every console code page) still anchors fit().
    @{ n='spec fit() indented with a form feed'; f='src/app.spec.ts';         c="describe('a', () => {`n$([char]0x000C)fit('b', () => {});`n});"; block=$true }
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
    @{ n='OpenAI sk-proj- key';                f='src/Ai/OpenAiClientFactory.cs'; c="var key = `"$openAiKey`";";                      block=$true }
    @{ n='Anthropic sk-ant- key in .env';      f='.env';                      c="ANTHROPIC_API_KEY=$anthropicKey";                       block=$true }
    @{ n='sk- key after an escaped \n';        f='src/data/run-log.json';     c="{ `"out`": `"started\n$openAiKey`" }";                  block=$true }
    @{ n='sk- key after an escaped \t';        f='src/data/run-log.json';     c="{ `"out`": `"key:\t$openAiKey`" }";                     block=$true }
    @{ n='sk- key after a JSON unicode-escaped quote'; f='src/Api/Data/request.json'; c="{ `"body`": `"{${u22}apiKey${u22}:${u22}$openAiKey${u22}}`" }"; block=$true }
    @{ n='sk- key after a \x22 escape';        f='src/config.js';             c="const s = `"\x22$anthropicKey\x22`";";                 block=$true }
    @{ n='sk- key after a PowerShell backtick escape'; f='scripts/seed.ps1';  c="Set-Content keys.txt `"first``n$openAiKey`"";          block=$true }
    @{ n='sk- key after a URL-encoded byte';   f='src/app/api.ts';            c="const url = '/login?next=%2Fv1%2Fchat%3Fkey%3D$openAiKey';"; block=$true }
    @{ n='hardcoded credential literal';       f='src/AuthService.cs';        c='var password = "hunter2hunter2";';                     block=$true }
    @{ n='connection string Password';         f='src/AuthService.cs';        c='var connectionString = "Server=db;User Id=sa;Password=hunter2;Database=app";'; block=$true }
    @{ n='connection string URI userinfo';     f='src/AuthService.cs';        c='var connectionString = "postgres://user:hunter2@host/db";'; block=$true }
    # The standard appsettings.json layout keeps the password under a named entry of ConnectionStrings.
    @{ n='ConnectionStrings section Password'; f='src/Api/appsettings.json';  c='{ "ConnectionStrings": { "Main": "Server=prod-sql;Database=app;User Id=app;Password=Pr0dS3cret!;" } }'; block=$true }
    @{ n='ConnectionStrings later entry Password'; f='src/Api/appsettings.json'; c="{`n  `"ConnectionStrings`": {`n    `"Cache`": `"localhost:6379`",`n    `"Main`": `"Server=db;User Id=sa;Password=hunter2;`"`n  }`n}"; block=$true }
    @{ n='ConnectionStrings section URI userinfo'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Db": "postgres://app:hunter2@db/app" } }'; block=$true }
    @{ n='ConnectionStrings Password after an ODBC Driver={...} entry'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Odbc": "Driver={ODBC Driver 18 for SQL Server};Server=x;Trusted_Connection=yes", "Main": "Server=prod;User Id=app;Password=Pr0dS3cret!;" } }'; block=$true }
    # A token exempts only the credential value it stands for, and every credential-shaped match is checked.
    @{ n='literal password beside a server token'; f='src/Web.config'; c='<add name="Main" connectionString="Server=#{SqlServer}#;User Id=app;Password=Pr0dS3cret!;" />'; block=$true }
    @{ n='ConnectionStrings literal password beside a server token'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=#{SqlServer}#;User Id=app;Password=Pr0dS3cret!;" } }'; block=$true }
    @{ n='literal credential after a tokenised one'; f='src/Api/appsettings.json'; c='{ "Db": { "Password": "#{DbPassword}#" }, "Smtp": { "Password": "Pr0dS3cret!xyz" } }'; block=$true }
    @{ n='literal password before a token in a later password key'; f='src/Web.config'; c='<add name="Main" connectionString="Server=db;User Id=app;Password=Pr0dS3cret!;SslMode=Required;CertificatePassword=#{CertPassword}#" />'; block=$true }
    @{ n='ConnectionStrings literal password before a token in a later password key'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Host=db;Username=app;Password=Pr0dS3cret!;SSL Password=__CertPassword__" } }'; block=$true }
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
    # The test/sample exemption reads the path under the repository the hook belongs to, never the absolute
    # path: a checkout under a folder that is itself named test, samples, Development or Mocks must not
    # exempt its source. Paths outside that repository get no exemption; Guard.Tests.ps1 also places a copy
    # of the hook inside such folders and sends it the repository's own source and test paths. A `..`
    # segment is collapsed before the exemption is read, so tests\..\src is src, not tests.
    @{ n='credential in an absolute path under a Projects\test folder'; f='C:\Projects\test\repo\src\AuthService.cs'; c='var password = "hunter2hunter2";'; block=$true }
    @{ n='credential in an absolute path under a Development folder'; f='C:\Development\repo\src\AuthService.cs'; c='var password = "hunter2hunter2";'; block=$true }
    @{ n='credential in a forward-slash path under a Mocks folder'; f='C:/Mocks/repo/src/AuthService.cs'; c='var password = "hunter2hunter2";'; block=$true }
    @{ n='ConnectionStrings password in an absolute path under a samples folder'; f='D:\Projects\samples\shop\src\Api\appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=prod-sql;Database=app;User Id=app;Password=Pr0dS3cret!;" } }'; block=$true }
    @{ n='credential behind a .. segment out of tests\';  f='tests\..\src\AuthService.cs'; c='var password = "hunter2hunter2";'; block=$true }
    @{ n='credential behind .. segments in a forward-slash path'; f='src/../tests/../src/AuthService.cs'; c='var password = "hunter2hunter2";'; block=$true }
    # .NET and PowerShell resolve a trailing space or dot away (Foo.cs<space> and Foo.cs. are Foo.cs), so such a name is checked as Foo.cs.
    @{ n='C# suppression in a .cs name with a trailing space'; f='src/Foo.cs '; c='#pragma warning disable CS8602'; block=$true }
    @{ n='C# suppression in a .cs name with a trailing dot';   f='src/Foo.cs.'; c='#pragma warning disable CS8602'; block=$true }
    # Windows writes 'Foo.cs::$DATA' (an NTFS stream suffix, ':name[:type]' on the last segment) into Foo.cs itself, so the
    # suffix is cut before the extension is read; a drive designator ('C:Foo.cs') is not a stream.
    @{ n='C# suppression in a .cs name with an NTFS stream suffix'; f='src\Foo.cs::$DATA'; c='#pragma warning disable CS8602'; block=$true }
    @{ n='C# suppression in a relative .cs name with a lowercase stream suffix'; f='Foo.cs::$data'; c='#pragma warning disable CS8602'; block=$true }
    @{ n='C# suppression in a drive-relative .cs name with a stream suffix'; f='C:Foo.cs::$DATA'; c='#pragma warning disable CS8602'; block=$true }
    @{ n='focused spec in a .spec.ts name with a named stream'; f='src/app.spec.ts:s:$DATA'; c="fit('x', () => {});"; block=$true }
    # A focus indented with a no-break space (UTF-8 C2 A0) still anchors fit(): the hook reads its stdin as UTF-8 whatever the console code page.
    @{ n='spec fit() indented with a no-break space'; f='src/app.spec.ts'; c="describe('a', () => {`n$([char]0x00A0)fit('b', () => {});`n});"; block=$true }

    @{ n='a stream suffix on a .txt name is not a C# file (allow)'; f='notes/Foo.txt::$DATA'; c='#pragma warning disable CS8602'; block=$false }
    @{ n='clean .cs (allow)';                  f='src/Foo.cs';                c='public int Add(int a, int b) => a + b;';               block=$false }
    @{ n='clean .spec.ts real assertion';      f='src/app.spec.ts';           c="it('adds', () => { expect(add(1,2)).toBe(3); });";     block=$false }
    @{ n='RxJS skip() not a test-skip';        f='src/stream.spec.ts';        c='source$.pipe(skip(1)).subscribe();';                   block=$false }
    # Playwright's test.skip(condition, reason) and bare test.skip() are runtime conditions, not committed skips.
    @{ n='playwright test.skip(condition) (allow)'; f='e2e/home.spec.ts';     c="test.skip(isMobile, 'not on mobile');";                block=$false }
    @{ n='playwright bare test.skip() (allow)'; f='e2e/home.spec.ts';         c='test.skip();';                                         block=$false }
    @{ n='playwright test.skip(callback) (allow)'; f='e2e/home.spec.ts';      c="test.skip(({ browserName }) => browserName === 'webkit', 'Safari only');"; block=$false }
    @{ n='vitest it.skipIf() (allow)';         f='src/app.spec.ts';           c="it.skipIf(isCi)('x', () => { expect(1).toBe(1); });";  block=$false }
    @{ n='vitest test.todo() (allow)';         f='src/app.spec.ts';           c="test.todo('later');";                                  block=$false }
    @{ n='clean .test.ts real assertion';      f='src/app.test.ts';           c="it('adds', () => { expect(add(1,2)).toBe(3); });";     block=$false }
    @{ n='layout.fit() method call (allow)';   f='src/app.spec.ts';           c='layout.fit();';                                        block=$false }
    # Vitest's context.skip() skips from inside a running test, the analogue of Playwright's conditional skip.
    @{ n='vitest context.skip() at run time (allow)'; f='src/app.spec.ts';    c="test('x', (context) => { context.skip(); });";         block=$false }
    @{ n='vitest context.skip(condition, note) (allow)'; f='src/app.spec.ts'; c="test('x', (context) => { context.skip(isCi, 'ci'); });"; block=$false }
    @{ n='vitest context.skip(note) (allow)';  f='src/app.spec.ts';           c="test('x', (context) => { context.skip('flaky on CI'); });"; block=$false }
    @{ n='playwright test.skip(project.name ===) (allow)'; f='e2e/home.spec.ts'; c="test.skip(project.name === 'webkit', 'no webkit');"; block=$false }
    @{ n='playwright test.fixme(condition) (allow)'; f='e2e/home.spec.ts';    c="test.fixme(browserName === 'firefox', 'bug 123');";    block=$false }
    @{ n='cs [JsonIgnore] near-miss (allow)';  f='src/Dto.cs';                c='[JsonIgnore] public int Id { get; set; }';             block=$false }
    @{ n='cs enum Ignore member (allow)';      f='src/Mode.cs';               c='public enum Mode { None, Ignore, All }';               block=$false }
    @{ n='cs lowercase ignore arg (allow)';    f='src/Handler.cs';            c='Handle(evt, ignore, ctx);';                            block=$false }
    @{ n='cs NUnit [Explicit] (allow by design)'; f='tests/FooTests.cs';      c='[Test, Explicit] public void T(){}';                   block=$false }
    @{ n='credential in *Tests* file (allow)'; f='tests/AuthServiceTests.cs'; c='var password = "hunter2hunter2";';                     block=$false }
    @{ n='credential in Api.UnitTests dir (allow)'; f='src/Api.UnitTests/AuthClient.cs'; c='var password = "hunter2hunter2";';           block=$false }
    @{ n='credential in __mocks__ (allow)';    f='src/__mocks__/auth.ts';     c="const password = 'hunter2hunter2';";                   block=$false }
    @{ n='credential in appsettings.Development.json (allow)'; f='src/Api/appsettings.Development.json'; c='"Password": "hunter2hunter2"'; block=$false }
    @{ n='credential in tests\ reached through a .. segment (allow)'; f='src/../tests/AuthServiceTests.cs'; c='var password = "hunter2hunter2";'; block=$false }
    @{ n='Azurite well-known dev key (allow)'; f='src/Storage.cs';            c='var cs = "AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==";'; block=$false }
    @{ n='SAS sig= without a token (allow)';   f='src/Storage.cs';            c='var q = "?sv=2022-11-02&sig=";';                        block=$false }
    @{ n='passwordless connection string';     f='src/AuthService.cs';       c='var connectionString = "Server=localhost;Trusted_Connection=True";'; block=$false }
    @{ n='passwordless ConnectionStrings section'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=.;Database=app;Trusted_Connection=True" } }'; block=$false }
    @{ n='ConnectionStrings password placeholder'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=db;User Id=sa;Password=<from-vault>;" } }'; block=$false }
    @{ n='ConnectionStrings in appsettings.Development.json (allow)'; f='src/Api/appsettings.Development.json'; c='{ "ConnectionStrings": { "Main": "Server=localhost;User Id=sa;Password=dev-only-pass;" } }'; block=$false }
    # Release pipelines replace tokens in appsettings.json; a token is not a credential.
    @{ n='ConnectionStrings #{token}# placeholders (allow)'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=#{SqlServer}#;User Id=#{SqlUser}#;Password=#{SqlPassword}#;" } }'; block=$false }
    @{ n='ConnectionStrings __token__ placeholder (allow)'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=db;User Id=app;Password=__SqlPassword__;" } }'; block=$false }
    @{ n='ConnectionStrings $(variable) placeholder (allow)'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=db;User Id=app;Password=$(SqlPassword);" } }'; block=$false }
    @{ n='ConnectionStrings password under 4 characters (allow)'; f='src/Api/appsettings.json'; c='{ "ConnectionStrings": { "Main": "Server=.;User Id=sa;Pwd=abc;" } }'; block=$false }
    @{ n='near-miss fine-grained PAT';         f='src/deploy.cs';             c='var t = "github_pat_too_short";';                       block=$false }
    # sk- inside a kebab-case name is not a key; both lines were blocked as one before the left boundary.
    @{ n='kebab import containing sk- (allow)'; f='src/app/board/board.ts';  c="import { TaskListItemRenderer } from './task-list-item-renderer-component';"; block=$false }
    @{ n='kebab route containing sk- (allow)'; f='src/app/app.routes.ts';     c="{ path: 'risk-assessment-history-details', component: RiskHistory }"; block=$false }
    # Tagged `secret` so the invalid-regex red test observes both fail-closed directions: the
    # private-key case must still block, while this near-miss must turn red if every secret probe
    # is conservatively blocked. A policy filter containing only blocking cases is an inert oracle.
    @{ n='public key block near-miss';          f='src/deploy.cs';             c='-----BEGIN PUBLIC KEY-----';                            block=$false; policy='secret' }
    @{ n='case-sensitive ASSERT near-miss';    f='tests/FooTests.cs';         c='ASSERT.True(true);';                                   block=$false }
    @{ n='case-sensitive ESLINT near-miss';    f='src/app.ts';                c='// ESLINT-DISABLE-next-line';                          block=$false }
    # A suppression or skip is counted against the text the write replaces, so a write that keeps one already in the file
    # passes and one that adds another is blocked. An edit case carries o, the text it replaces (old_string on Claude Code,
    # old_str on Copilot) beside c, the new text. A disk case is a whole-file write of c over a file that holds that text on
    # disk: Guard.Tests.ps1 writes the file and sends its absolute path. Credential patterns are not counted this way.
    @{ n='edit keeps an existing #pragma warning disable (allow)'; f='src/Foo.cs'; o="#pragma warning disable CS0618`nvar a = Old();"; c="#pragma warning disable CS0618`nvar a = Old();`nvar b = Old();"; block=$false }
    @{ n='edit keeps an existing [Fact(Skip=...)] on its own line (allow)'; f='tests/FooTests.cs'; o="[Fact(Skip=`"flaky`")]`npublic void A(){}"; c="[Fact(Skip=`"flaky`")]`npublic void A(){ var q = 1; }"; block=$false }
    @{ n='edit of the code after a [Fact(Skip=...)] on the same line'; f='tests/FooTests.cs'; o='[Fact(Skip="flaky")] public void A(){}'; c='[Fact(Skip="flaky")] public void A(){ var q = 1; }'; block=$true }
    @{ n='edit keeps an existing [Ignore] (allow)'; f='tests/FooTests.cs'; o="[Test]`n[Ignore(`"flaky`")]`npublic void A(){}"; c="[Test]`n[Ignore(`"flaky`")]`npublic void A(){ var q = 1; }"; block=$false }
    @{ n='edit keeps an existing eslint-disable (allow)'; f='src/app.ts'; o="// eslint-disable-next-line no-console`nconsole.log(a);"; c="// eslint-disable-next-line no-console`nconsole.log(a, b);"; block=$false }
    @{ n='edit keeps an existing @ts-ignore (allow)'; f='src/app.ts'; o="// @ts-ignore`nconst a: number = 'x';"; c="// @ts-ignore`nconst a: number = 'x'; const b = a;"; block=$false }
    @{ n='edit keeps an existing xit with a multi-line body (allow)'; f='src/app.spec.ts'; o="xit('x', () => {`n  doIt();`n});"; c="xit('x', () => {`n  doIt();`n  expect(1).toBe(1);`n});"; block=$false }
    @{ n='edit of the code after an xit on the same line'; f='src/app.spec.ts'; o="xit('x', () => {});"; c="xit('x', () => { expect(1).toBe(1); });"; block=$true }
    @{ n='edit that removes one of two #pragma warning disable (allow)'; f='src/Foo.cs'; o="#pragma warning disable CS0618`n#pragma warning disable CS0612`nvar a = Old();"; c="#pragma warning disable CS0618`nvar a = Old();"; block=$false }
    @{ n='edit adds a second #pragma warning disable beside an existing one'; f='src/Foo.cs'; o="#pragma warning disable CS0618`nvar a = Old();"; c="#pragma warning disable CS0618`n#pragma warning disable CS0612`nvar a = Old();"; block=$true; policy='test-defeat/suppression' }
    @{ n='edit adds a #pragma warning disable where its old text has none'; f='src/Foo.cs'; o='var a = Old();'; c="#pragma warning disable CS0618`nvar a = Old();"; block=$true }
    @{ n='edit adds a second [Fact(Skip=...)] beside an existing one'; f='tests/FooTests.cs'; o='[Fact(Skip="flaky")] public void A(){}'; c='[Fact(Skip="flaky")] public void A(){} [Fact(Skip="slow")] public void B(){}'; block=$true }
    @{ n='edit adds a second eslint-disable beside an existing one'; f='src/app.ts'; o="// eslint-disable-next-line no-console`nconsole.log(a);"; c="// eslint-disable-next-line no-console`nconsole.log(a);`n// eslint-disable-next-line no-alert`nalert(a);"; block=$true }
    @{ n='edit adds a second xit beside an existing one'; f='src/app.spec.ts'; o="xit('x', () => {});"; c="xit('x', () => {});`nxit('y', () => {});"; block=$true }
    @{ n='whole-file write keeps the #pragma warning disable already on disk (allow)'; f='src/Foo.cs'; disk="#pragma warning disable CS0618`nvar a = 1;`n"; c="#pragma warning disable CS0618`nvar a = 2;`n"; block=$false }
    @{ n='whole-file write keeps the [Fact(Skip=...)] already on disk on its own line (allow)'; f='tests/FooTests.cs'; disk="[Fact(Skip=`"flaky`")]`npublic void A(){}`n"; c="[Fact(Skip=`"flaky`")]`npublic void A(){ var q = 1; }`n"; block=$false }
    @{ n='whole-file write that edits the code after a [Fact(Skip=...)] on the same line of the file on disk'; f='tests/FooTests.cs'; disk='[Fact(Skip="flaky")] public void A(){}'; c='[Fact(Skip="flaky")] public void A(){ var q = 1; }'; block=$true }
    @{ n='whole-file write adds a second #pragma warning disable to the file on disk'; f='src/Foo.cs'; disk="#pragma warning disable CS0618`nvar a = 1;`n"; c="#pragma warning disable CS0618`n#pragma warning disable CS0612`nvar a = 2;`n"; block=$true }
    @{ n='whole-file write adds a #pragma warning disable to a file on disk without one'; f='src/Foo.cs'; disk="var a = 1;`n"; c="#pragma warning disable CS0618`nvar a = 2;`n"; block=$true }
    # A directive is compared as text: the match plus the words, commas, hyphens and blanks after it on its line, trimmed. A
    # write that widens one, or turns a mention of one into a directive, adds a new text and is blocked; one that keeps a
    # directive's text, or edits the code around it, does not. An unchanged directive moved to other code is a stated limit.
    @{ n='edit widens @ts-ignore to @ts-nocheck'; f='src/app.ts'; o="// @ts-ignore`nconst a: number = 'x';"; c="// @ts-nocheck`nconst a: number = 'x';"; block=$true }
    @{ n='edit widens #pragma warning disable CS0618 to a bare #pragma warning disable'; f='src/Foo.cs'; o="#pragma warning disable CS0618`nvar a = Old();"; c="#pragma warning disable`nvar a = Old();"; block=$true }
    @{ n='edit widens eslint-disable-next-line to a block /* eslint-disable */'; f='src/app.ts'; o="// eslint-disable-next-line no-console`nconsole.log(a);"; c="/* eslint-disable */`nconsole.log(a);"; block=$true }
    @{ n='edit widens xit to xdescribe'; f='src/app.spec.ts'; o="xit('x', () => {});"; c="xdescribe('x', () => {});"; block=$true }
    @{ n='edit widens it.skip to describe.skip'; f='src/app.spec.ts'; o="it.skip('x', () => {});"; c="describe.skip('x', () => {});"; block=$true }
    @{ n='edit turns a comment that mentions eslint-disable into a directive'; f='src/app.ts'; o="// dropped the eslint-disable here`nconst a = 1;"; c="// eslint-disable-next-line no-console`nconst a = 1;"; block=$true }
    @{ n='edit of the code before an eslint-disable-line keeps it (allow)'; f='src/app.ts'; o='foo(); // eslint-disable-line no-console'; c='foo(1); // eslint-disable-line no-console'; block=$false }
    @{ n='edit moves an unchanged eslint-disable-next-line to other code (allow, a stated limit)'; f='src/app.ts'; o="// eslint-disable-next-line no-console`nconsole.log(a);"; c="console.log(b);`n// eslint-disable-next-line no-console"; block=$false }
    @{ n='whole-file LF write keeps the #pragma warning disable of a CRLF file on disk (allow)'; f='src/Foo.cs'; disk="#pragma warning disable CS0618`r`nvar a = 1;`r`n"; c="#pragma warning disable CS0618`nvar a = 2;`n"; block=$false }
    # The directive's text runs to the end of its line (to the */ for a block comment that does not close there), so a rule
    # dropped from or added to a directive is a new directive, and a closing line that goes leaves a suppression in force.
    @{ n='edit drops the rule from an eslint-disable-next-line'; f='src/app.ts'; o="// eslint-disable-next-line @typescript-eslint/no-explicit-any`nconst a: any = 1;"; c="// eslint-disable-next-line`nconst a: any = 1;"; block=$true }
    @{ n='edit drops the rule from a block /* eslint-disable */'; f='src/app.ts'; o="/* eslint-disable @angular-eslint/component-selector */`n@Component({})"; c="/* eslint-disable */`n@Component({})"; block=$true }
    @{ n='edit appends rules to an eslint-disable-next-line'; f='src/app.ts'; o="// eslint-disable-next-line react-hooks/exhaustive-deps`nuseEffect(f, []);"; c="// eslint-disable-next-line react-hooks/exhaustive-deps, no-console, react/jsx-key`nuseEffect(f, []);"; block=$true }
    @{ n='edit adds a rule to a block eslint-disable that closes on a later line'; f='src/app.ts'; o="/* eslint-disable`n   no-console,`n   no-alert */`nfoo();"; c="/* eslint-disable`n   no-console,`n   no-alert,`n   no-debugger */`nfoo();"; block=$true }
    @{ n='edit keeps an eslint-disable-next-line with a scoped rule (allow)'; f='src/app.ts'; o="// eslint-disable-next-line @typescript-eslint/no-explicit-any`nconst a: any = 1;"; c="// eslint-disable-next-line @typescript-eslint/no-explicit-any`nconst a: any = 2;"; block=$false }
    @{ n='edit of the code after a block eslint-disable that closes on a later line keeps it (allow)'; f='src/app.ts'; o="/* eslint-disable`n   no-console,`n   no-alert */`nfoo();"; c="/* eslint-disable`n   no-console,`n   no-alert */`nfoo(1);"; block=$false }
    @{ n='edit drops the #pragma warning restore that closes a disable'; f='src/Foo.cs'; o="#pragma warning disable CS0618`nint a;`n#pragma warning restore CS0618`nint b;"; c="#pragma warning disable CS0618`nint a;`nint b;"; block=$true }
    @{ n='edit drops the eslint-enable that closes a block eslint-disable'; f='src/app.ts'; o="/* eslint-disable no-console */`nfoo();`n/* eslint-enable no-console */`nbar();"; c="/* eslint-disable no-console */`nfoo();`nbar();"; block=$true }
    @{ n='edit keeps the #pragma warning restore that closes a disable (allow)'; f='src/Foo.cs'; o="#pragma warning disable CS0618`nint a;`n#pragma warning restore CS0618`nint b;"; c="#pragma warning disable CS0618`nint a2;`n#pragma warning restore CS0618`nint b;"; block=$false }
    @{ n='whole-file write drops the #pragma warning restore of the file on disk'; f='src/Foo.cs'; disk="#pragma warning disable CS0618`nint a;`n#pragma warning restore CS0618`nint b;`n"; c="#pragma warning disable CS0618`nint a;`nint b;`n"; block=$true }
    # A directive is inside a block comment when a /* before it, within 8 lines, has no */ between: its text then runs to the */
    # or to the end of an 8-line, 1 KB-a-line window, not to the end of its line. A /* that closed earlier on the line does not count.
    @{ n='edit of the code after a closed /* c */ keeps the eslint-disable-next-line on its line (allow)'; f='src/app.ts'; o="const a = /* c */ 1; // eslint-disable-next-line no-console`nfoo();`n/* z */"; c="const a = /* c */ 1; // eslint-disable-next-line no-console`nbar();`n/* z */"; block=$false }
    @{ n='edit drops rules from a block eslint-disable whose /* is on the line above'; f='src/app.ts'; o="/*`n eslint-disable`n no-console,`n no-alert`n*/"; c="/*`n eslint-disable`n*/"; block=$true }
    @{ n='edit shortens a 9-line block eslint-disable to a bare one'; f='src/app.ts'; o="/* eslint-disable`n r1,`n r2,`n r3,`n r4,`n r5,`n r6,`n r7,`n r8 */`nfoo();"; c="/* eslint-disable */`nfoo();"; block=$true }
    @{ n='edit shortens a 1100-character block eslint-disable to a bare one'; f='src/app.ts'; o=("/* eslint-disable " + ('rule-a, ' * 138) + "*/`nfoo();"); c="/* eslint-disable */`nfoo();"; block=$true }
    # The balance counts only the block form of eslint-disable as an opener (not -line or -next-line), so an unrelated
    # eslint-disable-line that goes cannot pay for an eslint-enable that goes.
    @{ n='edit drops an eslint-enable and an unrelated eslint-disable-line'; f='src/app.ts'; o="/* eslint-disable no-alert */`nfoo();`n/* eslint-enable no-alert */`nf(); // eslint-disable-line no-console"; c="/* eslint-disable no-alert */`nfoo();"; block=$true }
    @{ n='edit drops only the eslint-enable and keeps the eslint-disable-line'; f='src/app.ts'; o="/* eslint-disable no-alert */`nfoo();`n/* eslint-enable no-alert */`nf(); // eslint-disable-line no-console"; c="/* eslint-disable no-alert */`nfoo();`nf(); // eslint-disable-line no-console"; block=$true }
    @{ n='edit drops an unrelated eslint-disable-line and keeps the block pair (allow)'; f='src/app.ts'; o="/* eslint-disable no-alert */`nfoo();`n/* eslint-enable no-alert */`nf(); // eslint-disable-line no-console"; c="/* eslint-disable no-alert */`nfoo();`n/* eslint-enable no-alert */`nf();"; block=$false }
)

# The edit events of the two surfaces, for the cases that carry o: Claude Code's Edit (file_path, old_string, new_string)
# and Copilot CLI's edit (path, old_str, new_str).
function New-ClaudeEditEvent  { param($File,$Old,$New) (@{ tool_name='Edit'; tool_input=@{ file_path=$File; old_string=$Old; new_string=$New } } | ConvertTo-Json -Compress -Depth 6) }
function New-CopilotEditEvent { param($File,$Old,$New) (@{ toolName='edit'; toolArgs=@{ path=$File; old_str=$Old; new_str=$New } } | ConvertTo-Json -Compress -Depth 6) }
