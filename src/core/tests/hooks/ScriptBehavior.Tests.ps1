# Behavioral contracts for shipped PowerShell utility scripts.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path

function Put($Path, $Text) {
    $parent = Split-Path $Path -Parent
    if ($parent) { New-Item -ItemType Directory -Force $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function PutBom($Path, $Text) {
    $parent = Split-Path $Path -Parent
    if ($parent) { New-Item -ItemType Directory -Force $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($true))
}
function Temp($Name) {
    $path = Join-Path ([IO.Path]::GetTempPath()) ($Name + '-' + [guid]::NewGuid())
    New-Item -ItemType Directory $path | Out-Null
    $path
}
function NormPath($Path) { ([IO.Path]::GetFullPath($Path).TrimEnd('\','/') -replace '\\','/').ToLowerInvariant() }
function InitSafe($Path) {
    git -C $Path init --quiet
    Assert ($LASTEXITCODE -eq 0) "git init failed: $Path"
    Push-Location -LiteralPath $Path
    try { Assert ((NormPath (git rev-parse --show-toplevel)) -eq (NormPath $Path)) "unsafe git root for $Path" }
    finally { Pop-Location }
}
function RunHere($Path, $Cwd, [string[]]$Arguments = @()) {
    Push-Location -LiteralPath $Cwd
    try { RunArg $Path $Arguments } finally { Pop-Location }
}
function Records($Text) {
    $records = @()
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^(OK|FAIL):\s+(.*)$') { $records += ($Matches[1] + '|' + $Matches[2]) }
    }
    ,$records
}
function LiteralCount($Text, $Needle) { @([regex]::Matches([string]$Text, [regex]::Escape($Needle))).Count }
function TerminalLineCount($Text, $Sentinel) {
    @(([string]$Text -split '\r\n|\n|\r') | Where-Object { $_.Trim().EndsWith($Sentinel, [StringComparison]::Ordinal) }).Count
}
function CopyScript($Name, $Root) {
    New-Item -ItemType Directory -Force (Join-Path $Root scripts) | Out-Null
    Copy-Item (Join-Path $scripts "$Name.ps1") (Join-Path $Root scripts)
}

function TemplateFixture {
    $root = Temp template
    CopyScript template-checks $root
    Put (Join-Path $root '.template-repo') "fixture`n"
    Put (Join-Path $root CHANGELOG.md) "# Changelog`n`n## 1.2.3 — 2026-08-08`n`n- Fixture.`n"
    Put (Join-Path $root CLAUDE.md) "@AGENTS.md`n@.github/instructions/framework-rules.instructions.md`n"
    Put (Join-Path $root AGENTS.md) "version: 1.2.3`n## Boy Scout Rule`nSame`n## Common Tasks`n- ``alpha`` — first → second`n"
    Put (Join-Path $root '.claude/framework-version.json') '{"version":"1.2.3"}'
    foreach ($name in @('audit-trail','boy-scout-check','guard','post-write','route-prompt','session-start')) {
        PutBom (Join-Path $root ".claude/hooks/$name.ps1") "# fixture`n"
    }
    Put (Join-Path $root '.claude/skills/demo/SKILL.md') "# demo`n"
    $root
}

$expectedChecks = @(
    'version stamps in sync', 'CLAUDE.md imports AGENTS.md', 'CLAUDE.md imports the framework rules',
    'AGENTS.md is the project instruction file',
    'carry a UTF-8 BOM',
    'all framework .ps1 files parse cleanly', 'required framework PowerShell hook set present (6)',
    'canonical project skills use .claude/skills', 'retired skill-mirror sync scripts are absent'
)

function SetWarehouseStub($Root, [int]$Status, [string]$Stream, [string]$Sentinel) {
    $write = if ($Stream -eq 'stderr') { "[Console]::Error.WriteLine('$Sentinel')" } else { "Write-Output '$Sentinel'" }
    PutBom (Join-Path $Root 'scripts/warehouse-map-check.ps1') "$write`nexit $Status`n"
}
function DocsFixture {
    $root = Temp docs
    CopyScript docs-sync-check $root
    Put (Join-Path $root 'docs/enforcement-surfaces.md') "fixture`n"
    Put (Join-Path $root CLAUDE.md) "@AGENTS.md`n@.github/instructions/framework-rules.instructions.md`n"
    Put (Join-Path $root AGENTS.md) "# ready`n"
    Put (Join-Path $root TECH_DEBT.md) "# debt`n"
    Put (Join-Path $root FRAMEWORK-CONTEXT.md) "# context`n"
    Put (Join-Path $root README.md) "# fixture`n"
    Put (Join-Path $root '.claude/skills/my-skill/SKILL.md') "# skill`n"
    Put (Join-Path $root '.claude/agents/my-agent.md') "# agent`n"
    $root
}

function MetricsSubjects {
    $local = Join-Path $scripts metrics.ps1
    if (Test-Path $local) { return @($local) }
    $srcRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    @(Get-ChildItem (Join-Path $srcRoot 'stacks/*/files/scripts/metrics.ps1') | ForEach-Object { $_.FullName })
}

Reset-Tests

It 'template-checks reaches the complete clean contract and reports planted drift' {
    $root = TemplateFixture
    try {
        $subject = Join-Path $root scripts/template-checks.ps1
        Assert (([regex]::Matches([IO.File]::ReadAllText($subject), 'files parse cleanly\.')).Count -eq 1) 'parse-success emission count changed'
        $clean = RunArg $subject
        Assert ($clean.Exit -eq 0) "clean fixture failed: $($clean.Out) $($clean.Err)"
        $records = Records $clean.Out
        foreach ($wanted in $expectedChecks) {
            Assert (@($records | Where-Object { $_ -like "*$wanted*" }).Count -ge 1) "check '$wanted' was never reached"
        }

        Put (Join-Path $root '.github/skills/rogue/SKILL.md') '# rogue'
        $rogue = RunArg $subject
        Assert ($rogue.Exit -ne 0) 'present .github/skills should fail template-checks'
        Assert ($rogue.Out.Contains('.github/skills exists — migrate its contents to .claude/skills, then remove the GitHub path.')) 'migration finding absent'
        Remove-Item -Recurse -Force (Join-Path $root '.github/skills')

        foreach ($retiredScript in @('scripts/sync-agent-files.ps1')) {
            $full = Join-Path $root $retiredScript
            if ($retiredScript.EndsWith('.ps1')) { PutBom $full "# retired`n" } else { Put $full "# retired`n" }
            $retired = RunArg $subject
            Assert ($retired.Exit -ne 0) "$retiredScript should fail template-checks"
            Assert ($retired.Out.Contains("retired skill-mirror sync scripts exist: $retiredScript — remove these framework leftovers.")) "retired-script finding absent for $retiredScript"
            Remove-Item -LiteralPath $full -Force
        }

        Put (Join-Path $root '.claude/framework-version.json') '{"version":"9.9.9"}'
        Remove-Item -LiteralPath (Join-Path $root '.claude/hooks/guard.ps1') -Force
        $drift = RunArg $subject
        Assert ($drift.Exit -eq 3) "two-finding drift exit=$($drift.Exit), expected fixed status 3"
        Assert ($drift.Out.Contains('version-stamp drift: AGENTS.md says 1.2.3, framework-version.json says 9.9.9.')) 'version drift failure missing'
        Assert ($drift.Out.Contains('2 framework check(s) FAILED.')) 'finding count changed'

        $absent = 'CHANGELOG.__b175_absent__'
        $source = [IO.File]::ReadAllText($subject)
        $anchor = "Resolve-Path -LiteralPath 'CHANGELOG.md'"
        Assert ((LiteralCount $source $anchor) -eq 1) 'CHANGELOG input anchor changed'
        PutBom $subject ($source.Replace($anchor, "Resolve-Path -LiteralPath '$absent'"))
        $resource = RunArg $subject
        $diagnostic = 'CANT-VERIFY: template-checks could not inspect CHANGELOG.md; changelog headings remain UNKNOWN. Fix the host/resource read problem and rerun.'
        Assert ($resource.Exit -eq 2 -and $resource.Out.Trim() -ceq $diagnostic) "resource contract changed: exit=$($resource.Exit) out='$($resource.Out)'"
    } finally { Remove-Item -Recurse -Force $root }
}

It 'template-checks names each instruction-layout defect and accepts CRLF' {
    $cases = [ordered]@{
        'older-layout'    = 'CLAUDE.md does not import AGENTS.md - this repo still uses the older layout.'
        'no-rules-import' = 'CLAUDE.md does not import .github/instructions/framework-rules.instructions.md'
        'mirror-banner'   = 'AGENTS.md still carries the retired generated-mirror banner.'
        'no-boy-scout'    = "AGENTS.md is missing section '## Boy Scout Rule'."
        'no-agents'       = 'AGENTS.md is missing.'
        'crlf'            = $null
        'generated-prose' = $null
        'dot-slash'       = $null
        'inline-import'   = $null
    }
    foreach ($case in $cases.Keys) {
        $root = TemplateFixture
        try {
            $claude = Join-Path $root CLAUDE.md
            $agents = Join-Path $root AGENTS.md
            if ($case -eq 'older-layout') { Put $claude "version: 1.2.3`n@.github/instructions/framework-rules.instructions.md`n## Boy Scout Rule`nSame`n" }
            elseif ($case -eq 'no-rules-import') { Put $claude "@AGENTS.md`n" }
            elseif ($case -eq 'mirror-banner') { Put $agents ("<!-- GENERATED FILE — do not edit by hand. -->`n" + [IO.File]::ReadAllText($agents)) }
            elseif ($case -eq 'no-boy-scout') { Put $agents "version: 1.2.3`n## Conventions`nSame`n" }
            elseif ($case -eq 'no-agents') { Remove-Item -LiteralPath $agents -Force }
            elseif ($case -eq 'generated-prose') { Put $agents ([IO.File]::ReadAllText($agents) + "- Do not hand-edit a generated file; regenerate it. GENERATED FILE markers in *.Designer.cs stay.`n") }
            elseif ($case -eq 'dot-slash') { Put $claude "@./AGENTS.md`n@.github/instructions/framework-rules.instructions.md`n" }
            elseif ($case -eq 'inline-import') { Put $claude "Project instructions: see @AGENTS.md`n@.github/instructions/framework-rules.instructions.md`n" }
            else {
                foreach ($path in @($claude, $agents)) { [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path) -replace "`r`n", "`n" -replace "`n", "`r`n"), [Text.UTF8Encoding]::new($false)) }
            }
            $result = RunArg (Join-Path $root scripts/template-checks.ps1)
            if ($null -eq $cases[$case]) {
                Assert ($result.Exit -eq 0) "$case should pass: $($result.Out)"
            } else {
                Assert ($result.Exit -eq 3) "$case exit=$($result.Exit), expected 3: $($result.Out)"
                Assert ($result.Out.Contains($cases[$case])) "$case finding absent: $($result.Out)"
            }
        } finally { Remove-Item -Recurse -Force $root }
    }
}

It 'template-checks in a consumer repository checks only the scripts the ownership manifest lists' {
    $root = TemplateFixture
    try {
        Remove-Item -LiteralPath (Join-Path $root '.template-repo') -Force
        $subject = Join-Path $root scripts/template-checks.ps1
        $own = @('.claude/hooks/audit-trail.ps1','.claude/hooks/boy-scout-check.ps1','.claude/hooks/guard.ps1','.claude/hooks/post-write.ps1','.claude/hooks/route-prompt.ps1','.claude/hooks/session-start.ps1','scripts/template-checks.ps1')
        $manifest = Join-Path $root framework-ownership.json
        Put $manifest ('{"schema-version":1,"paths":[' + (($own | ForEach-Object { '{"path":"' + $_ + '","ownership":"framework-owned/overwritten"}' }) -join ',') + ']}')
        # A consumer's own script: no BOM, pwsh-7 syntax. It is not the framework's to police.
        Put (Join-Path $root scripts/deploy.ps1) "`$x = `$null ?? 1`n"
        $consumer = RunArg $subject
        Assert ($consumer.Exit -eq 0) "consumer-owned script failed the framework checks: exit=$($consumer.Exit) $($consumer.Out)"
        # A framework-owned script that lost its BOM still fails.
        Put (Join-Path $root .claude/hooks/guard.ps1) "# fixture`n"
        $owned = RunArg $subject
        Assert ($owned.Exit -eq 3 -and $owned.Out.Contains('BOM missing on:') -and $owned.Out.Contains('guard.ps1') -and -not $owned.Out.Contains('deploy.ps1')) "owned BOM-less script not reported alone: exit=$($owned.Exit) $($owned.Out)"
        PutBom (Join-Path $root .claude/hooks/guard.ps1) "# fixture`n"
        # An unreadable manifest is 'could not examine', not a pass.
        Put $manifest '{ not json'
        $bad = RunArg $subject
        Assert ($bad.Exit -eq 2 -and $bad.Out.Contains('CANT-VERIFY:') -and $bad.Out.Contains('framework-ownership.json')) "invalid manifest: exit=$($bad.Exit) $($bad.Out)"
        # No manifest (older install): the full scan stays.
        Remove-Item -LiteralPath $manifest -Force
        $absent = RunArg $subject
        Assert ($absent.Exit -eq 3 -and $absent.Out.Contains('deploy.ps1')) "absent manifest should keep the full scan: exit=$($absent.Exit) $($absent.Out)"
    } finally { Remove-Item -Recurse -Force $root }
}

It 'template-checks rejects an Unreleased stamped head but accepts a dated one' {
    foreach ($case in @('dated','unreleased')) {
        $root = TemplateFixture
        try {
            $head = if ($case -eq 'dated') { '## 1.2.3 — 2026-08-08' } else { '## 1.2.3 — Unreleased' }
            Put (Join-Path $root CHANGELOG.md) "# Changelog`n`n$head`n`n- Fixture.`n"
            $result = RunArg (Join-Path $root scripts/template-checks.ps1)
            if ($case -eq 'dated') { Assert ($result.Exit -eq 0) "dated head should pass: $($result.Out)" }
            else {
                Assert ($result.Exit -ne 0) 'Unreleased head should fail'
                Assert ($result.Out.Contains("still reads '$head' — stamp it with a real release date before shipping.")) 'placeholder finding absent'
            }
        } finally { Remove-Item -Recurse -Force $root }
    }
}

It 'docs-sync-check preserves all wrapper states and advisory prose' {
    $results = [ordered]@{}
    $root = DocsFixture
    try {
        foreach ($world in @(
            @{ Name='status-0'; Status=0; Stream='stdout'; Sentinel='WAREHOUSE_CHILD_STATUS_0' },
            @{ Name='status-1'; Status=1; Stream='stdout'; Sentinel='WAREHOUSE_CHILD_STATUS_1' },
            @{ Name='status-2'; Status=2; Stream='stderr'; Sentinel='WAREHOUSE_CHILD_STATUS_2' },
            @{ Name='unexpected'; Status=-1; Stream='stderr'; Sentinel='WAREHOUSE_CHILD_STATUS_UNEXPECTED' }
        )) {
            SetWarehouseStub $root $world.Status $world.Stream $world.Sentinel
            $results[$world.Name] = RunArg (Join-Path $root scripts/docs-sync-check.ps1)
        }

        $oldNote = 'NOTE: warehouse map is missing or stale; refresh it before a warehouse write. (advisory - not a failure)'
        $newNote = 'NOTE: warehouse map could not be verified; this is not evidence that the map is missing or stale. (advisory - not a failure)'
        $zero = $results['status-0']
        Assert ($zero.Exit -eq 0) "status-0 exit=$($zero.Exit)"
        Assert ((LiteralCount $zero.Out 'WAREHOUSE_CHILD_STATUS_0') -eq 1) 'status-0 sentinel cardinality differs'
        Assert ((LiteralCount $zero.Out $oldNote) -eq 0 -and (LiteralCount $zero.Out $newNote) -eq 0) 'status-0 emitted warehouse note'
        foreach ($advisory in @(
            "NOTE: docs/ci-integration.md is missing — restore it from the template if you need the Windows required-build recipe. (advisory — not a failure)",
            "NOTE: README.md does not mention: skill:my-skill agent:my-agent — update the What's-in-the-box / subagents tables (they may have drifted). (advisory — not a failure)"
        )) { Assert ($zero.Out.Contains($advisory)) "advisory differs: $advisory" }

        $one = $results['status-1']
        Assert ($one.Exit -eq 0) "status-1 exit=$($one.Exit)"
        Assert ((LiteralCount $one.Out 'WAREHOUSE_CHILD_STATUS_1') -eq 1) 'status-1 sentinel cardinality differs'
        Assert ((LiteralCount $one.Out $oldNote) -eq 1 -and (LiteralCount $one.Out $newNote) -eq 0) 'status-1 advisory classification differs'

        foreach ($name in @('status-2','unexpected')) {
            $result = $results[$name]
            $sentinel = if ($name -eq 'status-2') { 'WAREHOUSE_CHILD_STATUS_2' } else { 'WAREHOUSE_CHILD_STATUS_UNEXPECTED' }
            Assert ($result.Exit -eq 0) "$name exit=$($result.Exit)"
            Assert ((TerminalLineCount $result.Err $sentinel) -eq 1) "$name stderr sentinel cardinality differs"
            Assert ((LiteralCount $result.Out $newNote) -eq 1 -and (LiteralCount $result.Out $oldNote) -eq 0) "$name advisory classification differs"
        }
    } finally { Remove-Item -Recurse -Force $root }

    $mirror = DocsFixture
    try {
        SetWarehouseStub $mirror 0 stdout 'WAREHOUSE_CHILD_STATUS_MIRROR'
        Put (Join-Path $mirror '.github/skills/my-skill/SKILL.md') '# stale'
        $result = RunArg (Join-Path $mirror scripts/docs-sync-check.ps1)
        Assert ($result.Exit -ne 0) "docs-sync should fail for .github/skills, got $($result.Exit)"
        Assert ($result.Out.Contains('.github/skills exists — migrate its contents to .claude/skills, then remove the GitHub path.')) 'docs-sync migration finding absent'
    } finally { Remove-Item -Recurse -Force $mirror }
}

It 'metrics reports every expected counter as non-zero' {
    $metricScripts = @(MetricsSubjects)
    Assert ($metricScripts.Count -gt 0) 'metrics subject discovery returned zero scripts'
    foreach ($subject in $metricScripts) {
        $root = Temp metrics
        try {
            InitSafe $root
            Put (Join-Path $root sample.cs) @'
async Task Work() { }
_logger.LogInformation($"x");
#pragma warning disable CS1
Console.WriteLine("x");
// TODO TODO
throw new NotImplementedException();
var s = new UserService();
var h = MD5.Create(); var h2 = SHA1.Create();
q.FromSqlRaw("x");
double TotalAmount;
[Fact] void T() { Assert.True(true); }
[Fact(Skip = "x")] void S() { }
'@
            Put (Join-Path $root sample.ts) @'
let x: any; let y = <any>x;
// @ts-ignore
// eslint-disable
stream.subscribe();
sanitizer.bypassSecurityTrustHtml(x);
console.log(x);
// TODO TODO
throw new Error("not implemented");
const s = new UserService();
describe("x", () => { it("y", () => { expect(true).toBe(true); }); });
fit("x", () => {});
'@
            Put (Join-Path $root 'bin/excluded.cs') 'Console.WriteLine("excluded");'
            Put (Join-Path $root 'node_modules/excluded.ts') 'console.log("excluded");'
            $result = RunHere $subject $root
            Assert ($result.Exit -eq 0) "metrics failed for $subject`: $($result.Err)"
            $json = $result.Out | ConvertFrom-Json
            $keys = @($json.metrics.psobject.Properties.Name | Sort-Object)
            Assert ($keys.Count -gt 0) "metrics key discovery returned zero for $subject"
            foreach ($key in $keys) { Assert ([int]$json.metrics.$key -gt 0) "$key expected non-zero, got $($json.metrics.$key)" }
        } finally { Remove-Item -Recurse -Force $root }
    }
}

# The Angular counters on v21-v22 shapes, counted exactly: Vitest's focus and skip forms, suffix-less
# @Service/@Injectable classes, and ts_strict's three states (TypeScript 6 makes strict the default).
$ngMetricsCase = 'metrics counts v21-v22 spec, service and ts_strict shapes exactly'
$ngMetrics = @(MetricsSubjects | Where-Object { [IO.File]::ReadAllText($_).Contains('tests_skipped_focused') })
if ($ngMetrics.Count -eq 0) {
    Skip $ngMetricsCase 'this distribution''s metrics script carries no Angular counters'
} else {
    It $ngMetricsCase {
        $expected = [ordered]@{ tests_skipped_focused = 5; test_specs = 2; concrete_service_instantiation_dip = 2 }
        foreach ($subject in $ngMetrics) {
            $root = Temp metrics-ng
            try {
                InitSafe $root
                Put (Join-Path $root 'src/app/user.ts') @'
@Service()
export class User {}
@Injectable({
  providedIn: 'root',
})
export class Session {}
export class Address {}
const u = new User();
const s = new Session();
const a = new Address();
const ok = /u/.test('u');
'@
                Put (Join-Path $root 'src/app/user.spec.ts') @'
describe('user', () => {
  test('plain', () => {});
  test.only('focused', () => {});
  test.skip('skipped', () => {});
  it.skipIf(true)('conditional', () => {});
  it.concurrent.only('chained', () => {});
  test.todo('later');
});
'@
                foreach ($world in @(
                    @{ Name = 'TypeScript 6, no strict key'; Options = '"noImplicitOverride": true'; Package = '{ "devDependencies": { "typescript": "~6.0.2" } }'; Expect = 'true' },
                    @{ Name = 'TypeScript 6, strict false'; Options = '"strict": false, "noImplicitOverride": true'; Package = '{ "devDependencies": { "typescript": "~6.0.2" } }'; Expect = 'false' },
                    @{ Name = 'TypeScript 5, no strict key'; Options = '"noImplicitOverride": true'; Package = '{ "devDependencies": { "typescript": "~5.9.2" } }'; Expect = 'false' },
                    @{ Name = 'no TypeScript version'; Options = '"noImplicitOverride": true'; Package = '{ "name": "fixture" }'; Expect = 'null' }
                )) {
                    Put (Join-Path $root tsconfig.json) ('{ "compilerOptions": { ' + $world.Options + ' }, "angularCompilerOptions": { "strictTemplates": false }, "files": [], "references": [{ "path": "./tsconfig.app.json" }] }')
                    Put (Join-Path $root package.json) $world.Package
                    $result = RunHere $subject $root
                    Assert ($result.Exit -eq 0) "metrics failed for $subject ($($world.Name)): $($result.Err)"
                    $json = $result.Out | ConvertFrom-Json
                    foreach ($key in $expected.Keys) {
                        Assert ([int]$json.metrics.$key -eq $expected[$key]) "$subject ($($world.Name)): $key expected $($expected[$key]), got $($json.metrics.$key)"
                    }
                    $strict = if ($null -eq $json.readiness.ts_strict) { 'null' } else { ([string]$json.readiness.ts_strict).ToLowerInvariant() }
                    Assert ($strict -eq $world.Expect) "$subject ($($world.Name)): ts_strict expected $($world.Expect), got $strict"
                }
            } finally { Remove-Item -Recurse -Force $root }
        }
    }
}

function MetricKey($Json, [string]$Key) { @($Json.metrics.psobject.Properties.Name) -contains $Key }

It 'metrics gives the same JSON, coverage included, at a path with [ ] as at a plain one' {
    foreach ($subject in @(MetricsSubjects)) {
        $roots = @((Temp metrics-plain), (Temp 'metrics-[1]'))
        try {
            $jsons = @()
            foreach ($root in $roots) {
                InitSafe $root
                Put (Join-Path $root 'A.cs') "Console.WriteLine(1);`n[Fact] void T() { }`n"
                Put (Join-Path $root 'a.ts') "console.log(1);`nit('x', () => {});`n"
                Put (Join-Path $root 'coverage.cobertura.xml') '<coverage line-rate="0.5"></coverage>'
                $result = RunHere $subject $root
                Assert ($result.Exit -eq 0) "metrics failed for $subject at $root`: $($result.Err)"
                $jsons += ,($result.Out | ConvertFrom-Json)
            }
            Assert ($jsons[0].readiness.coverage_pct -eq 50) "the plain path did not read the coverage file: $($jsons[0].readiness.coverage_pct)"
            Assert ($jsons[1].readiness.coverage_pct -eq 50) "the bracketed path lost the coverage file: $($jsons[1].readiness.coverage_pct)"
            $plain = $jsons[0].metrics | ConvertTo-Json -Compress; $bracketed = $jsons[1].metrics | ConvertTo-Json -Compress
            Assert ($plain -eq $bracketed) "the bracketed path counted differently for $subject`: $bracketed, plain $plain"
            Assert (($jsons[1].metrics.psobject.Properties.Value | Measure-Object -Sum).Sum -gt 0) 'nothing was counted at the bracketed path'
        } finally { foreach ($root in $roots) { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue } }
    }
}

It 'metrics resolves a relative scope against the caller, not the repository root' {
    foreach ($subject in @(MetricsSubjects)) {
        $root = Temp metrics-scope
        try {
            InitSafe $root
            Put (Join-Path $root 'web/src/app/A.cs') "Console.WriteLine(1);`n"
            Put (Join-Path $root 'web/src/app/a.ts') "console.log(1);`n"
            Put (Join-Path $root 'other/B.cs') "Console.WriteLine(2);`nConsole.WriteLine(3);`n"
            Put (Join-Path $root 'other/b.ts') "console.log(2);`nconsole.log(3);`n"
            $web = Join-Path $root web
            foreach ($scope in @('src/app', '.')) {
                $result = RunHere $subject $web @($scope)
                Assert ($result.Exit -eq 0) "metrics failed for $subject from web with '$scope': $($result.Err)"
                $json = $result.Out | ConvertFrom-Json
                foreach ($key in @('console_writeline', 'console_log')) {
                    if (MetricKey $json $key) { Assert ([int]$json.metrics.$key -eq 1) "$subject from web with '$scope': $key expected 1 (web only), got $($json.metrics.$key)" }
                }
            }
            $missing = RunHere $subject $web @('src/nowhere')
            Assert ($missing.Exit -ne 0) "a scope that does not resolve must not report a clean run, got exit $($missing.Exit): $($missing.Out)"
        } finally { Remove-Item -Recurse -Force -LiteralPath $root }
    }
}

It 'metrics counts TODO case-sensitively, a wrapped async signature and the NUnit and xUnit attribute forms' {
    foreach ($subject in @(MetricsSubjects)) {
        $root = Temp metrics-exact
        try {
            InitSafe $root
            Put (Join-Path $root 'TodoController.cs') @'
class TodoController { }
// TODO: real
public async Task Wrapped(
    int x,
    CancellationToken ct)
{ }
public async Task Bare() { }
[Fact(DisplayName = "a")] void A() { }
[Theory, InlineData(1)] void B() { }
[Test, Category("c")] void C() { }
[TestCase(1)] void D() { }
[TestMethod] void E() { }
'@
            Put (Join-Path $root 'todo.service.ts') "import { x } from './todo.service';`n// FIXME: real`n"
            $result = RunHere $subject $root
            Assert ($result.Exit -eq 0) "metrics failed for $subject`: $($result.Err)"
            $json = $result.Out | ConvertFrom-Json
            $cs = MetricKey $json 'raw_sql'; $ng = MetricKey $json 'any_type'
            $expectedTodo = ([int]$cs) + ([int]$ng)
            Assert ([int]$json.metrics.todo_hack_fixme -eq $expectedTodo) "$subject`: todo_hack_fixme expected $expectedTodo (the TODO and FIXME comments, not the word todo in a name), got $($json.metrics.todo_hack_fixme)"
            if ($cs) {
                Assert ([int]$json.metrics.async_missing_cancellationtoken -eq 1) "$subject`: async_missing_cancellationtoken expected 1 (Bare), got $($json.metrics.async_missing_cancellationtoken)"
                Assert ([int]$json.metrics.test_attributes -eq 5) "$subject`: test_attributes expected 5, got $($json.metrics.test_attributes)"
                Assert ($json.readiness.has_tests -eq $true) "$subject`: has_tests expected true"
            }
        } finally { Remove-Item -Recurse -Force -LiteralPath $root }
    }
}

exit (Write-TestSummary 'ScriptBehavior.Tests')
