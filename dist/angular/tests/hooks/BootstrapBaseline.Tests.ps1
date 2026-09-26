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
It 'framework-owned and framework document edits alone stop early' {
    $r = Fixture
    try {
        Recorded $r
        Put (Join-Path $r 'scripts/tool.ps1') "'framework v2'"
        Put (Join-Path $r 'AGENTS.md') ((Agents @($claimRepo, $claimDi, $claimCtl, $claimNoSql)) + "`nA note added by hand.`n")
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
        Has $res 'RECORDED claims=3 carried=2 profiles=dotnet'
        $state = [IO.File]::ReadAllText((Join-Path $r $stateRel))
        Assert ([regex]::Matches($state, '(?m)^claim\t').Count -eq 3) "expected 3 claim rows: $state"
        Assert ($state -notmatch 'No SQL migration') 'a claim removed from AGENTS.md was carried forward'
        $after = Impact $r
        ExitIs $after 0; Has $after 'RESULT stop'
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
exit (Write-TestSummary 'BootstrapBaseline.Tests')
