param([string]$Root)
$ErrorActionPreference = 'Stop'
# Read-only validation of Known Hazard Areas. Wildcards validate only their longest leading
# wildcard-free directory prefix; matching the wildcard expression itself is deliberately out of scope.
# Root comes from the argument (docs-sync-check passes it) or self-anchors to scripts/.., never stdin.
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$context = Join-Path $Root 'FRAMEWORK-CONTEXT.md'; $fails=0
function Fail($m){$script:fails++;Write-Output "FAIL: $m"}
if(-not(Test-Path -LiteralPath $context)){Write-Output 'hazard-check skipped (no FRAMEWORK-CONTEXT.md).';exit 0}
$raw=[IO.File]::ReadAllText($context).TrimStart([char]0xFEFF)-replace"`r",''
if($raw-match'KNOWN_HAZARD_AREAS_PENDING'){Write-Output 'hazard-check skipped (hazard table not yet drafted).';exit 0}
if($raw-notmatch'(?m)^## Known Hazard Areas\s*$'){Write-Output 'hazard-check skipped (no Known Hazard Areas section).';exit 0}
$inHazards=$false
foreach($line in ($raw-split"`n")){
 if($line-match'^## Known Hazard Areas\s*$'){$inHazards=$true;continue}
 if($inHazards-and$line-match'^## '){break}
 if(-not$inHazards-or$line-notmatch'^\|'){continue}
 $cells=@($line.Split('|')|ForEach-Object{$_.Trim()});$nonempty=@($cells|Where-Object{$_-ne''})
 $area=$(if($cells.Count-gt1){$cells[1]}else{''})
 if($area-eq'Area / file(s)'){continue}
 if($nonempty.Count-gt0-and@($nonempty|Where-Object{$_-notmatch'^[-:]+$'}).Count-eq0){continue}
 if($area-eq'_(drafted by /bootstrap)_'){continue}
 if($cells.Count-ne6){Fail "hazard row does not have 4 cells: $line";continue}
 $hazard=$cells[2];$status=$cells[3];$reviewed=$cells[4]
 if($status-notin@('[VERIFIED]','[SUSPECTED]','[UNVERIFIED]')-and-not$status.StartsWith('[REVIEWED: not a hazard')){Fail "hazard row has an unrecognised Status '$status' (expected [VERIFIED], [SUSPECTED], [UNVERIFIED], or [REVIEWED: not a hazard ...]): $area"}
 $dateOK=$reviewed-match'^[0-9]{4}-[0-9]{2}-[0-9]{2}$';if($dateOK){try{$null=[datetime]::ParseExact($reviewed,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)}catch{$dateOK=$false}}
 if(-not$dateOK){Fail "hazard row has an invalid Reviewed date '$reviewed' (expected YYYY-MM-DD): $area"}
 $candidates=@();$without=$area
 foreach($m in [regex]::Matches($area,'`([^`]*)`')){$candidates+=$m.Groups[1].Value}
 $without=[regex]::Replace($without,'`[^`]*`',' ');$candidates+=@($without-split'[\s,]+'|Where-Object{$_})
 foreach($rawCandidate in $candidates){
  $candidate=$rawCandidate.Trim('(',')','"',"'").TrimEnd(',','.',';',':')
  if(-not($candidate-match'/'-or$candidate-match'\.[A-Za-z0-9]{1,10}$')){continue}
  if($candidate-match'^[A-Za-z][A-Za-z0-9+.-]*://'-or$candidate.StartsWith('www.')){continue}
  if(-not$candidate){continue};$candidate=$candidate-replace'\\','/';$candidate=$candidate-replace'^\./',''
  # Decide the resolution mode BEFORE wildcard truncation: truncating 'src/ap*p/x' yields 'src', which
  # has no '/' left but is still a directory path, not a bare filename.
  $rooted=$candidate-match'/'
  if($candidate-match'[?*]'){$parts=@($candidate-split'/');$keep=@();foreach($part in $parts){if($part-match'[?*]'){break};$keep+=$part};$candidate=$keep-join'/';if(-not$candidate){continue}}
  # A candidate with no '/' is a bare filename. /bootstrap drafts this cell freely, so a row naming
  # just 'PaymentService.cs' is normal -- resolving that against the repo root would fail a blocking
  # gate on ordinary input. Match it anywhere in the tree instead; a renamed or deleted file, which is
  # the defect this check exists to catch, still has no match. Ordinal (case-sensitive) so the bash
  # twin agrees. -Force is required or dot-directories are skipped on Linux and not on Windows.
  if($rooted){if(-not(Test-Path -LiteralPath (Join-Path $Root $candidate))){Fail "hazard row names a path that does not exist: $candidate (row: $area)"};continue}
  if($null-eq$names){$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($f in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue|Where-Object{$_.FullName-notmatch'[\\/](\.git|node_modules|bin|obj|dist)[\\/]'})){$null=$names.Add($f.Name)}}
  if(-not$names.Contains($candidate)){Fail "hazard row names a path that does not exist: $candidate (row: $area)"}
 }
}
if($fails){Write-Output "$fails hazard-check failure(s).";exit 1};Write-Output 'hazard-check passed.';exit 0
