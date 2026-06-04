#!/usr/bin/env bash
# Generate docs/architecture.html from docs/ARCHITECTURE.md (the canonical source).
# The HTML embeds the markdown verbatim and renders it client-side with marked + mermaid (CDN),
# so the diagrams display and the HTML cannot silently drift from the source. Re-run after editing
# ARCHITECTURE.md; docs-sync-check flags staleness via the embedded src-sha1 marker.
# The HTML is for human reviewers only — AI agents read the markdown directly.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

src="docs/ARCHITECTURE.md"
out="docs/architecture.html"
[ -f "$src" ] || { echo "No $src — nothing to build."; exit 1; }

# sha1 of CR-stripped content (eol-insensitive, so the drift check survives autocrlf).
if command -v sha1sum >/dev/null 2>&1; then sha=$(tr -d '\r' < "$src" | sha1sum | awk '{print $1}')
elif command -v shasum  >/dev/null 2>&1; then sha=$(tr -d '\r' < "$src" | shasum  | awk '{print $1}')
else sha="nohash"; fi

{
  cat <<HTMLHEAD
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AI Tech Lead Framework — Architecture</title>
<!-- GENERATED from docs/ARCHITECTURE.md by scripts/build-architecture-html.sh — do not edit by hand. -->
<!-- src-sha1: ${sha} -->
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
HTMLHEAD
  cat "$src"
  cat <<'HTMLTAIL'
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
HTMLTAIL
} > "$out"

echo "Generated $out from $src (src-sha1: $sha)"
