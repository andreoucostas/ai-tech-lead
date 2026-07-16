param([string]$Root)
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (($input | Out-String).Trim()) }
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$wiki = Join-Path $Root 'docs/wiki'; $index = Join-Path $wiki 'INDEX.md'; $fails=0
function Fail($m){$script:fails++;Write-Output "FAIL: $m"}; function Warn($m){Write-Output "WARN: $m"}
$signal='(?i)(ignore|disregard|override|forget|instead of|regardless of|do not tell|system prompt|you are|you must|<!--[^>]*(do|run|execute|ignore|must)|[A-Za-z0-9+/]{80,}={0,2}|[\u200B-\u200F\u202A-\u202E\u2060-\u206F]|https?://\S*(exfil|webhook|collect|upload))'
if(-not(Test-Path -LiteralPath $index)){Fail 'docs/wiki/INDEX.md is missing';Write-Output "$fails wiki-check failure(s).";exit 1}
$idx=[IO.File]::ReadAllText($index).TrimStart([char]0xFEFF)-replace"`r",''
$lines=@($idx -split"`n"|Where-Object{$_ -match'^- \['});$slugs=@()
foreach($line in $lines){if($line -notmatch'^- \[(gotcha|context|recipe|failed-approach)\] \[([a-z0-9]+(?:-[a-z0-9]+)*)\]\(\./\2\.md\) — (.+)$'){Fail "invalid INDEX line: $line"}else{$slugs+=$Matches[2]};if($line-match$signal){Fail "injection marker in INDEX line: $line"}}
if(($slugs -join"`n") -ne (($slugs|Sort-Object) -join"`n")){Fail 'INDEX entries are not sorted by slug'}
$files=@(Get-ChildItem -LiteralPath $wiki -Filter '*.md' -File|Where-Object{$_.Name-notin@('INDEX.md','_template.md')})
if($files.Count-gt100){Warn "$($files.Count) entries exceeds 100"}
foreach($s in $slugs){if(-not(Test-Path -LiteralPath (Join-Path $wiki "$s.md"))){Fail "INDEX entry has no file: $s"}}
foreach($f in $files){$stem=$f.BaseName;if($stem-notin$slugs){Fail "entry file has no INDEX line: $stem"};$raw=[IO.File]::ReadAllText($f.FullName).TrimStart([char]0xFEFF)-replace"`r",'';$a=$raw-split"`n";if($a.Count-gt80){Warn "$($f.Name) exceeds 80 lines"};if($a.Count-lt3-or$a[0]-ne'---'){Fail "$($f.Name): malformed frontmatter";continue};$end=[Array]::IndexOf($a,'---',1);if($end-lt1){Fail "$($f.Name): malformed frontmatter";continue};$vals=@{};foreach($k in @('name','description','type','scope','status','last-verified')){$hit=@($a[1..($end-1)]|Where-Object{$_-match("^"+[regex]::Escape($k)+": (.*)$")});if($hit.Count-ne1){Fail "$($f.Name): missing or duplicate $k"}else{$null=$hit[0]-match("^"+[regex]::Escape($k)+": (.*)$");$vals[$k]=$Matches[1]}}
if($vals.name-ne$stem){Fail "$($f.Name): name must equal filename stem"};if($vals.type-notin@('gotcha','context','recipe','failed-approach')){Fail "$($f.Name): invalid type"};if($vals.status-notin@('verified','suspected','unverified')){Fail "$($f.Name): invalid status"};if($vals.'last-verified'-notmatch'^\d{4}-\d{2}-\d{2}$'){Fail "$($f.Name): invalid last-verified"}else{try{$d=[datetime]::ParseExact($vals.'last-verified','yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);if($d-lt[datetime]::Today.AddDays(-90)){Warn "$($f.Name) last verified $($vals.'last-verified')"}}catch{Fail "$($f.Name): invalid last-verified"}}
if($vals.description-match$signal){Fail "$($f.Name): injection marker in description"};$body=($a[($end+1)..($a.Count-1)]-join"`n");if($body-match$signal){Warn "$($f.Name): injection marker in body"}
}
if($fails){Write-Output "$fails wiki-check failure(s).";exit 1};Write-Output 'wiki-check passed.';exit 0
