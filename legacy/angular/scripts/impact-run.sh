#!/usr/bin/env bash
# Behavioral A/B runner for the impact harness.
#
# Runs each task in tests/impact/tasks.json through a headless coding agent (Copilot CLI) twice —
# arm "pre" = OLD framework (a pre-adoption commit) and arm "post" = THIS framework (current) —
# N trials each, in throwaway git worktrees, capturing structured metadata per run to
# docs/impact/runs/<arm>/<task>/<trial>.json. Model / tool / task / base commit are held constant;
# the ONLY difference between arms is the framework config present in each. No human input required.
#
# Usage: bash scripts/impact-run.sh <pre_ref> <post_ref> [--smoke]
#   <pre_ref>   commit/tag with the OLD framework (the pre-adoption tag /adopt creates)
#   <post_ref>  commit with THIS framework (e.g. HEAD/master after adoption)
#   --smoke     use config.smoke_trials (quick inline run) instead of config.trials
#
# Prereq: the headless agent (e.g. `copilot`) is installed and authenticated once. Stochastic by
# nature — that's why it runs multiple trials; read results as distributions, not single runs.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$ROOT"
pre="${1:-}"; post="${2:-}"; mode="${3:-}"
[ -n "$pre" ] && [ -n "$post" ] || { echo "Usage: bash scripts/impact-run.sh <pre_ref> <post_ref> [--smoke]"; exit 2; }

