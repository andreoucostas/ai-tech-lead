#!/usr/bin/env bash
# PostToolUse hook (Write|Edit) — bash twin of bom-fix.ps1 (meta-invariant #3: .ps1/.sh twin parity).
# Meta-invariant #4: every .ps1 must carry a UTF-8 BOM so Windows PowerShell 5.1 parses it correctly.
# Auto-fixable, so we fix instead of warning: if a just-written .ps1 under a template repo lacks a
# BOM, prepend one in place, content unchanged. Scoped to ai-tech-lead/ paths so it never rewrites
# unrelated files. Soft-fails (exit 0) on any error — never blocks the write.
set -u

[ -t 0 ] && exit 0
input=$(cat)
[ -z "$input" ] && exit 0

fp=""
if command -v jq >/dev/null 2>&1; then
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  fp=$(printf '%s' "$input" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti=d.get("tool_input") or {}
sys.stdout.write(ti.get("file_path") or ti.get("filePath") or "")
' 2>/dev/null)
else
  exit 0   # no JSON parser — nothing to inspect; the .ps1 twin is the wired hook anyway
fi

[ -z "$fp" ] && exit 0
case "$fp" in *.ps1) ;; *) exit 0 ;; esac
case "$fp" in
  *ai-tech-lead[/\\]*) ;;
  *) exit 0 ;;
esac
[ -f "$fp" ] || exit 0

first3=$(head -c3 "$fp" | od -An -tx1 | tr -d ' \n')
[ "$first3" = "efbbbf" ] && exit 0   # already has a BOM

tmp="${fp}.bomfix.$$"
if { printf '\xEF\xBB\xBF'; cat "$fp"; } > "$tmp" 2>/dev/null; then
  mv "$tmp" "$fp" 2>/dev/null || rm -f "$tmp"
else
  rm -f "$tmp"
fi
exit 0
