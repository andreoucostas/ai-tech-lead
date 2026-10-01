---
name: perf
description: >
  Scan a .NET C# codebase (or a specific file/path) for performance anti-patterns and
  produce a prioritised, actionable findings report.
  USE FOR: pre-release performance audits, reviewing a hot path before optimising it,
  systematic anti-pattern detection across a module or whole repo, secondary validation
  after manual profiling, or when TECH_DEBT.md has open Performance items to investigate.
  DO NOT USE FOR: runtime profiling (use dotnet-trace or PerfView instead), fixing a single
  known performance issue you've already located, benchmarking, or
  auditing code that has already been through a dedicated perf review this sprint.
---

# Performance Anti-Pattern Scan

Scans C# source for ~50 known anti-patterns across async, memory, strings, collections,
LINQ, regex, serialization, and I/O. Produces tiered severity findings with file locations
and one-line fixes.

---

## Step 1 — Scope and signals

Identify the scan target (whole repo, a project, a directory, or specific files).

Grep for code signals to determine which categories apply:

```
async/await presence       → enables Async category
Span<T> / Memory<T>        → enables Memory category
Regex / new Regex          → enables Regex category
IEnumerable / LINQ (.Where/.Select/.ToList) → enables LINQ category
HttpClient / Stream        → enables I/O category
JsonSerializer / XmlSerializer → enables Serialization category
string + / string.Format   → enables Strings category
new List / new Dictionary  → enables Collections category
```

Default scan depth: **standard** (all matched categories).
If the user says "quick" or "critical only" — skip Info findings.
If the user says "thorough" or "comprehensive" — add cross-file consistency checks.

---

## Step 2 — Detection recipes

Run these grep patterns against the scan target. Record hit counts and file locations.

### Async

| Pattern | Grep | Severity |
|---------|------|----------|
| `.Result` / `.Wait()` on Task (deadlock risk) | `\.Result\b\|\.Wait()` | 🔴 Critical |
| `async void` (fire-and-forget, swallows exceptions) | `async void ` | 🔴 Critical |
| `Task.Run` inside ASP.NET request (wasted thread-pool) | `Task\.Run\(` | 🟡 Moderate |
| Missing `ConfigureAwait(false)` in library code | `await [^C]` (in non-ASP files) | ℹ️ Info |
| Unnecessary `await` in pass-through (return task directly) | `return await ` | ℹ️ Info |
| `CancellationToken` not propagated to async calls | grep async methods without `ct` / `cancellationToken` param | 🟡 Moderate |

### Memory / Allocations

| Pattern | Grep | Severity |
|---------|------|----------|
| `new byte[]` inside loop | inside loop body | 🔴 Critical |
| Boxing: casting value type to `object` / `IComparable` | `\(object\)\|\bas IComparable\b` | 🟡 Moderate |
| `string.Concat` / `+` in loop (O(n²) allocations) | `+= ` near loop | 🟡 Moderate |
| Span/Memory use in async context (not allowed) | `Span<` in async method | 🔴 Critical |
| Large arrays rented but not returned (`ArrayPool`) | `new.*\[\d{4,}\]` | 🟡 Moderate |
| `sealed` class ratio (unsealed = virtual dispatch overhead) | count `class ` vs `sealed class` | ℹ️ Info |

### Strings

| Pattern | Grep | Severity |
|---------|------|----------|
| `string.Format` (prefer interpolation or `Span`-based) | `string\.Format\(` | ℹ️ Info |
| Multiple `.Replace()` chained (compound allocation) | `\.Replace(.*\.Replace(` | 🟡 Moderate |
| `ToUpper()` / `ToLower()` for comparison (use `OrdinalIgnoreCase`) | `\.ToUpper()\|\.ToLower()` | 🟡 Moderate |
| `Contains` without `StringComparison` | `\.Contains("[^"]` | ℹ️ Info |
| Repeated `string.Split` on hot path | `\.Split(` | ℹ️ Info |

### Collections / LINQ

| Pattern | Grep | Severity |
|---------|------|----------|
| `.ToList()` immediately before `foreach` (double allocation) | `\.ToList().*foreach\|foreach.*\.ToList()` | 🟡 Moderate |
| `.Count()` on `IEnumerable` (full enumeration) | `\.Count()` (not `.Count` property) | 🟡 Moderate |
| `First()` / `Single()` without `OrDefault` (throws on miss) | `\.First()\|\.Single()` | 🟡 Moderate |
| LINQ inside tight loop (re-evaluated each iteration) | LINQ call inside `for`/`while`/`foreach` body | 🔴 Critical |
| `new List<T>()` without capacity hint in loop | `new List<` without `(capacity` | ℹ️ Info |
| Dictionary lookup twice (TryGetValue + reassign) | `ContainsKey.*\[` | ℹ️ Info |

### Regex

| Pattern | Grep | Severity |
|---------|------|----------|
| `new Regex(...)` on hot path without `Compiled` | `new Regex\(` | 🟡 Moderate |
| `new Regex(...)` with compile-time literal (use `[GeneratedRegex]`) | `new Regex\("` | 🟡 Moderate |
| `Regex.IsMatch` / `Regex.Replace` static (re-compiled each call) | `Regex\.IsMatch\|Regex\.Replace\|Regex\.Match` | 🟡 Moderate |

### I/O

| Pattern | Grep | Severity |
|---------|------|----------|
| Synchronous I/O in async method (`File.Read`, `StreamReader.ReadToEnd`) | `File\.Read\b\|ReadToEnd()` | 🔴 Critical |
| `HttpClient` constructed per-request (socket exhaustion) | `new HttpClient(` | 🔴 Critical |
| `Stream.Read` in a loop without buffer pooling | `\.Read(` in loop | 🟡 Moderate |

### Serialization

| Pattern | Grep | Severity |
|---------|------|----------|
| `JsonSerializer` without cached `JsonSerializerOptions` | `new JsonSerializerOptions` | 🟡 Moderate |
| `XmlSerializer` constructed per-call (reflection + compile cost) | `new XmlSerializer\(` | 🔴 Critical |

---

## Step 3 — Classify and scale

After collecting counts:

- Any single pattern with **50+ instances** → escalate one severity level and flag as **systematic**.
- If user identifies code as a **hot path or latency-sensitive** → escalate all 🟡 findings in that scope to 🔴.
- **Verify the inverse** for sealed classes: report `X sealed / Y total` so systematic unsealing is visible.
- **Do not flag** `[GeneratedRegex]` patterns — they're already optimal.
- **Do not flag** LINQ on cold paths (startup, one-time config loading).

---

## Step 4 — Output format

Group by severity. For each finding:

```
🔴 PERF-01: async void handlers (3 instances)
Impact: swallows exceptions silently, cannot be awaited
Files: OrderService.cs:42, PaymentHandler.cs:17, NotificationWorker.cs:88
Fix: change to async Task; wire exceptions to caller or ILogger
```

End with a summary table:

| Severity | Count | Systematic? |
|----------|-------|-------------|
| 🔴 Critical | N | list any |
| 🟡 Moderate | N | list any |
| ℹ️ Info | N | — |

Close with: _"Results are non-deterministic grep-based heuristics. Confirm Critical findings by reading the affected code before fixing. Benchmark before and after any Critical change on hot paths."_

---

## Step 5 — TECH_DEBT.md integration

For each 🔴 Critical and any 🟡 Moderate flagged as systematic, offer to append a row to TECH_DEBT.md:

```
| PERFxx | Performance | Critical | <files> | <issue> | <fix> | M |
```

Only append — never overwrite existing rows.
