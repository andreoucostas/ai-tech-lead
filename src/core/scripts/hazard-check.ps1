param([string]$Root)
$ErrorActionPreference = 'Stop'
# Read-only validation of Known Hazard Areas. Only literal repository-root-relative paths satisfy
# row evidence; URLs, symbols, and wildcard expressions may be ancillary but prove no path exists.
# Root comes from the argument (docs-sync-check passes it) or self-anchors to scripts/.., never stdin.
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$context = Join-Path $Root 'FRAMEWORK-CONTEXT.md'; $fails=0
function Fail($m){$script:fails++;Write-Output "FAIL: $m"}
function Test-IsoDate($value){if($value-cnotmatch'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'){return $false};try{$null=[datetime]::ParseExact($value,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);return $true}catch{return $false}}
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
 $statusDate=$null
 if(-not(@('[VERIFIED]','[SUSPECTED]','[UNVERIFIED]')-ccontains$status)){
  $statusMatch=[regex]::Match($status,'^\[REVIEWED: not a hazard — ([0-9]{4}-[0-9]{2}-[0-9]{2})\]$')
  if(-not$statusMatch.Success){Fail "hazard row has an unrecognised Status '$status' (expected [VERIFIED], [SUSPECTED], [UNVERIFIED], or [REVIEWED: not a hazard — YYYY-MM-DD]): $area"}
  elseif(-not(Test-IsoDate $statusMatch.Groups[1].Value)){Fail "hazard row has an invalid reviewed Status date '$($statusMatch.Groups[1].Value)' (expected a calendar-valid YYYY-MM-DD): $area"}
  else{$statusDate=$statusMatch.Groups[1].Value}
 }
 $dateOK=Test-IsoDate $reviewed
 if(-not$dateOK){Fail "hazard row has an invalid Reviewed date '$reviewed' (expected YYYY-MM-DD): $area"}
 if($null-ne$statusDate-and$dateOK-and$statusDate-cne$reviewed){Fail "hazard row reviewed Status date '$statusDate' does not match Reviewed column '$reviewed': $area"}
 $candidates=@();$without=$area
 foreach($m in [regex]::Matches($area,'`([^`]*)`')){$candidates+=$m.Groups[1].Value}
 $without=[regex]::Replace($without,'`[^`]*`',' ');$candidates+=@($without-split'[\s,]+'|Where-Object{$_})
 $literalCandidates=0;$invalidPath=$false
 foreach($rawCandidate in $candidates){
  $candidate=$rawCandidate.Trim('(',')','"',"'").TrimEnd(',','.',';',':')
  if($candidate-match'^[A-Za-z][A-Za-z0-9+.-]*://'-or$candidate.StartsWith('www.')){continue}
  if(-not$candidate-or$candidate-match'[?*]'){continue};$candidate=$candidate-replace'\\','/';$candidate=$candidate-replace'^\./',''
  if(-not($candidate-match'/'-or$candidate-match'\.[A-Za-z0-9]{1,10}$')){continue}
  if($candidate-match'^/'-or$candidate-match'^[A-Za-z]:/'-or$candidate.Contains('//')-or("/$candidate/"-match'/\.\.?/')){Fail "hazard row names a path that is not a safe repository-root-relative path: $candidate (row: $area)";$invalidPath=$true;continue}
  $literalCandidates++
  if(-not(Test-Path -LiteralPath (Join-Path $Root $candidate))){Fail "hazard row names a path that does not exist: $candidate (row: $area)"}
 }
 if($literalCandidates-eq0-and-not$invalidPath){Fail "hazard row must include at least one exact resolving repository-root-relative path: $area"}
}
if($fails){Write-Output "$fails hazard-check failure(s).";exit 1};Write-Output 'hazard-check passed.';exit 0
