param([string]$Root)
$ErrorActionPreference = 'Stop'
# Read-only validation of Known Hazard Areas. Only literal repository-root-relative paths satisfy
# row evidence; URLs, symbols, and wildcard expressions may be ancillary but prove no path exists.
# Root comes from the argument (docs-sync-check passes it) or self-anchors to scripts/.., never stdin.
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$context = Join-Path $Root 'FRAMEWORK-CONTEXT.md'; $fails=0
function Fail($m){$script:fails++;Write-Output "FAIL: $m"}
function Test-IsoDate($value){if($value-cnotmatch'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'){return $false};try{$null=[datetime]::ParseExact($value,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);return $true}catch{return $false}}
if(-not(Test-Path -LiteralPath $context)){Fail 'FRAMEWORK-CONTEXT.md is missing; Known Hazard Areas cannot be validated.';Write-Output "$fails hazard-check failure(s).";exit 1}
$raw=[IO.File]::ReadAllText($context).TrimStart([char]0xFEFF)-replace"`r",''
if($raw.Contains('KNOWN_HAZARD_AREAS_PENDING')){Fail 'Known Hazard Areas are still pending; complete /bootstrap and remove KNOWN_HAZARD_AREAS_PENDING.';Write-Output "$fails hazard-check failure(s).";exit 1}
$lines=@($raw-split"`n");$headingCount=0
foreach($candidateLine in $lines){if(($candidateLine-replace'[ \t]+$','')-ceq'## Known Hazard Areas'){$headingCount++}}
if($headingCount-ne1){Fail "FRAMEWORK-CONTEXT.md must contain exactly one '## Known Hazard Areas' section (found $headingCount).";Write-Output "$fails hazard-check failure(s).";exit 1}
$inHazards=$false;$attemptedRows=0;$realRows=0;$noNotableRows=0
foreach($line in $lines){
 if(($line-replace'[ \t]+$','')-ceq'## Known Hazard Areas'){$inHazards=$true;continue}
 if($inHazards-and$line-match'^## '){break}
 if(-not$inHazards){continue}
 if(($line-replace'^[ \t]+|[ \t]+$','')-ceq'_No notable hazards detected — confirm with the team._'){$noNotableRows++;continue}
 if($line-notmatch'^\|'){continue}
 $cells=@($line.Split('|')|ForEach-Object{$_.Trim()});$nonempty=@($cells|Where-Object{$_-ne''})
 $area=$(if($cells.Count-gt1){$cells[1]}else{''})
 if($area-eq'Area / file(s)'){continue}
 if($nonempty.Count-gt0-and@($nonempty|Where-Object{$_-notmatch'^[-:]+$'}).Count-eq0){continue}
 $exactPlaceholder=$cells.Count-eq6-and$cells[0]-ceq''-and$cells[1]-ceq'_(drafted by /bootstrap)_' -and$cells[2]-ceq'_' -and$cells[3]-ceq'_' -and$cells[4]-ceq'_' -and$cells[5]-ceq''
 if($exactPlaceholder){$attemptedRows++;Fail 'Known Hazard Areas still contains the /bootstrap placeholder row.';continue}
 $attemptedRows++;$realRows++
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
  $safetyCandidate=$rawCandidate.Trim('(',')','"',"'").TrimEnd(',',';');$candidate=$safetyCandidate
  if($candidate.Length-gt0-and($candidate.EndsWith('.')-or$candidate.EndsWith(':'))){$candidate=$candidate.Substring(0,$candidate.Length-1)}
  if($candidate-match'^[A-Za-z][A-Za-z0-9+.-]*://'-or$candidate.StartsWith('www.')){continue}
  $openBracket=$candidate.IndexOf('[');$balancedBracket=$openBracket-ge0-and$candidate.IndexOf(']',$openBracket+1)-ge0
  if(-not$candidate-or$candidate-match'[?*]'-or$balancedBracket){continue}
  $safetyCandidate=$safetyCandidate-replace'\\','/';$candidate=$candidate-replace'\\','/'
  $unsafe=$false
  foreach($form in @($safetyCandidate,$candidate)){if($form-match'^/'-or$form-match'^[A-Za-z]:'-or$form.Contains('//')-or("/$form/"-match'/\.\.?/')){$unsafe=$true;break}}
  if($unsafe){Fail "hazard row names a path that is not a safe repository-root-relative path: $safetyCandidate (row: $area)";$invalidPath=$true;continue}
  if(-not($candidate-match'/'-or$candidate-match'\.[A-Za-z0-9]{1,10}$')){continue}
  $literalCandidates++
  if(-not(Test-Path -LiteralPath (Join-Path $Root $candidate))){Fail "hazard row names a path that does not exist: $candidate (row: $area)"}
 }
 if($literalCandidates-eq0-and-not$invalidPath){Fail "hazard row must include at least one exact resolving repository-root-relative path: $area"}
}
if($realRows-gt0-and$noNotableRows-gt0){Fail 'Known Hazard Areas cannot contain both hazard rows and the exact no-notable outcome.'}
elseif($attemptedRows-eq0-and$noNotableRows-eq0){Fail 'Known Hazard Areas must contain at least one hazard row or the exact no-notable outcome.'}
if($fails){Write-Output "$fails hazard-check failure(s).";exit 1};Write-Output 'hazard-check passed.';exit 0