cfg="tests/impact/config.json"; tasks="tests/impact/tasks.json"
[ -f "$cfg" ] && [ -f "$tasks" ] || { echo "Missing tests/impact/config.json or tasks.json."; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required."; exit 2; }

agent_cmd=$(jq -r '.agent_cmd' "$cfg")
if [ "$mode" = "--smoke" ]; then trials=$(jq -r '.smoke_trials // 1' "$cfg"); else trials=$(jq -r '.trials // 3' "$cfg"); fi
agent_bin=$(printf '%s' "$agent_cmd" | awk '{print $1}')
if ! command -v "$agent_bin" >/dev/null 2>&1; then
  echo "Headless agent '$agent_bin' not on PATH — cannot run the behavioral A/B (Tier 2)."
  echo "Install/auth it (Copilot CLI) or run only the deterministic before/after (Tier 1)."
  exit 3
fi

# Infer a build command for this repo (used for tasks with \"build\": true).
build_cmd=""
if ls "$ROOT"/*.sln >/dev/null 2>&1 || find "$ROOT" -maxdepth 3 -name '*.csproj' -not -path '*/bin/*' 2>/dev/null | grep -q .; then
  command -v dotnet >/dev/null 2>&1 && build_cmd="dotnet build --nologo --verbosity quiet"
elif [ -f "$ROOT/angular.json" ]; then
  command -v npx >/dev/null 2>&1 && build_cmd="npx --no-install tsc --noEmit"
fi

run_dir="docs/impact/runs"; rm -rf "$run_dir"; mkdir -p "$run_dir"

for arm in pre post; do
  if [ "$arm" = pre ]; then ref="$pre"; else ref="$post"; fi
  ntasks=$(jq 'length' "$tasks"); i=0
  while [ "$i" -lt "$ntasks" ]; do
    tid=$(jq -r ".[$i].id" "$tasks")
    prompt=$(jq -r ".[$i].prompt" "$tasks")
    need_build=$(jq -r ".[$i].build // false" "$tasks")
    mkdir -p "$run_dir/$arm/$tid"
    t=1
    while [ "$t" -le "$trials" ]; do
      wt=$(mktemp -d 2>/dev/null || echo "/tmp/impact.$$.$RANDOM"); mkdir -p "$wt"
      if ! git worktree add -q --detach "$wt" "$ref" 2>/dev/null; then
        echo "  worktree add failed for ref '$ref' — skipping"; rm -rf "$wt"; t=$((t+1)); continue
      fi

      start=$(date +%s 2>/dev/null || echo 0)
      cmd="${agent_cmd/\{prompt\}/$(printf '%q' "$prompt")}"
      if command -v timeout >/dev/null 2>&1; then
        ( cd "$wt" && timeout 900 bash -c "$cmd" ) >/dev/null 2>&1 || true
      else
        ( cd "$wt" && bash -c "$cmd" ) >/dev/null 2>&1 || true
      fi
      end=$(date +%s 2>/dev/null || echo 0); dur=$(( end - start )); [ "$dur" -lt 0 ] && dur=0

      git -C "$wt" add -A 2>/dev/null
      changed=(); while IFS= read -r f; do [ -n "$f" ] && changed+=("$f"); done < <(git -C "$wt" diff --cached --name-only 2>/dev/null)
      abschanged=(); for f in "${changed[@]}"; do abschanged+=("$wt/$f"); done
      added=$(git -C "$wt" diff --cached --numstat 2>/dev/null | awk '{a+=$1} END{print a+0}')
      deleted=$(git -C "$wt" diff --cached --numstat 2>/dev/null | awk '{d+=$2} END{print d+0}')

      build_ok="null"
      if [ "$need_build" = "true" ] && [ -n "$build_cmd" ]; then
        if ( cd "$wt" && $build_cmd ) >/dev/null 2>&1; then build_ok=true; else build_ok=false; fi
      fi

      assert_report="[]"; acc_ok=true
      eval_asserts() {  # $1 = jq key, $2 = present|absent
        local key="$1" expect="$2" n j rx hit pass
        n=$(jq -r ".[$i].$key | length // 0" "$tasks" 2>/dev/null); [ -z "$n" ] && n=0
        j=0
        while [ "$j" -lt "$n" ]; do
          rx=$(jq -r ".[$i].$key[$j]" "$tasks")
          hit=false
          if [ "${#abschanged[@]}" -gt 0 ] && grep -rEIl "$rx" "${abschanged[@]}" >/dev/null 2>&1; then hit=true; fi
          pass=true
          [ "$expect" = present ] && [ "$hit" = false ] && pass=false
          [ "$expect" = absent ]  && [ "$hit" = true  ] && pass=false
          [ "$pass" = false ] && acc_ok=false
          assert_report=$(printf '%s' "$assert_report" | jq --arg rx "$rx" --arg ex "$expect" --argjson pass "$pass" '. + [{regex:$rx, expect:$ex, pass:$pass}]')
          j=$((j+1))
        done
      }
      eval_asserts asserts_match present
      eval_asserts asserts_no_match absent
      [ "$need_build" = "true" ] && [ "$build_ok" = false ] && acc_ok=false

      metrics="{}"
      if [ "${#abschanged[@]}" -gt 0 ]; then
        m=$(bash "$ROOT/scripts/metrics.sh" "${abschanged[@]}" 2>/dev/null | jq -c '.metrics' 2>/dev/null)
        [ -n "$m" ] && metrics="$m"
      fi

      jq -n \
        --arg arm "$arm" --arg task "$tid" --argjson trial "$t" --arg ref "$ref" \
        --argjson build_ok "$build_ok" --argjson acceptance "$acc_ok" \
        --argjson asserts "$assert_report" --argjson metrics "$metrics" \
        --argjson files "${#changed[@]}" --argjson added "${added:-0}" --argjson deleted "${deleted:-0}" \
        --argjson duration "$dur" \
        '{arm:$arm, task:$task, trial:$trial, ref:$ref, build_ok:$build_ok, acceptance:$acceptance, asserts:$asserts, antipatterns_introduced:$metrics, files_changed:$files, lines_added:$added, lines_deleted:$deleted, duration_s:$duration}' \
        > "$run_dir/$arm/$tid/$t.json"

      git worktree remove --force "$wt" 2>/dev/null; rm -rf "$wt" 2>/dev/null
      echo "  $arm/$tid trial $t: acceptance=$acc_ok build=$build_ok files=${#changed[@]}"
      t=$((t+1))
    done
    i=$((i+1))
  done
done

echo "Done. Per-run metadata in $run_dir/. Aggregate into a report with /impact."
