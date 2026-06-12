# Generate docs/architecture.html from docs/ARCHITECTURE.md (PowerShell twin of build-architecture-html.sh).
# Embeds the markdown verbatim and renders it client-side with marked + mermaid (CDN) so the HTML
# cannot silently drift. Re-run after editing ARCHITECTURE.md. The HTML is for human reviewers only.
$ErrorActionPreference = 'Stop'

$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { $root = (Get-Location).Path }
Set-Location $root

$src   = if ($args.Count -ge 1) { $args[0] } else { 'docs/ARCHITECTURE.md' }
$out   = if ($args.Count -ge 2) { $args[1] } else { 'docs/architecture.html' }
$title = if ($args.Count -ge 3) { $args[2] } else { 'AI Tech Lead Framework — Architecture' }
if (-not (Test-Path $src)) { Write-Output "No $src -- nothing to build."; exit 1 }

$md = Get-Content $src -Raw -Encoding UTF8
# sha1 of CR-stripped content (eol-insensitive, matches the bash twin).
$norm  = ($md -replace "`r", "")
$bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
$sha   = -join ([System.Security.Cryptography.SHA1]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })

$head = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<!-- GENERATED from docs/ARCHITECTURE.md by scripts/build-architecture-html.ps1 — do not edit by hand. -->
<!-- src-sha1: $sha -->
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6;
         max-width: 60rem; margin: 0 auto; padding: 2rem 1.25rem; color: #1b1f24; background: #fff; }
  h1,h2,h3 { line-height: 1.25; }
  h1 { border-bottom: 2px solid #eaecef; padding-bottom: .3em; }
  h2 { border-bottom: 1px solid #eaecef; padding-bottom: .3em; margin-top: 2.2rem; }
  code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; background: #f3f4f6; padding: .15em .35em; border-radius: 4px; font-size: .9em; }
  pre { background: #f6f8fa; padding: 1rem; border-radius: 8px; overflow: auto; }
  pre code { background: none; padding: 0; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; font-size: .95em; }
  th,td { border: 1px solid #d0d7de; padding: .5rem .7rem; text-align: left; vertical-align: top; }
  th { background: #f6f8fa; }
  blockquote { color: #57606a; border-left: .25rem solid #d0d7de; margin: 1rem 0; padding: 0 1rem; }
  .mermaid { background: #fff; text-align: center; margin: 1.25rem 0; }
  a { color: #0969da; }
  @media (prefers-color-scheme: dark) {
    body { color: #c9d1d9; background: #0d1117; }
    code, pre, th { background: #161b22; } th,td { border-color: #30363d; }
    .mermaid { background: #0d1117; } a { color: #58a6ff; } h1,h2 { border-color: #21262d; }
  }
</style>
</head>
<body>
<main id="content">Rendering… (this page needs internet to render diagrams; the canonical source is docs/ARCHITECTURE.md)</main>
<script id="md" type="text/markdown">
"@

$tail = @'
</script>
<script src="https://cdn.jsdelivr.net/npm/marked@12/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
  var md = document.getElementById('md').textContent;
  document.getElementById('content').innerHTML = marked.parse(md, { gfm: true });
  document.querySelectorAll('pre > code.language-mermaid').forEach(function (c) {
    var div = document.createElement('div');
    div.className = 'mermaid';
    div.textContent = c.textContent;
    c.closest('pre').replaceWith(div);
  });
  var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  mermaid.initialize({ startOnLoad: false, theme: dark ? 'dark' : 'neutral' });
  mermaid.run();
</script>
</body>
</html>
'@

Set-Content -Path $out -Value ($head + $md + $tail) -Encoding UTF8
Write-Output "Generated $out from $src (src-sha1: $sha)"
