# bootstrap-baseline PowerShell behavioral tests: record a /bootstrap baseline, then report what a
# later /rebootstrap must re-analyse. Every case builds its own throwaway Git repository.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$baselinePs = Join-Path $scripts 'bootstrap-baseline.ps1'
$stateRel = '.claude/bootstrap-baseline.tsv'

$claimRepo = 'Data access goes through OrderRepository for every order aggregate.'
$claimDi = 'Services are registered in ServiceRegistration.AddOrders during startup.'
$claimCtl = 'Every API controller derives from ApiControllerBase.'
$claimNoSql = 'No SQL migration scripts are checked in; schema changes ship through EF Core.'

function Put([string]$Path, [string]$Text) {
    $dir = Split-Path $Path -Parent
    if ($dir) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}
function G([string]$Root, [string[]]$GitArgs) {
    $out = & git -C $Root -c user.name=test -c user.email=test@example.invalid -c init.defaultBranch=main @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed: $($out -join ' ')" }
}
function Agents([string[]]$Claims) {
    "# Project`n`n## Conventions`n`n" + (($Claims | ForEach-Object { "- $_" }) -join "`n") + "`n"
}
function Fixture {
    $r = Join-Path ([IO.Path]::GetTempPath()) ('baseline-' + [guid]::NewGuid())
    [IO.Directory]::CreateDirectory($r) | Out-Null
    Put (Join-Path $r 'framework-ownership.json') ('{ "schema-version": 1, "paths": [' +
        '{ "path": "AGENTS.md", "ownership": "consumer-owned/protected" },' +
        '{ "path": "framework-ownership.json", "ownership": "framework-owned/overwritten" },' +
        '{ "path": "scripts/tool.ps1", "ownership": "framework-owned/overwritten" } ] }')
    Put (Join-Path $r 'AGENTS.md') (Agents @($claimRepo, $claimDi, $claimCtl, $claimNoSql))
    Put (Join-Path $r 'scripts/tool.ps1') "'framework'"
    Put (Join-Path $r 'README.md') 'readme'
    Put (Join-Path $r 'Orders.sln') 'solution'
    Put (Join-Path $r 'src/Orders/Orders.csproj') '<Project />'
    Put (Join-Path $r 'src/Orders/Data/OrderRepository.cs') 'class OrderRepository {}'
    Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') 'static class ServiceRegistration {}'
    Put (Join-Path $r 'src/Orders/Api/Controllers/OrdersController.cs') 'class OrdersController : ApiControllerBase {}'
    G $r @('init', '-q')
    G $r @('add', '-A')
    G $r @('commit', '-q', '-m', 'fixture')
    $r
}
function Claim([string]$Pass, [string]$Kind, [string]$Text, [string[]]$Evidence) {
    [ordered]@{ profile = 'dotnet'; pass = $Pass; kind = $Kind; text = $Text; evidence = $Evidence }
}
function AllClaims {
    @(
        (Claim 'A2' 'scoped' $claimRepo @('src/Orders/Data/OrderRepository.cs')),
        (Claim 'A3' 'scoped' $claimDi @('src/Orders/Api/ServiceRegistration.cs')),
        (Claim 'A4' 'universal' $claimCtl @('src/Orders/Api/Controllers/*.cs')),
        (Claim 'A2' 'absence' $claimNoSql @('**/Migrations/*.sql'))
    )
}
function ClaimsFile($Claims, [string[]]$Profiles = @('dotnet')) {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('claims-' + [guid]::NewGuid() + '.json')
    Put $path (ConvertTo-Json -Depth 6 -InputObject ([ordered]@{ profiles = $Profiles; claims = @($Claims) }))
    $path
}
function Record([string]$Root, $Claims = (AllClaims)) {
    $file = ClaimsFile $Claims
    try { RunArg $baselinePs @('-Mode', 'Record', '-Root', $Root, '-ClaimsPath', $file) }
    finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
}
function Impact([string]$Root) { RunArg $baselinePs @('-Mode', 'Impact', '-Root', $Root) }
function Recorded([string]$Root) {
    $res = Record $Root
    Assert ($res.Exit -eq 0) "record exit $($res.Exit): $($res.Out) $($res.Err)"
}
function Has($Result, [string]$Line) {
    Assert ($Result.Out -match ('(?m)^' + [regex]::Escape($Line) + '\r?$')) "missing line '$Line' in: $($Result.Out) $($Result.Err)"
}
function HasNot($Result, [string]$Pattern) {
    Assert ($Result.Out -notmatch $Pattern) "unexpected match '$Pattern' in: $($Result.Out)"
}
function ExitIs($Result, [int]$Expected) {
    Assert ($Result.Exit -eq $Expected) "exit $($Result.Exit), expected $($Expected): $($Result.Out) $($Result.Err)"
}
function Drop([string]$Root) { Remove-Item -Recurse -Force -LiteralPath $Root -ErrorAction SilentlyContinue }
function Relocate([string]$Root, [string]$From, [string]$To) {
    $target = Join-Path $Root $To
    [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    [IO.File]::Move((Join-Path $Root $From), $target)
}
function Hazards([string]$Root, [string]$Area) {
    Put (Join-Path $Root 'FRAMEWORK-CONTEXT.md') ("# Context`n`n## Known Hazard Areas`n`n| Area / file(s) | Hazard | Status | Reviewed |`n" +
        "|---|---|---|---|`n| $Area | Registration order is load-bearing. | [VERIFIED] | 2026-09-01 |`n`n## Shared Libraries`n")
}

Reset-Tests
It 'fixture repository commits every fixture file' {
    $r = Fixture
    try {
        $tracked = @(& git -C $r ls-files)
        Assert ($tracked.Count -eq 9) "expected 9 tracked fixture files, got $($tracked.Count): $($tracked -join ', ')"
    } finally { Drop $r }
}
It 'an unchanged repository stops before any re-analysis' {
    $r = Fixture
    try {
        Recorded $r
        Assert (Test-Path -LiteralPath (Join-Path $r $stateRel)) 'record did not write the baseline file'
        $res = Impact $r
        ExitIs $res 0; Has $res 'CHANGED-AREAS 0'; Has $res 'RESULT stop'
        HasNot $res '(?m)^(PROFILE|CLAIM|RECHECK|EDITED) '
        $state = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        Assert ($state -notmatch "[ \t]\n") 'a baseline row ends in whitespace an editor would strip'
    } finally { Drop $r }
}
It 'a missing baseline asks for a full run and says it could not examine' {
    $r = Fixture
    try {
        $res = Impact $r
        ExitIs $res 3; Has $res 'RESULT full'
        Assert ($res.Out -match '(?m)^BASELINE none .*cannot examine') "no cannot-examine baseline line: $($res.Out)"
    } finally { Drop $r }
}
It 'a changed evidence file marks only its own claim affected' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Orders/Data/OrderRepository.cs') 'class OrderRepository { void Save() {} }'
        G $r @('commit', '-q', '-am', 'change repository')
        $res = Impact $r
        ExitIs $res 0
        Has $res 'AREA src/Orders/Data'
        Has $res 'PROFILE dotnet incremental affected=1/4 (25%) reason=none'
        Assert ($res.Out -match '(?m)^CLAIM changed-evidence [0-9a-f]{12} dotnet/A2: Data access goes through OrderRepository') "no changed-evidence line: $($res.Out)"
        HasNot $res 'ServiceRegistration\.AddOrders'
        Has $res 'RESULT incremental'
    } finally { Drop $r }
}
It 'an uncommitted edit counts as a change' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') 'static class ServiceRegistration { static void AddOrders() {} }'
        $res = Impact $r
        ExitIs $res 0
        Assert ($res.Out -match '(?m)^CLAIM changed-evidence [0-9a-f]{12} dotnet/A3: ') "uncommitted edit not seen: $($res.Out)"
    } finally { Drop $r }
}
It 'framework-owned edits and a new version comment alone stop early' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'scripts/tool.ps1') "'framework v2'"
        Put (Join-Path $r 'AGENTS.md') ("<!--`n  version: 2.0.0`n-->`n" + (Agents @($claimRepo, $claimDi, $claimCtl, $claimNoSql)))
        G $r @('commit', '-q', '-am', 'framework update')
        $res = Impact $r
        ExitIs $res 0; Has $res 'CHANGED-AREAS 0'; Has $res 'RESULT stop'
    } finally { Drop $r }
}
It 'a hand-edited claim is affected' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'AGENTS.md') (Agents @($claimRepo, 'Services are registered by assembly scanning.', $claimCtl, $claimNoSql))
        $res = Impact $r
        ExitIs $res 0
        Assert ($res.Out -match '(?m)^CLAIM edited-or-removed [0-9a-f]{12} dotnet/A3: Services are registered in ServiceRegistration') "edited claim not reported: $($res.Out)"
        Has $res 'RESULT incremental'
    } finally { Drop $r }
}
It 'a line added to AGENTS.md by hand is reported and blocks the early stop' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'AGENTS.md') (Agents @($claimRepo, $claimDi, $claimCtl, $claimNoSql, 'All domain services are sealed classes.'))
        $res = Impact $r
        ExitIs $res 0; Has $res 'CHANGED-AREAS 0'
        Has $res 'EDITED - All domain services are sealed classes.'
        Has $res 'RESULT incremental'
        HasNot $res '(?m)^RECHECK '
    } finally { Drop $r }
}
It 'a reworded claim that keeps its old sentence is reported as edited' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'AGENTS.md') (Agents @($claimRepo, $claimDi, ($claimCtl + ' Legacy controllers are exempt.'), $claimNoSql))
        $res = Impact $r
        ExitIs $res 0
        Has $res "EDITED - $claimCtl Legacy controllers are exempt."
        Has $res 'RESULT incremental'
    } finally { Drop $r }
}
It 'every changed area is listed, however many' {
    $r = Fixture
    try {
        Recorded $r
        for ($i = 0; $i -lt 55; $i++) { Put (Join-Path $r "lib/Mod$i/Thing.cs") "class Thing$i {}" }
        $res = Impact $r
        ExitIs $res 0; Has $res 'CHANGED-AREAS 55'
        $listed = [regex]::Matches($res.Out, '(?m)^AREA lib/Mod[0-9]+\r?$').Count
        Assert ($listed -eq 55) "expected 55 AREA lines, got $listed"
    } finally { Drop $r }
}
It 'the same claim text may be recorded under two profiles' {
    $r = Fixture
    try {
        $shared = @((Claim 'A1' 'scoped' $claimDi @('src/Orders/Api/ServiceRegistration.cs')),
            [ordered]@{ profile = 'angular'; pass = 'A1'; kind = 'scoped'; text = $claimDi; evidence = @('README.md') })
        $file = ClaimsFile $shared @('dotnet', 'angular')
        try { $res = RunArg $baselinePs @('-Mode', 'Record', '-Root', $r, '-ClaimsPath', $file) }
        finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
        ExitIs $res 0; Has $res 'RECORDED claims=2 carried=0 unclaimed=3 profiles=dotnet,angular'
    } finally { Drop $r }
}
It 'evidence that now matches no file is reported, not carried forward' {
    $r = Fixture
    try {
        Recorded $r
        G $r @('rm', '-q', 'src/Orders/Api/Controllers/OrdersController.cs')
        $res = Impact $r
        ExitIs $res 0
        Assert ($res.Out -match '(?m)^CLAIM no-evidence-match [0-9a-f]{12} dotnet/A4: Every API controller') "dead evidence not reported: $($res.Out)"
    } finally { Drop $r }
}
It 'a new file deep in a tree is reported at its depth-three area and rechecks universal and absence claims' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Orders/Api/Controllers/Admin/Legacy/AdminController.cs') 'class AdminController {}'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'CHANGED-AREAS 1'; Has $res 'AREA src/Orders/Api'
        Has $res 'PROFILE dotnet incremental affected=0/4 (0%) reason=none'
        Assert ($res.Out -match '(?m)^RECHECK universal [0-9a-f]{12} dotnet/A4: ') "universal claim not rechecked: $($res.Out)"
        Assert ($res.Out -match '(?m)^RECHECK absence [0-9a-f]{12} dotnet/A2: No SQL migration') "absence claim not rechecked: $($res.Out)"
        HasNot $res '(?m)^CLAIM '
    } finally { Drop $r }
}
It 'a file that now matches an absence claim makes it affected' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'db/Migrations/001_init.sql') 'create table t (id int);'
        $res = Impact $r
        ExitIs $res 0
        Assert ($res.Out -match '(?m)^CLAIM changed-evidence [0-9a-f]{12} dotnet/A2: No SQL migration') "absence claim not affected: $($res.Out)"
    } finally { Drop $r }
}
It 'a new project manifest forces a full run of its profile' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Billing/Billing.csproj') '<Project />'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'PROFILE dotnet full affected=0/4 (0%) reason=manifest src/Billing/Billing.csproj'
        Has $res 'RESULT full'
        HasNot $res '(?m)^RECHECK '
    } finally { Drop $r }
}
It 'a changed project manifest body alone does not force a full run' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Orders/Orders.csproj') '<Project><ItemGroup /></Project>'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'PROFILE dotnet incremental affected=0/4 (0%) reason=none'
    } finally { Drop $r }
}
It 'more than half of a profile claims affected forces a full run' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Orders/Data/OrderRepository.cs') 'changed 1'
        Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') 'changed 2'
        Put (Join-Path $r 'src/Orders/Api/Controllers/OrdersController.cs') 'changed 3'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'PROFILE dotnet full affected=3/4 (75%) reason=threshold'
        Has $res 'RESULT full'
    } finally { Drop $r }
}
It 'record refuses a claim whose text is not in AGENTS.md and writes nothing' {
    $r = Fixture
    try {
        $res = Record $r @((Claim 'A1' 'scoped' 'This sentence appears nowhere in the instructions.' @('README.md')))
        ExitIs $res 1
        Assert ($res.Out -match 'INVALID: .*not found in AGENTS\.md') "no invalid-claim message: $($res.Out)"
        Assert (-not (Test-Path -LiteralPath (Join-Path $r $stateRel))) 'a refused record still wrote the baseline'
    } finally { Drop $r }
}
It 'record refuses scoped evidence that matches no file' {
    $r = Fixture
    try {
        $res = Record $r @((Claim 'A2' 'scoped' $claimRepo @('src/Orders/Data/Missing*.cs')))
        ExitIs $res 1
        Assert ($res.Out -match 'INVALID: .*matches no file') "no dead-evidence message: $($res.Out)"
    } finally { Drop $r }
}
It 'framework-owned files cannot be claim evidence' {
    $r = Fixture
    try {
        $res = Record $r @((Claim 'A2' 'scoped' $claimRepo @('scripts/tool.ps1')))
        ExitIs $res 1
        Assert ($res.Out -match 'INVALID: .*matches no file') "framework-owned evidence was accepted: $($res.Out)"
    } finally { Drop $r }
}
It 'record carries forward unlisted claims still in AGENTS.md and drops removed ones' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'AGENTS.md') (Agents @($claimRepo, $claimDi, $claimCtl))
        $res = Record $r @((Claim 'A2' 'scoped' $claimRepo @('src/Orders/Data/OrderRepository.cs')))
        ExitIs $res 0
        Has $res 'RECORDED claims=3 carried=2 unclaimed=0 profiles=dotnet'
        $state = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        Assert ([regex]::Matches($state, '(?m)^claim\t').Count -eq 3) "expected 3 claim rows: $state"
        Assert ($state -notmatch 'No SQL migration') 'a claim removed from AGENTS.md was carried forward'
        $after = Impact $r
        ExitIs $after 0; Has $after 'RESULT stop'
    } finally { Drop $r }
}
It 'a claim carried forward with evidence that had already changed is still reported' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') 'static class ServiceRegistration { static void AddOrders() {} }'
        G $r @('commit', '-q', '-am', 'change registration')
        # A run that found the registration claim wrong but applied no change leaves it unlisted.
        $res = Record $r @((Claim 'A2' 'scoped' $claimRepo @('src/Orders/Data/OrderRepository.cs')))
        ExitIs $res 0
        $after = Impact $r
        ExitIs $after 0; Has $after 'CHANGED-AREAS 0'
        Assert ($after.Out -match '(?m)^CLAIM changed-evidence [0-9a-f]{12} dotnet/A3: Services are registered') "a stale carried claim was not reported: $($after.Out)"
        Has $after 'RESULT incremental'
    } finally { Drop $r }
}
It 'a UTF-8 console with a byte-order mark still lets record and impact hash the tree' {
    # Windows PowerShell 5.1 opens a child's redirected stdin with the console input encoding and writes
    # its preamble first, so under a UTF-8 console git read a byte-order mark before the first path.
    $r = Fixture
    $previous = [Console]::InputEncoding
    try {
        try { [Console]::InputEncoding = New-Object Text.UTF8Encoding($true) } catch { }
        $res = Record $r
        ExitIs $res 0
        $after = Impact $r
        ExitIs $after 0; Has $after 'RESULT stop'
    } finally {
        try { [Console]::InputEncoding = $previous } catch { }
        Drop $r
    }
}
It 'record refuses a claim that is only part of a statement and names the whole statement' {
    $r = Fixture
    try {
        $res = Record $r @((Claim 'A2' 'scoped' 'Data access goes through OrderRepository' @('src/Orders/Data/OrderRepository.cs')))
        ExitIs $res 1
        Has $res "INVALID: claim 'Data access goes through OrderRepository' is not one whole statement; copy the whole statement: $claimRepo"
    } finally { Drop $r }
}
It 'a baseline claim that is only part of a statement is reported and not carried forward' {
    $r = Fixture
    try {
        Recorded $r
        # A record made before whole statements were required could hold a fragment as a claim.
        $state = Join-Path $r $stateRel
        $partial = [IO.File]::ReadAllText($state).Replace("`tscoped`t$claimRepo`n", "`tscoped`tData access goes through OrderRepository`n")
        Assert ($partial.Contains("`tscoped`tData access goes through OrderRepository`n")) 'fixture did not plant the partial claim'
        Put $state $partial
        $after = Impact $r
        ExitIs $after 0
        Assert ($after.Out -match '(?m)^CLAIM edited-or-removed [0-9a-f]{12} dotnet/A2: Data access goes through OrderRepository\r?$') "a partial claim was treated as current: $($after.Out)"
        Has $after 'RESULT incremental'
        $res = Record $r @()
        ExitIs $res 0
        Has $res "UNCLAIMED $claimRepo"
        Has $res 'RECORDED claims=3 carried=3 unclaimed=1 profiles=dotnet'
    } finally { Drop $r }
}
It 'record names each Conventions or Architecture Decisions statement no claim covers' {
    $r = Fixture
    try {
        $extra = 'Every repository method is async and takes a CancellationToken.'
        $adr = 'ADR-001 — Orders keep one aggregate per request — 2026-09-27'
        Put (Join-Path $r 'AGENTS.md') ((Agents @($claimRepo, $claimDi, $claimCtl, $claimNoSql, $extra)) +
            "`n### Verification Commands`n`n- build: dotnet build Orders.sln`n`n## Architecture Decisions`n`n- $adr`n`n## Common Tasks`n`n- add-endpoint: add an HTTP endpoint`n")
        $res = Record $r
        ExitIs $res 0
        Has $res "UNCLAIMED $extra"
        Has $res "UNCLAIMED $adr"
        HasNot $res 'UNCLAIMED .*(dotnet build|add-endpoint)'
        Has $res 'RECORDED claims=4 carried=0 unclaimed=2 profiles=dotnet'
    } finally { Drop $r }
}
It 'a file moved unchanged is followed, named for its hazard row and re-pointed by the next record' {
    $r = Fixture
    try {
        Hazards $r '`src/Orders/Api/ServiceRegistration.cs` (startup wiring)'
        Recorded $r
        Relocate $r 'src/Orders/Data/OrderRepository.cs' 'src/Sales/Data/OrderRepository.cs'
        Relocate $r 'src/Orders/Api/ServiceRegistration.cs' 'src/Orders/Startup/ServiceRegistration.cs'
        Relocate $r 'src/Orders/Api/Controllers/OrdersController.cs' 'src/Orders/Api/Controllers/SalesController.cs'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'RENAMED src/Orders/Api/ServiceRegistration.cs -> src/Orders/Startup/ServiceRegistration.cs'
        Has $res 'RENAMED src/Orders/Data/OrderRepository.cs -> src/Sales/Data/OrderRepository.cs'
        Has $res 'RENAMED src/Orders/Api/Controllers/OrdersController.cs -> src/Orders/Api/Controllers/SalesController.cs'
        Has $res 'PROFILE dotnet incremental affected=0/4 (0%) reason=none'
        HasNot $res '(?m)^CLAIM '
        $again = Record $r @()
        ExitIs $again 0
        $after = Impact $r
        ExitIs $after 0; Has $after 'RESULT stop'
        HasNot $after '(?m)^RENAMED '
    } finally { Drop $r }
}
It 'a file moved and changed, or out of a folder its claim names, is still rechecked and never re-pointed' {
    $r = Fixture
    try {
        Hazards $r '`src/Orders/Api/ServiceRegistration.cs`'
        Recorded $r
        # "Data access goes through ..." names the Data folder the repository leaves.
        Relocate $r 'src/Orders/Data/OrderRepository.cs' 'src/Orders/Persistence/OrderRepository.cs'
        Relocate $r 'src/Orders/Api/ServiceRegistration.cs' 'src/Orders/Startup/ServiceRegistration.cs'
        Put (Join-Path $r 'src/Orders/Startup/ServiceRegistration.cs') 'static class ServiceRegistration { static void AddOrders() {} }'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'RENAMED src/Orders/Data/OrderRepository.cs -> src/Orders/Persistence/OrderRepository.cs'
        HasNot $res 'RENAMED src/Orders/Api/'
        Assert ($res.Out -match '(?m)^CLAIM names-old-path [0-9a-f]{12} dotnet/A2: Data access goes through') "a claim naming the old folder was followed: $($res.Out)"
        Assert ($res.Out -match '(?m)^CLAIM no-evidence-match [0-9a-f]{12} dotnet/A3: Services are registered') "a moved and changed file was followed: $($res.Out)"
        $again = Record $r @()
        ExitIs $again 0
        $after = Impact $r
        ExitIs $after 0
        Assert ($after.Out -match '(?m)^CLAIM names-old-path [0-9a-f]{12} dotnet/A2: ') "record re-pointed a claim that names the old folder: $($after.Out)"
    } finally { Drop $r }
}
It 'a file moved out of the glob its claim rests on is not followed' {
    $r = Fixture
    try {
        Recorded $r
        Relocate $r 'src/Orders/Api/Controllers/OrdersController.cs' 'src/Orders/Api/OrdersController.cs'
        $res = Impact $r
        ExitIs $res 0
        Assert ($res.Out -match '(?m)^CLAIM no-evidence-match [0-9a-f]{12} dotnet/A4: Every API controller') "a file that left its glob was followed: $($res.Out)"
    } finally { Drop $r }
}
It 'untracked tool output and framework backups are not recorded, so a fresh clone stops' {
    $r = Fixture
    $c = Join-Path ([IO.Path]::GetTempPath()) ('baseline-clone-' + [guid]::NewGuid())
    try {
        # A developer's own ng serve / ng test --code-coverage output, an update's skill backup and a killed
        # record's write file, none of which the repository's ignore rules catch or a teammate's clone holds.
        Put (Join-Path $r '.angular/cache/20.3.4/orders/angular-compiler.db') 'cache'
        Put (Join-Path $r 'coverage/orders/index.html') 'coverage'
        Put (Join-Path $r 'out-tsc/spec/app.spec.js') 'compiled spec'
        Put (Join-Path $r 'tmp/notes.md') 'scratch'
        Put (Join-Path $r 'dist/orders/main.js') 'build'
        Put (Join-Path $r 'bazel-out/k8-fastbuild/bin/x.js') 'bazel'
        Put (Join-Path $r '.nx/workspace-data/project-graph.json') 'nx'
        Put (Join-Path $r 'web/node_modules/lib/index.js') 'package'
        # Vitest browser mode's failure screenshots, beside the spec; the CLI's .gitignore lists them only from 20.3.3.
        Put (Join-Path $r 'src/app/__screenshots__/app.spec.ts/renders-1.png') 'screenshot'
        Put (Join-Path $r '.claude/framework-update-backup/skills/create-adr/SKILL.md') 'backup'
        Put (Join-Path $r '.claude/bootstrap-baseline.tsv.tmp') "schema`t1`n"
        Recorded $r
        $state = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        Assert ($state -notmatch '(?m)^area\t(\.angular|coverage|out-tsc|tmp|dist|bazel-out|\.nx|web/node_modules|src/app/__screenshots__|\.claude/framework-update-backup|\.claude\t)') "machine-local output was recorded: $state"
        G $r @('add', '--', $stateRel)
        G $r @('commit', '-q', '-m', 'baseline')
        G $r @('clone', '-q', $r, $c)
        $res = Impact $c
        ExitIs $res 0; Has $res 'CHANGED-AREAS 0'; Has $res 'RESULT stop'
    } finally { Drop $r; Drop $c }
}
It 'a new uncommitted file in an application folder named like tool output still counts' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'src/Billing/tmp/InvoiceDraft.cs') 'class InvoiceDraft {}'
        $res = Impact $r
        ExitIs $res 0
        Has $res 'AREA src/Billing/tmp'
        HasNot $res '(?m)^RESULT stop'
    } finally { Drop $r }
}
It 'a baseline recorded under one core.autocrlf setting reports no drift under another, for LF blobs and CRLF blobs alike' {
    # git hash-object runs the clean filter: a machine with core.autocrlf=true hashed a blob that holds CRLF as LF,
    # and one with false hashed it as stored, so two teammates recorded different hashes for an unchanged file.
    $r = Fixture
    $c = Join-Path ([IO.Path]::GetTempPath()) ('baseline-eol-' + [guid]::NewGuid())
    try {
        G $r @('config', 'core.autocrlf', 'false')
        Put (Join-Path $r 'src/Orders/Data/OrderRepository.cs') "class OrderRepository {`n    void Save() {}`n}`n"
        Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') "static class ServiceRegistration {`r`n    static void AddOrders() {}`r`n}`r`n"
        G $r @('add', '-A'); G $r @('commit', '-q', '-m', 'sources with line endings')
        Recorded $r
        G $r @('add', '--', $stateRel); G $r @('commit', '-q', '-m', 'baseline')
        # The same tree under another developer's setting.
        G $r @('config', 'core.autocrlf', 'true')
        $same = Impact $r
        ExitIs $same 0; Has $same 'CHANGED-AREAS 0'; Has $same 'RESULT stop'
        G $r @('config', 'core.autocrlf', 'false')
        # A clone with core.autocrlf=true checks the LF blob out as CRLF, and holds the CRLF blob as it is.
        G $r @('clone', '-q', '-c', 'core.autocrlf=true', $r, $c)
        $lf = [IO.File]::ReadAllText((Join-Path $c 'src/Orders/Data/OrderRepository.cs'))
        Assert ($lf.Contains("`r`n")) 'the clone did not check the LF blob out as CRLF, so nothing was examined'
        $clone = Impact $c
        ExitIs $clone 0; Has $clone 'CHANGED-AREAS 0'; Has $clone 'RESULT stop'
        # And the other way round: a baseline recorded in the CRLF clone is accepted by the first tree.
        Recorded $c
        [IO.File]::Copy((Join-Path $c $stateRel), (Join-Path $r $stateRel), $true)
        $back = Impact $r
        ExitIs $back 0; Has $back 'CHANGED-AREAS 0'; Has $back 'RESULT stop'
    } finally { Drop $r; Drop $c }
}
function AsSchemaOne([string]$State) {
    # The baseline an earlier release wrote for AllClaims: schema 1, one evidence row per matched file, '-' for a claim of absence.
    $blob = @{}
    foreach ($m in [regex]::Matches($State, '(?m)^file\t([^\t\n]+)\t([0-9a-f]{40})$')) { $blob[$m.Groups[1].Value] = $m.Groups[2].Value }
    $expand = @{
        'src/Orders/Data/OrderRepository.cs'   = @('src/Orders/Data/OrderRepository.cs')
        'src/Orders/Api/ServiceRegistration.cs' = @('src/Orders/Api/ServiceRegistration.cs')
        'src/Orders/Api/Controllers/*.cs'      = @('src/Orders/Api/Controllers/OrdersController.cs')
        '**/Migrations/*.sql'                  = @()
    }
    $rows = foreach ($line in $State.Split("`n")) {
        if (-not $line -or $line.StartsWith("file`t")) { continue }
        if ($line -eq "schema`t2") { "schema`t1"; continue }
        $f = $line.Split("`t")
        if ($f[0] -eq 'evidence' -and $f.Count -eq 3) {
            if ($expand[$f[2]].Count -eq 0) { "evidence`t$($f[1])`t$($f[2])`t-`t-" }
            foreach ($path in $expand[$f[2]]) { "evidence`t$($f[1])`t$($f[2])`t$path`t$($blob[$path])" }
            continue
        }
        $line
    }
    ($rows -join "`n") + "`n"
}
It 'claims sharing a glob record each matched file once, and an evidence row names its pattern only' {
    $r = Fixture
    try {
        $extra = @(1..30 | ForEach-Object { "Module $_ follows the layered convention." })
        Put (Join-Path $r 'AGENTS.md') (Agents (@($claimRepo, $claimDi, $claimCtl, $claimNoSql) + $extra))
        $claims = @(AllClaims) + @($extra | ForEach-Object { Claim 'B1' 'scoped' $_ @('src/Orders/**/*.cs') })
        $res = Record $r $claims
        ExitIs $res 0
        $state = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        Assert ($state -match "(?m)^schema`t2$") "the record is not in the compact schema: $state"
        $paths = @([regex]::Matches($state, '(?m)^file\t([^\t\n]+)\t[0-9a-f]{40}$') | ForEach-Object { $_.Groups[1].Value })
        Assert ($paths.Count -eq 3) "expected the three matched .cs files once each, got $($paths.Count): $($paths -join ', ')"
        $ordered = [string[]]$paths.Clone(); [Array]::Sort($ordered, [StringComparer]::Ordinal)
        Assert (($ordered -join "`n") -ceq ($paths -join "`n")) "file rows are not in ordinal order: $($paths -join ', ')"
        $narrow = [regex]::Matches($state, '(?m)^evidence\t[0-9a-f]{12}\t[^\t\n]+$').Count
        Assert ($narrow -eq 34) "expected one pattern-only evidence row per claim and pattern (34), got $narrow"
        Assert ($state -notmatch '(?m)^evidence\t[0-9a-f]{12}\t[^\t\n]+\t') 'an evidence row still lists a path'
        $after = Impact $r
        ExitIs $after 0; Has $after 'CHANGED-AREAS 0'; Has $after 'RESULT stop'
    } finally { Drop $r }
}
It 'a baseline in the previous schema is still read, and the next record rewrites it' {
    $r = Fixture
    try {
        Recorded $r
        $state = Join-Path $r $stateRel
        Put $state (AsSchemaOne ([IO.File]::ReadAllText($state)))
        Assert ([IO.File]::ReadAllText($state) -match "(?m)^evidence`t[0-9a-f]{12}`tsrc/Orders/Data/OrderRepository\.cs`tsrc/Orders/Data/OrderRepository\.cs`t[0-9a-f]{40}$") 'the helper did not write a per-file evidence row'
        $same = Impact $r
        ExitIs $same 0; Has $same 'CHANGED-AREAS 0'; Has $same 'RESULT stop'
        Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') 'static class ServiceRegistration { static void AddOrders() {} }'
        $drift = Impact $r
        ExitIs $drift 0; Has $drift 'AREA src/Orders/Api'
        Assert ($drift.Out -match '(?m)^CLAIM changed-evidence [0-9a-f]{12} dotnet/A3: ') "the old baseline missed the changed file: $($drift.Out)"
        $res = Record $r @()
        ExitIs $res 0; Has $res 'RECORDED claims=4 carried=4 unclaimed=0 profiles=dotnet'
        Assert ([IO.File]::ReadAllText($state) -match "(?m)^schema`t2$") 'the next record did not rewrite the baseline in the current schema'
        $after = Impact $r
        ExitIs $after 0; Has $after 'CHANGED-AREAS 0'
        Assert ($after.Out -match '(?m)^CLAIM changed-evidence [0-9a-f]{12} dotnet/A3: ') "carrying the claim forward marked it verified: $($after.Out)"
    } finally { Drop $r }
}
It 'record writes an unlisted claim as its pattern alone when its files are unchanged, and keeps its recorded hashes when they changed' {
    $r = Fixture
    try {
        Recorded $r
        $first = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        $was = [regex]::Match($first, '(?m)^file\tsrc/Orders/Api/ServiceRegistration\.cs\t([0-9a-f]{40})$').Groups[1].Value
        Assert ($was.Length -eq 40) "the first record has no file row for the registration file: $first"
        Put (Join-Path $r 'src/Orders/Api/ServiceRegistration.cs') 'static class ServiceRegistration { static void AddOrders() {} }'
        G $r @('commit', '-q', '-am', 'change registration')
        $res = Record $r @((Claim 'A2' 'scoped' $claimRepo @('src/Orders/Data/OrderRepository.cs')))
        ExitIs $res 0; Has $res 'RECORDED claims=4 carried=3 unclaimed=0 profiles=dotnet'
        $state = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        Assert ($state -match "(?m)^evidence`t[0-9a-f]{12}`tsrc/Orders/Api/ServiceRegistration\.cs`tsrc/Orders/Api/ServiceRegistration\.cs`t$was$") "the changed claim lost its recorded hash: $state"
        Assert ($state -notmatch '(?m)^file\tsrc/Orders/Api/ServiceRegistration\.cs\t') "the changed file was listed under its new hash: $state"
        $narrow = [regex]::Matches($state, '(?m)^evidence\t[0-9a-f]{12}\t[^\t\n]+$').Count
        Assert ($narrow -eq 3) "expected the listed, universal and absence claims as pattern-only rows (3), got $narrow"
    } finally { Drop $r }
}
It 'file rows lost from a baseline read as changed evidence, never as no drift' {
    $r = Fixture
    try {
        Recorded $r
        $state = Join-Path $r $stateRel
        $kept = @([IO.File]::ReadAllText($state).Split("`n") | Where-Object { $_ -notlike "file`t*" })
        Put $state (($kept -join "`n"))
        $res = Impact $r
        ExitIs $res 0
        HasNot $res '(?m)^RESULT stop'
        Has $res 'PROFILE dotnet full affected=3/4 (75%) reason=threshold'
    } finally { Drop $r }
}
It 'a corrupt baseline asks for a full run' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r $stateRel) "schema`t99`n"
        $res = Impact $r
        ExitIs $res 3; Has $res 'RESULT full'
    } finally { Drop $r }
}
It 'a missing ownership inventory cannot be examined' {
    $r = Fixture
    try {
        Recorded $r
        Remove-Item -LiteralPath (Join-Path $r 'framework-ownership.json') -Force
        $res = Impact $r
        ExitIs $res 2
        Assert ($res.Out -match 'CANNOT EXAMINE: .*framework-ownership\.json') "no cannot-examine message: $($res.Out)"
    } finally { Drop $r }
}
It 'a directory outside Git cannot be examined' {
    $r = Join-Path ([IO.Path]::GetTempPath()) ('baseline-nogit-' + [guid]::NewGuid())
    try {
        Put (Join-Path $r 'AGENTS.md') (Agents @($claimRepo))
        $res = Impact $r
        ExitIs $res 2
        Assert ($res.Out -match 'CANNOT EXAMINE: ') "no cannot-examine message: $($res.Out)"
    } finally { Drop $r }
}
It 'an unknown mode is refused as invalid' {
    $r = Fixture
    try {
        $res = RunArg $baselinePs @('-Mode', 'Guess', '-Root', $r)
        ExitIs $res 1
        Assert ($res.Out -match 'INVALID: ') "no invalid message: $($res.Out)"
    } finally { Drop $r }
}
function CultureRecord([string]$Root, [string]$Culture, [string]$Probe, [switch]$CoreOnly) {
    # Runs Record on this thread under a culture whose ICU rules differ from invariant. Exit 3 from the wrapper means
    # the probe did not behave as that culture should, so nothing was examined.
    $claims = ClaimsFile (AllClaims)
    $wrapper = Join-Path ([IO.Path]::GetTempPath()) ('baseline-culture-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Put $wrapper ("[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::new('$Culture')`n" +
            "if (-not ($Probe)) { exit 3 }`n".Replace("if (-not", $(if ($CoreOnly) { "if (`$PSVersionTable.PSEdition -eq 'Core' -and -not" } else { "if (-not" })) +
            "& '" + $baselinePs.Replace("'", "''") + "' -Mode Record -Root '" + $Root.Replace("'", "''") + "' -ClaimsPath '" + $claims.Replace("'", "''") + "'`n" +
            "exit `$LASTEXITCODE`n")
        RunArg $wrapper @()
    } finally { Remove-Item -LiteralPath $wrapper, $claims -Force -ErrorAction SilentlyContinue }
}
It 'record works under th-TH, where the culture-sensitive LastIndexOf of a slash is the string length' {
    $r = Fixture
    try {
        $res = CultureRecord $r 'th-TH' "'a/b/c'.LastIndexOf('/') -eq 5" -CoreOnly
        Assert ($res.Exit -ne 3) 'th-TH did not take in the wrapper, so nothing was examined'
        ExitIs $res 0
    } finally { Drop $r }
}
It 'record writes the recorded date in the Gregorian calendar whatever the culture' {
    $r = Fixture
    try {
        $res = CultureRecord $r 'ar-SA' "[DateTime]::new(2026,10,23).ToString('yyyy') -ne '2026'"
        Assert ($res.Exit -ne 3) 'ar-SA did not take in the wrapper, so nothing was examined'
        ExitIs $res 0
        $line = @([IO.File]::ReadAllLines((Join-Path $r $stateRel)) | Where-Object { $_ -like "recorded`t*" })[0]
        Assert ($line -match "^recorded`t20\d\d-\d\d-\d\d$") "recorded line is not a Gregorian date: $line"
    } finally { Drop $r }
}
It 'a root with a trailing backslash is the same root' {
    $r = Fixture
    try {
        $file = ClaimsFile (AllClaims)
        try { $res = RunArg $baselinePs @('-Mode', 'Record', '-Root', ($r + '\'), '-ClaimsPath', $file) } finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
        ExitIs $res 0
        $after = RunArg $baselinePs @('-Mode', 'Impact', '-Root', ($r + '\'))
        ExitIs $after 0; Has $after 'RESULT stop'
    } finally { Drop $r }
}
It 'git refusing to open one file of a large tree is reported with git''s own message' {
    $r = Fixture
    $held = $null
    try {
        $dir = Join-Path $r 'many'
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        $pad = 'x' * 120
        for ($i = 0; $i -lt 1200; $i++) { [IO.File]::WriteAllText((Join-Path $dir ('b{0:D5}-{1}.txt' -f $i, $pad)), 'x') }
        $first = Join-Path $dir ('a-held-' + $pad + '.txt')
        [IO.File]::WriteAllText($first, 'held')
        $held = [IO.File]::Open($first, 'Open', 'ReadWrite', 'None')
        $res = Record $r
        ExitIs $res 2
        Assert ($res.Out -match 'a-held-') "the message does not name the held file: $($res.Out)"
        Assert ($res.Out -notmatch 'pipe') "git's error was replaced by a pipe failure: $($res.Out)"
    } finally { if ($held) { $held.Dispose() }; Drop $r }
}
It 'a copied UNCLAIMED statement keeps its em dash on a legacy code page console' {
    $r = Fixture
    try {
        $adr = 'ADR-001 — Orders keep one aggregate per request — 2026-09-27'
        Put (Join-Path $r 'AGENTS.md') ((Agents @($claimRepo, $claimDi, $claimCtl, $claimNoSql)) + "`n## Architecture Decisions`n`n- $adr`n")
        $file = ClaimsFile (AllClaims)
        $out = Join-Path ([IO.Path]::GetTempPath()) ('baseline-bytes-' + [guid]::NewGuid().ToString('N') + '.bin')
        try {
            $q = '"'
            $cmd = "set PSModulePath=&& chcp 437 >nul && $q$(Get-PsExe)$q -NoProfile -ExecutionPolicy Bypass -File $q$baselinePs$q -Mode Record -Root $q$r$q -ClaimsPath $q$file$q > $q$out$q"
            $null = & cmd.exe /d /c $cmd
            $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($out))
            Assert ($text.Contains("UNCLAIMED $adr")) "the console wrote the statement through the code page, not UTF-8: $text"
        } finally { Remove-Item -LiteralPath $file, $out -Force -ErrorAction SilentlyContinue }
    } finally { Drop $r }
}
exit (Write-TestSummary 'BootstrapBaseline.Tests')
