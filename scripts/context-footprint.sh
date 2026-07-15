#!/usr/bin/env bash
# ai-tech-lead context-footprint gate (independent bash twin).
# Usage: context-footprint.sh [-Check|-Update]; exits 0 pass/update, 1 mismatch, 2 FATAL/usage.
set -uo pipefail
cd "$(dirname "$0")/.."
mode="-Check"
[ "$#" -le 1 ] || { echo "usage: context-footprint.sh [-Check|-Update]" >&2; exit 2; }
case "${1:--Check}" in -Check|--check) mode="-Check";; -Update|--update) mode="-Update";; *) echo "usage: context-footprint.sh [-Check|-Update]" >&2;exit 2;; esac
baseline="meta/context-footprint.json"
if [ "$mode" = "-Check" ] && [ ! -f "$baseline" ];then echo "FAIL: context-footprint baseline missing: $baseline. Run with -Update and review the generated diff." >&2;exit 1;fi
command -v bash >/dev/null 2>&1||{ echo "FATAL: bash is required to render hook twins." >&2;exit 2; }
command -v pwsh >/dev/null 2>&1||{ echo "FATAL: pwsh is required to render hook twins." >&2;exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/context-footprint.XXXXXX")||exit 2;trap 'rm -rf "$tmp"' EXIT;tab=$(printf '\t')

# D1: normalize CRLF before wc -c; round chars/4 ties to even.
normalize_file(){ LC_ALL=C sed 's/\r$//' "$1"; }
byte_count(){ normalize_file "$1"|LC_ALL=C wc -c|tr -d ' '; }
token_count(){ local n=$1;local q=$((n/4));local r=$((n%4));if [ "$r" -gt 2 ]||{ [ "$r" -eq 2 ]&&[ $((q%2)) -eq 1 ];};then q=$((q+1));fi;printf %d "$q"; }
add_item(){ printf '%s\t%d\t%d\n' "$2" "$3" "$(token_count "$3")">>"$1"; }

# D2: hard-failing frontmatter split and byte-safe hook capture.
split_frontmatter(){
 local source=$1 first normalized last_hex close_line total_bytes
 first=$(LC_ALL=C sed -n '1{s/\r$//;p;}' "$source")
 [ "$first" = "---" ]||{ echo "FATAL: manifest file has no opening frontmatter delimiter: $source" >&2;return 2; }
 normalized="$tmp/frontmatter.normalized"
 normalize_file "$source">"$normalized"
 last_hex=$(tail -c 1 "$normalized"|od -An -tx1|tr -d ' \n')
 [ "$last_hex" = "0a" ]||{ echo "FATAL: manifest file does not end with a trailing newline: $source" >&2;return 2; }
 close_line=$(LC_ALL=C awk 'NR>1&&$0=="---"{print NR;exit}' "$normalized")
 [ -n "$close_line" ]||{ echo "FATAL: manifest file has no closing frontmatter delimiter: $source" >&2;return 2; }
 front_bytes=$(head -n "$close_line" "$normalized"|LC_ALL=C wc -c|tr -d ' ')
 total_bytes=$(LC_ALL=C wc -c<"$normalized"|tr -d ' ')
 body_bytes=$((total_bytes-front_bytes))
}
render_fixture(){
 local dist=$1 hook=$2 fixture=$3 event=$4 work="$tmp/$1-$2-${3//\//-}"
 mkdir -p "$work"
 if [ "$hook" = session-start ];then
  printf '# Fixture\nBOOTSTRAP_PENDING\n'>"$work/CLAUDE.md"
  printf '| ID | Severity | Status | Found | Due |\n| CF-1 | High | Open | 2000-01-01 | 2000-01-02 |\n'>"$work/SECURITY_FINDINGS.md"
 fi
 printf %s "$event">"$work/event.json"
 local sh_hook="$PWD/dist/$dist/.claude/hooks/$hook.sh" ps_hook="$PWD/dist/$dist/.claude/hooks/$hook.ps1"
 (cd "$work"&&LC_ALL=C bash "$sh_hook"<event.json>sh.out 2>&1)||{ echo "FATAL: bash hook failed: $dist/$hook/$fixture" >&2;return 2; }
 (cd "$work"&&pwsh -NoProfile -File "$ps_hook"<event.json>ps.out 2>&1)||{ echo "FATAL: PowerShell hook failed: $dist/$hook/$fixture" >&2;return 2; }
 normalize_file "$work/sh.out">"$work/sh.norm";normalize_file "$work/ps.out">"$work/ps.norm"
 cmp -s "$work/sh.norm" "$work/ps.norm"||{ echo "FAIL: hook twin-render mismatch: $dist/$hook/$fixture" >&2;return 1; }
 case "$(LC_ALL=C sed -n 1p "$work/sh.norm")" in \{*) echo "FATAL: fixture took JSON output branch: $dist/$hook/$fixture" >&2;return 2;;esac
 LC_ALL=C wc -c<"$work/sh.norm"|tr -d ' '
}

prompts="$tmp/prompts.tsv"
printf '%s\n' "intent/debt${tab}Review the technical debt in this area" "intent/design${tab}Design the best approach for this component" "intent/feature${tab}Implement a new component" "intent/fix${tab}Fix the broken component" "intent/refactor${tab}Refactor this component" "intent/review${tab}Review this code" "intent/test${tab}Write tests for this component" "security-only${tab}Explain password auth" "worst/fix-security${tab}Fix the broken password auth">"$prompts"
groups="static.claude static.copilot instructed session prompt ondemand-info";dists="dotnet angular monorepo"
for dist in $dists;do
 root="dist/$dist";[ -d "$root" ]||{ echo "FATAL: missing $root -- rebuild first." >&2;exit 2; }
 for group in $groups;do :>"$tmp/$dist.$group.tsv";done
 add_item "$tmp/$dist.static.claude.tsv" CLAUDE.md "$(byte_count "$root/CLAUDE.md")"
 for relative in AGENTS.md .github/copilot-instructions.md;do add_item "$tmp/$dist.static.copilot.tsv" "$relative" "$(byte_count "$root/$relative")";done
 for relative in FRAMEWORK-CONTEXT.md docs/defaults.md docs/wiki/INDEX.md;do [ ! -f "$root/$relative" ]||add_item "$tmp/$dist.instructed.tsv" "$relative" "$(byte_count "$root/$relative")";done
 {
  find "$root/.claude/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' -print
  find "$root/.claude/commands" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print
  find "$root/.claude/agents" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print
 }|LC_ALL=C sort>"$tmp/$dist.manifest"
 while IFS= read -r source;do
  relative=${source#"$root/"};split_frontmatter "$source"||exit $?
  add_item "$tmp/$dist.static.claude.tsv" "$relative#frontmatter" "$front_bytes"
  add_item "$tmp/$dist.ondemand-info.tsv" "$relative#body" "$body_bytes"
 done<"$tmp/$dist.manifest"
 chars=$(render_fixture "$dist" session-start bootstrap-overdue '{"hook_event_name":"SessionStart"}')||exit $?;add_item "$tmp/$dist.session.tsv" fixture/session-start "$chars"
 while IFS="$tab" read -r name prompt;do event='{"hook_event_name":"UserPromptSubmit","prompt":"'"$prompt"'"}';chars=$(render_fixture "$dist" route-prompt "$name" "$event")||exit $?;add_item "$tmp/$dist.prompt.tsv" "fixture/route-prompt/$name" "$chars";done<"$prompts"
 for group in $groups;do LC_ALL=C sort -t "$tab" -k1,1 "$tmp/$dist.$group.tsv" -o "$tmp/$dist.$group.tsv";done
 eval "${dist}_claude_total=$(LC_ALL=C awk -F '\t' '{s+=$2}END{print s+0}' "$tmp/$dist.static.claude.tsv")"
 eval "${dist}_copilot_total=$(LC_ALL=C awk -F '\t' '{s+=$2}END{print s+0}' "$tmp/$dist.static.copilot.tsv")"
 eval "${dist}_prompt_max=$(LC_ALL=C awk -F '\t' 'BEGIN{m=0}$2>m{m=$2}END{print m}' "$tmp/$dist.prompt.tsv")"
 eval "${dist}_claude_file=$(LC_ALL=C awk -F '\t' '$1=="CLAUDE.md"{print $2}' "$tmp/$dist.static.claude.tsv")"
done
largest_single=$dotnet_claude_file;[ "$angular_claude_file" -le "$largest_single" ]||largest_single=$angular_claude_file
ratio_numerator=$((1000*monorepo_claude_file))
ratio_permille=$((ratio_numerator/largest_single))
ratio_remainder=$((ratio_numerator%largest_single))
if [ $((2*ratio_remainder)) -gt "$largest_single" ] || { [ $((2*ratio_remainder)) -eq "$largest_single" ] && [ $((ratio_permille%2)) -eq 1 ]; };then
 ratio_permille=$((ratio_permille+1))
fi

# D3: independent fixed-order, two-space, integer-only canonical JSON emitter.
json_string(){ local v;v=$(printf %s "$1"|LC_ALL=C sed 's/\\/\\\\/g;s/"/\\"/g');printf '"%s"' "$v"; }
emit_items(){ local file=$1 indent=$2 first=1 path chars tok;[ -s "$file" ]||{ printf '[]';return; };printf '[\n';while IFS="$tab" read -r path chars tok;do [ "$first" -eq 1 ]||printf ',\n';first=0;printf '%s{\n%s  "path": %s,\n%s  "chars": %d,\n%s  "tok": %d\n%s}' "$indent" "$indent" "$(json_string "$path")" "$indent" "$chars" "$indent" "$tok" "$indent";done<"$file";printf '\n%s]' "${indent%  }"; }
emit_dist(){ local dist=$1 group first=1;printf '{\n';for group in $groups;do [ "$first" -eq 1 ]||printf ',\n';first=0;printf '      "%s": ' "$group";emit_items "$tmp/$dist.$group.tsv" '        ';done;printf '\n    }'; }
emit_derived(){ local dist=$1 claude copilot prompt;eval "claude=\$${dist}_claude_total;copilot=\$${dist}_copilot_total;prompt=\$${dist}_prompt_max";printf '{\n      "static.claude.chars": %d,\n      "static.claude.tok": %d,\n      "static.copilot.chars": %d,\n      "static.copilot.tok": %d,\n      "prompt.max.chars": %d,\n      "prompt.max.tok": %d\n    }' "$claude" "$(token_count "$claude")" "$copilot" "$(token_count "$copilot")" "$prompt" "$(token_count "$prompt")"; }
output="$tmp/context-footprint.json"
{
 printf '{\n  "schema-version": 1,\n  "generated-by": "scripts/context-footprint.ps1 + scripts/context-footprint.sh",\n  "counting-rule": "LF-normalized UTF-8 bytes; ~tok = round(chars/4)",\n  "ceilings": {\n    "static.claude.single-stack.chars": 40000,\n    "static.claude.monorepo.chars": 48000,\n    "monorepo-claude-ratio-permille": 1500\n  },\n  "dists": {\n'
 printf '    "dotnet": ';emit_dist dotnet;printf ',\n    "angular": ';emit_dist angular;printf ',\n    "monorepo": ';emit_dist monorepo
 printf '\n  },\n  "derived": {\n    "dotnet": ';emit_derived dotnet;printf ',\n    "angular": ';emit_derived angular;printf ',\n    "monorepo": ';emit_derived monorepo;printf ',\n    "monorepo-claude-ratio-permille": %d\n  },\n' "$ratio_permille"
 printf '  "_notes": [\n    "Claude frontmatter is a stable over-approximation of harness injection.",\n    "Copilot skill frontmatter and .agent.md wrapper consumption are unverified; B-17 instructions join static.copilot when added.",\n    "ondemand-info is reported but never policy-gated.",\n    "Token values are chars÷4 approximations."\n  ]\n}\n'
}>"$output"

# D4/D5: warnings do not change a matching-baseline exit.
[ "$dotnet_claude_total" -le 40000 ]||echo "WARN: dotnet static.claude exceeds 40000 chars."
[ "$angular_claude_total" -le 40000 ]||echo "WARN: angular static.claude exceeds 40000 chars."
[ "$monorepo_claude_total" -le 48000 ]||echo "WARN: monorepo static.claude exceeds 48000 chars."
[ "$ratio_permille" -le 1500 ]||echo "WARN: monorepo CLAUDE.md exceeds 1.5x the larger single-stack CLAUDE.md."
if [ "$mode" = "-Update" ];then cp "$output" "$baseline";echo "UPDATED: meta/context-footprint.json";exit 0;fi
cmp -s "$output" "$baseline"||{ echo "FAIL: context footprint differs from meta/context-footprint.json. Review the change, then run -Update.";exit 1; }
echo "OK: context footprint matches meta/context-footprint.json.";exit 0
