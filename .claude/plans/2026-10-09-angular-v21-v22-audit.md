# Angular currency assessment: ai-tech-lead @ ad3bf972 (0.95.0 unreleased), 2026-10-09

> **Status 2026-10-09, after this audit was written.** The maintainer says the consumers are on Angular 21.2, so the scope
> is v21-v22 (see the addendum at the end): every v20 branch and the v20 LTS deadline drop out. The maintainer also
> approved reversing 6879e5e8's neutral standalone and `inject()` wording (B0, first question) and starting with
> batch 1. Batch 1 (§4 B1 and B2: K1, K2, the M2 sample parts, F10) is B-368, done for 0.95.0; K1 was reproduced with
> angular-eslint 21.4.0 and ESLint 9.39.5 (exit 2, "could not find plugin"), K2 was not run. The remaining batches are
> B-367. Every path:line below was read at `ad3bf972`; re-read before editing.


**Conventions.** OBSERVED means read at HEAD, or in the cited source. For sources I read the copies saved under `scratchpad/ng-audit/`: `ng-changelog.md`, `cli-changelog.md`, `agents-skills/releases-main.md`, `carrier/`, `src/`. INFERRED means a consequence reasoned from those sources and never executed. I re-read every repo `path:line` below at HEAD unless it is marked *(slice)*.

**Path keys.** `A/` = `src/stacks/angular/files/`, `M/` = `src/stacks/monorepo/files/`, `As/` = `src/stacks/angular/snippets/`, `Ms/` = `src/stacks/monorepo/snippets/`. Each `dist/<stack>/` copy matches its src file apart from CRLF, according to the slice parity checks.

**URL keys.**

| Key | Repository and commit |
|-----|-----------------------|
| NG | github.com/angular/angular/blob/4e4ad75144e55538cedc65f0ac3ff5b68cb34ce9/ (main) |
| A22 | github.com/angular/angular/blob/2da8b0b41da0b91cc57eacb329aabc194f01943d/ |
| A21 | github.com/angular/angular/blob/8ac0a2c79a04f4bbb05ea3b4f6dc13e42b3e1e22/ |
| A20 | github.com/angular/angular/blob/2e8bde1d858502efb458783a34be2a1c36f215fd/ |
| CLI | github.com/angular/angular-cli/blob/dcf906a6261a00f95cfbdb18cf9065e1c966e182/ (main) |
| C22 | github.com/angular/angular-cli/blob/1d477d6bc27159cb0c78288e047fcadfe6fc31d4/ |
| C21 | github.com/angular/angular-cli/blob/4bbeadde130693517590150a8dd21dbfcbbc5b71/ |
| C20 | github.com/angular/angular-cli/blob/4c9e20372ca0d40e4b83f3f98fe3eb565333873e/ |
| AE | github.com/angular-eslint/angular-eslint/blob/06bf0e5db930e1ec72f7d23d8fd7f59be1ffbac7/ |
| ESL | github.com/eslint/eslint/blob/b92decf8ead7cc4082a18a4a0ab28f3c7c589887/ |

All keys are `https://` URLs.

## 1. Which majors consumers are on, and what that implies

| Major | Role | Released | Support ends |
|-------|------|----------|--------------|
| v22 | latest | 2026-06-03 | active 2027-06, LTS 2028-06 |
| v21 | latest-1 | 2025-11-19 | LTS 2027-06 |
| v20 | latest-2 | 2025-05-28 | **LTS ends 2026-11-28, seven weeks from today** |

- Source for the table: NG `adev/src/content/reference/releases.md#L99-L105`. That page also says "Angular versions v2 to v19 are no longer supported".
- Release cadence from v22 on (releases.md):
  - one major every 12 months (#L60-L69);
  - 24 months of support: 12 active plus 12 LTS (#L88-L93);
  - deprecations last at least one major (#L116);
  - v23 is due about June 2027 (#L84).

What this implies:

1. **The guidance floor is v20.** No consumer is on v17–v19. Every "17+" or "16+" pivot in the tree therefore separates nothing (see §3).
2. **The floor should follow your consumer policy, not Angular's support table** (INFERRED). v20 leaves LTS on 2026-11-28 but stays latest-2 until v23 ships, about June 2027. Under the new cadence this becomes permanent: a major's 24 months of support end just as it becomes latest-2. Your latest-2 consumers will normally be on an unsupported major. The framework should keep advising them correctly, and `/bootstrap` should report the support status as a finding.
3. **The defaults that differ inside the window change at v21 and v22.**
   - v21:
     - Apps are zoneless unless they call `provideZoneChangeDetection` (NG `CHANGELOG.md#L2471`).
     - TestBed is zoneless (A21 `packages/core/testing/src/test_bed_compiler.ts#L937`). The CLI test builders add zone change detection back when zone.js loads in the test build (C22 `packages/angular/build/src/builders/karma/application_builder.ts#L214-L233`).
     - Vitest is the test runner for new projects (A22 `adev/src/content/guide/testing/overview.md#L5-L19`).
     - HttpClient is provided in root (NG `CHANGELOG.md#L2635`).
   - v22:
     - OnPush is the default change detection (#L1096).
     - The fetch backend is the default (#L1126-L1127).
     - Incremental hydration is on by default (#L1268).
     - `paramsInheritanceStrategy` defaults to `'always'` (#L1118-L1120).
     - `@Service` arrives (#L1179).
     - `strictTemplates` is on by default (A22 `packages/core/schematics/migrations.json#L13-L17`).
     - Webpack builders are deprecated, and the Jest and Web Test Runner builders are removed (CLI `CHANGELOG.md#L1049-L1079`).
     - TypeScript 6 makes `strict` the default.
4. **Upgrade residue is the main cross-cutting theme.** `ng update` moves one major at a time (releases.md#L150-L157), and the v22 migrations leave artefacts behind:
   - `Eager` on every existing component;
   - `strictTemplates: false`;
   - `withXhr`;
   - `withNoIncrementalHydration` (A22 `packages/core/schematics/migrations.json#L3-L27`).

   Today `/bootstrap` would record these as team conventions. `paramsInheritanceStrategy` flips with **no** migration: none of the eight v22 core migrations touches it (OBSERVED). v20 teams have to make the v21 move within seven weeks to stay supported, so `dependency-audit` is on the critical path right now.
5. **Reach.** Some files are consumer-owned/protected, so fixes to them reach new installs only:
   - `AGENTS.md`, which holds the Boy Scout section (`dist/angular/framework-ownership.json:63`);
   - `docs/ARCHITECTURE.md` (`:71`).

   These are framework-owned and reach every consumer on update: `docs/defaults.md` (`:76`), the rules carrier (`:61`), and the commands, agents, skills and hooks (for example `:23`, `:26`, `:40`, `:46`). README is not installed (`src/core/scripts/install.ps1:321-324`). Any version split that existing consumers need must therefore live in framework-owned files. The CHANGELOG entry must tell consumers to edit their own Boy Scout section.

## 2. Findings (deduplicated across the five slices)

### 2a. Breaks

**K1 — Merging the ESLint standards sample aborts `ng lint`** [AS-01]

- **Where:**
  - `A/scripts/ci/eslint-standards.sample.mjs:9-19`. It reaches `dist/monorepo` through the overlay at `scripts/build.ps1:38-39`.
  - The merge instructions: `enforce-standards/SKILL.md`, A:26-31 and M:57-62.
- **Today:**
  - The object has no `files` key, so the `@typescript-eslint/ban-ts-comment` rule it enables reaches every linted file, `*.html` included.
  - `ng add angular-eslint` (v20–v22) registers typescript-eslint only under `files: ["**/*.ts"]`. It lints `**/*.html` in a separate object (AE `packages/schematics/src/utils.ts#L335-L378`).
  - ESLint throws `Could not find plugin` when a rule is enabled for a file that has no plugin registered (ESL `lib/config/config.js#L87-L125`).
  - INFERRED, not executed: lint aborts on the first template, inline templates included (`processInlineTemplates`).
- **Fix:**
  - Keep `linterOptions` in an unscoped object, and move the rule into `{ files: ['**/*.ts'], rules: {…} }`.
  - Add one skill line: "Put a plugin rule only in an object whose `files` match where the repository registers that plugin."

**K2 — `dependency-audit` stalls a major upgrade on any NgRx repo** [AS-03]

- **Where:** `dependency-audit/SKILL.md`, A:70-78 and M:140-148.
- **Today:**
  - Step 4 updates only `@angular/core`, `@angular/cli` and first-party packages, and it forbids `--force`.
  - `ng update` rejects any installed package whose peer range excludes the target version: "Incompatible peer dependencies found" (C22 `packages/angular/cli/src/commands/update/update-resolver.ts#L253-L316`, read from the fetched copy).
  - `@ngrx/*` N declares a peer of `@angular/core ^N` (github.com/ngrx/platform/blob/ddd9772e81e2db8a8964fa65f355086118d29dd9/modules/store/package.json#L23-L26).
  - INFERRED: v20→v21 aborts, and the only bypass is forbidden, so the agent stalls. This is the move v20 teams are making now.
- **Fix:**
  - In the same `ng update`, name every installed library whose peer range excludes the next major, at the release that includes it (NgRx N for Angular N).
  - Naming one member of an `ng-update.packageGroup` updates the whole group.

**K3 — The post-write type-check passes silently on a v20+ solution-style tsconfig** [HSE-1, partial]

- **Where:**
  - A `.claude/hooks/post-write.ps1:134-149` and M `:218-233`.
  - The doctor canary text: `src/core/scripts/framework-doctor.ps1:558,560`.
- **Today:**
  - Since CLI 20.0 the root `tsconfig.json` is `"files": []` plus `references` (CLI `CHANGELOG.md#L3086-L3087`; C22 `packages/schematics/angular/workspace/files/tsconfig.json.template#L24`).
  - In a library-only workspace the hook runs `tsc -p tsconfig.json`. That compiles nothing and exits 0, which is the exact false pass the hook's own comment at :146-148 says it prevents.
  - OBSERVED: the hooks slice ran the HEAD bytes through an argument-logging `npx` shim on a CLI 21.2.19 workspace (`scratchpad/ng-audit/hooks-fx/npx-args.log`).
  - INFERRED: that the compile is empty. No TypeScript was installed, and the shim always exits 0.
  - Spec writes, and library writes inside an app workspace, were never covered by `tsconfig.app.json`. That is a design limit, not a v20 regression.
- **Fix:**
  - Never run `tsc` against a `files: []` + `references` config. Instead emit a non-blocking "type-check not verified: solution-style config" note on both surfaces and exit 0.
  - Add `tsconfig.lib.json` only after timing it against the 45 s budget. Never use `tsconfig.spec.json` for `.test.ts` files: it includes only `src/**/*.spec.ts`.
  - State the spec/library limit in `docs/enforcement-surfaces.md`.
  - Change the canary to name an application source file.
  - This is an escaped false green, so it gets the catching case plus at most three sentences of RCA in the commit body.

### 2b. A deprecated API is recommended, or is the only form named

**D1 — `HttpClientTestingModule`** [HTTPTEST-1, CMD-12, MD-09]

- **Where:**
  - `docs/defaults.md` A:113 and M:230, which offer it as the "legacy" alternative.
  - `A/.claude/commands/test.md:33`, which names it first with no label. M `test.md:39` is already current.
- **Fact:** the module is `@deprecated` in v20 and v22 (A20 and A22 `packages/common/http/testing/src/module.ts#L21`).
- **Fix:**
  - v20: `provideHttpClient()` then `provideHttpClientTesting()`.
  - v21+: `provideHttpClientTesting()` alone; add `provideHttpClient(…)` first only to enable features (A22 `adev/src/content/guide/http/testing.md#L11-L29`).
  - Keep the module only in a spec that already uses it.

**D2 — XSRF check names only `HttpClientXsrfModule`** [AS-06, MD-08]

- **Where:** `security-auditor.md` A:58 and M:67.
- **Fact:** the module is deprecated (A22 `packages/common/http/src/module.ts#L40-L41`). The standalone way to disable XSRF is `withNoXsrfProtection()` (A22 `adev/src/content/guide/security.md#L390-L396`).
- **Today:** a standalone app that disables XSRF matches nothing in the check.
- **Fix:** list all four forms:
  - `withNoXsrfProtection()`;
  - `withXsrfConfiguration` with an empty or mismatched cookie or header name;
  - the deprecated `HttpClientXsrfModule.disable()` / `.withOptions({ cookieName: '' })`;
  - XSRF handling removed.

**D3 — Route-guard check names only `CanActivate`** [AS-07]

- **Where:** `security-auditor.md` A:65 and M:38.
- **Fact:** `canLoad` is deprecated in favour of `canMatch` (A22 `goldens/public-api/router/index.api.md#L121-L158`).
- **Today (INFERRED):** a lazy route guarded only by `canMatch` is reported as unguarded, a false positive.
- **Fix:** accept `canActivate` or `canMatch`, and flag `canLoad` as deprecated.

**D4 — Legacy structural directives** [carrier-docs missed; part of CMD-05]

- **Where:** `docs/defaults.md` A:37 and M:154.
- **Today:**
  - The line does not say the directives are deprecated, and it omits `*ngSwitch`.
  - "Migrate … when touching existing templates" licenses a drive-by migration that the always-loaded Bug-fix scope forbids (`dist/angular/.github/instructions/framework-rules.instructions.md:116`).
- **Fact:** NgIf, NgFor and NgSwitch have been deprecated since 20.0 (NG `CHANGELOG.md#L3742`). Removal is now "a future major" (A22 `packages/common/src/directives/ng_if.ts#L160-L182`).
- **Fix:** "Use `@if`/`@for`/`@switch`; `*ngIf`/`*ngFor`/`*ngSwitch` are deprecated since v20. Migrate a template when its file is the primary target, not in a bug fix."

**D5 — The A6 package scan names no deprecated Angular package** [commands missed]

- **Where:** `bootstrap.md` A:92 and M:170.
- **Facts:**
  - `@angular/animations` was deprecated in 20.2 and is due for removal in v23 (NG `CHANGELOG.md#L3158`; A22 `packages/core/src/metadata/directives.ts#L601`).
  - `@angular/platform-browser-dynamic` was deprecated in 20.0 (NG `CHANGELOG.md#L3746`).
  - Both track the current major, so an "outdated" check never flags them.
- **Fix:** name both packages in the bullet.

### 2c. Misses a current default (grouped by theme)

**M1 — OnPush is the default on v22** [CD-1, CD-2, MD-01, MD-02, MD-03, CMD-01, ARCH-1]

- **Where:**
  - `docs/defaults.md` A:35 and M:152.
  - `As/AGENTS.md/bs-subtract:6` and `Ms/…/bs-subtract:6`.
  - `As/AGENTS.md/bs-primary-add:3` and `Ms/…/bs-primary-add:5`.
  - `bootstrap.md` A:62 and M:140.
  - `rebootstrap.md` A:96 and M:122.
  - `docs/ARCHITECTURE.md` A:135 and M:136.
- **Today:** the text says "OnPush on every component", "Add `ChangeDetectionStrategy.OnPush`" and "OnPush coverage — gaps". On v22, though:
  - an unset `changeDetection` already means OnPush (NG `CHANGELOG.md#L1096`);
  - `ng update` writes `Eager` into every existing component (A22 `packages/core/schematics/migrations.json#L3-L7`);
  - `Default` is deprecated (A22 `packages/core/src/change_detection/constants.ts#L18-L43`);
  - Angular's rules file says not to write OnPush explicitly (A22 `packages/core/resources/best-practices.md#L13`).
- **Consequence (INFERRED):** the A3 bootstrap pass reports every v22 component as a gap and misses the real gaps, the components pinned to `Eager`.
- **Fix (one wording, used everywhere):**
  - On v20/v21, set OnPush.
  - On v22+, leave `changeDetection` unset, or mirror the explicit form only where sibling components already carry it.
  - `Eager` (21.2+) or `Default` needs a documented reason. An `Eager` added by the migration is pending review, not a convention.
  - The Boy Scout item becomes "move off eager checking": add OnPush on v20/v21, remove `Eager`/`Default` on v22+.
  - Rebootstrap A3 also re-checks zoneless status.
- **Corrections to two slice fixes:** no lint config can *require* the explicit form, so the CD-2 and MD-01 lint clauses were inverted. The v22 rule allows explicit OnPush by default; with `allowExplicitOnPush: false` it flags the explicit form as redundant and autofixes it away (AE `packages/eslint-plugin/src/rules/prefer-on-push-component-change-detection.ts#L19`, `#L102-L130`).
- **Side effect for consumers (INFERRED):** that rule is `'error'` in v22 ts-recommended (AE `packages/angular-eslint/src/configs/ts-recommended.ts#L28`), so every migrated `Eager` component is a lint error. The Boy Scout note must call that pre-existing upgrade debt, not licence for a drive-by switch.

**M2 — Vitest is the default runner (v21+), and the Jest/WTR builders are gone (v22)** [TESTFOCUS-1, AS-02, AS-04, HSE-2, HSE-3, HSE-4, MD-06, MD-07, agents-skills missed ×2]

- **Where and what consumers get today:**
  - **Write guard,** `src/core/.claude/hooks/guard.ps1:65-68`. It checks only `*.spec.*` files and knows only `it|describe` `.only`/`.skip`. OBSERVED by the hooks slice probe on HEAD bytes under pwsh 7: these all exit 0 instead of being blocked:
    - in a `.spec.ts`: `test.only(`, `test.skip(`, `suite.only(`, `it.concurrent.only(`;
    - in a `.test.ts`: `it.only(` and `expect(true).toBe(true)`.

    The unit-test builder runs both `**/*.spec.ts` and `**/*.test.ts` by default (C21 and C22 `packages/angular/build/src/builders/unit-test/schema.json#L40-L46`; I read both fetched copies).
  - **ESLint sample,** `:20-31`. It bans only the Jasmine globals by `callee.name`, and only on `*.spec.ts`. Vitest has no `fit`/`xit` (vitest.dev/api).
  - **Skill text.** The floor statement (A:15 / M:18) says the guard blocks only "`fit`/`xit`". The red check (A:34 / M:66) uses `fdescribe`, which fails on any runner, so it certifies a gate that does not bite on Vitest.
  - **`docs/defaults.md`** A:115 / M:232 lists only the Jasmine forms.
  - **`scripts/metrics.ps1`** A:26-27 / M:46-47 counts only `it|describe`. OBSERVED (slice): it reports 0 for `test.only` / `test.skip` / `it.skipIf`.
  - **`add-tests` suite bootstrap** (A:54 / M:75) proposes "Jasmine/Karma or Jest". CLI v22 removed the Jest builder (CLI `CHANGELOG.md#L1051`).
  - **Spec scope.** The test-critic scope (A:15 / M:17) and the `add-tests` sibling lookup (A:24 / M:34) see only `*.spec.ts`.
- **Fix:**
  - Name the Jasmine forms and the Vitest/Jest forms side by side: `fit` / `fdescribe` / `xit` / `xdescribe`, plus `(it|test|describe|suite)(.concurrent)?.only` and `.skip`, on both `*.spec.*` and `*.test.*`.
  - **My correction to the slice regexes (INFERRED; Playwright docs not fetched):** Playwright e2e specs legitimately call `test.skip(condition, reason)` and a bare `test.skip()`. Hard-block `.skip` only when its first argument is a string or template literal (the declaration form). Count `skipIf`, `runIf` and `todo` in metrics, but do not block them.
  - New `add-tests` fallback: "`@angular/build:unit-test` runs its `runner` (Vitest when unset, CLI 21+); `@angular/build:karma` runs Karma/Jasmine; Jest only through a builder the workspace already configures."

**M3 — Zone versus zoneless evidence (v21)** [TOOLING-1, CMD-03, AS-05, AS-14, AS-15, HSE-8, commands missed]

- **Where and what consumers get today:**
  - **Conventions checklist,** `docs/defaults.md` A:24 / M:136. It asks for none of these: the change-detection provider, the test builder and runner, the build builder, `strictTemplates`.
  - **`bootstrap.md` A6** (A:94 / M:172) records only a framework name.
  - **`bootstrap.md` A3** (A:68 / M:146) reads only the *build* target's polyfills.
    - Raw TestBed has been zoneless since v21.
    - The CLI builders add `provideZoneChangeDetection()` when zone.js loads in the *test* build (C22 `packages/angular/build/src/builders/unit-test/runners/vitest/build-options.ts#L159-L185`, and karma `application_builder.ts#L214-L233`).
    - Nothing records which case applies, although test-critic (ad3bf972) depends on it.
    - The same line also names `provideExperimentalZonelessChangeDetection`, which was renamed in 20.0 (NG `CHANGELOG.md#L3675`).
  - **`bootstrap-pass.md`** A:14 globs only `*.ts` for code passes. A3 needs `angular.json`; the M copy already includes it.
  - **"zone-patched"** in `add-tests` (A:34 / M:47) is never defined.
  - **test-critic** (A:27 / M:30) ties the vitest patch to "Angular 22 or later". The patch actually ships in zone.js 0.16.2, which v21 accepts (NG `packages/zone.js/CHANGELOG.md#L13-L15`; A21 `packages/core/package.json#L24`). INFERRED; untested on v21.
  - **Eval `angular-003`** (`A/tests/evals/cases.yaml:44-75`, M:174-205) is ambiguous on v21-zoneless or v22-OnPush apps.
- **Fix:**
  - Use the TOOLING-1 wording, corrected: record the provider first, then the polyfill. Mark only webpack `:browser` and related builders as deprecated, not every `build-angular` builder.
  - Add an A6 bullet: "whether specs run zoned — zone.js loaded in the test build (the test target's polyfills, or v22 Vitest runtime detection), or overridden by `main` / `providersFile` / `setupFiles`."
  - Delete the "earlier `provideExperimentalZonelessChangeDetection`" clause.
  - Have bootstrap-pass read `angular.json` for every pass.
  - Use one phrase in both `add-tests` and test-critic: "(zone.js in the test target's resolved polyfills or setup file; under Vitest also `zone.js/plugins/vitest-patch`, zone.js 0.16.2+, documented from Angular 22)".
  - Pin the eval prompt to "zone.js change detection, no `changeDetection` override".

**M4 — Signal-based component APIs (stable since 19)** [IO-1, MD-04, MD-15, CMD-05, TPL-1, AS-09, AS-10, AS-12, missed bs-subtract:4 and bs-primary-subtract:3]

- **Where and what consumers get today:** these lines name only the decorator API.
  - `docs/defaults.md` A:34 / M:151: "via `@Input` / `@Output`".
  - `docs/defaults.md` A:48 / M:165.
  - `bs-subtract:4` (both stacks): "Unused `@Input`/`@Output`".
  - Carrier `lean-test:2` (both stacks): "`@Input` decorators bind". The M copy also drops "change detection runs".
  - `bootstrap.md` A3 (A:65 / M:143), which has no control-flow item.
  - bloat-radar (A:45 / M:46) and test-critic `:10` (both stacks).

  These lines send template logic to "component methods or pipes":
  - `docs/defaults.md` A:36 / M:153;
  - `bs-primary-add:2` (A) / `:4` (M);
  - A `bs-primary-subtract:3`;
  - bloat-radar A:56 / M:57.

  The style guide says "typically with a computed" (A22 `adev/src/content/best-practices/style-guide.md#L160-L167`). bloat-radar A:57 / M:58 flags `[style.color]`, which is the very form the style guide prefers (#L218-L235).
- **Facts:**
  - `input()`/`output()`/`model()` have been `@publicApi` since 19.0 (A20 `packages/core/src/authoring/model/model.ts#L111`).
  - Angular's rules: A22 `packages/core/resources/best-practices.md#L28-L31`.
  - The `host` property is preferred over `@HostBinding` and `@HostListener` (A22 `adev/src/content/guide/components/host-elements.md#L106-L108`).
- **Fix:**
  - "inputs/outputs: `input()`/`output()`/`model()` in new code; mirror the decorators where the file uses them."
  - Prefer `computed()` to methods.
  - A3 inventories signal versus decorator inputs, `model()`, `host` versus the decorators, and control flow; it also globs `*.html`.
  - bloat-radar flags a static `style="…"` attribute, not `[style.x]` bindings.
  - Carrier #12 says "inputs bind (`@Input` or `input()`) … change detection runs" in both stacks.
  - `docs/defaults.md:48`: use the IO-1 corrected wording.

**M5 — Signal Forms (absent in v20, experimental in v21, stable in v22)** [FORMS-1, MD-05, CMD-06, missed custom-control]

- **Where:** `docs/defaults.md` A:41-68 / M:158-185 and `bootstrap.md` A3 (A:66 / M:144).
- **Today:** only reactive and template-driven forms are detected. The greenfield default is reactive, and the custom-control table covers only `NG_VALUE_ACCESSOR`/`NgControl`.
- **Facts:** A21 `packages/forms/signals/src/api/structure.ts#L84`; A22 `#L118`; A22 `packages/core/resources/best-practices.md#L33-L34`.
- **Consequence (INFERRED):** a repo already on Signal Forms is classified as having "no forms approach", so the agent introduces a second one, and its custom controls get told to add `NG_VALUE_ACCESSOR`.
- **Fix:**
  - Detect `form()` imported from `@angular/forms/signals`. FORMS-1 also proposes accepting `[formField]`, or `[field]` on 21.0.0–21.0.8 (*slice, not re-checked*).
  - Name `FormValueControl`/`FormCheckboxControl` controls.
  - Scope the `NG_VALUE_ACCESSOR` table to reactive and template-driven forms.
  - The greenfield default is a policy choice (B0): Signal Forms on v22+, typed reactive forms on v20/v21.

**M6 — DI and standalone** [DEF-1, CMD-07, HSE-6, HSE-7]

- **Neutral default text,** `docs/defaults.md` A:27-28 / M:144-145.
  - **Facts:**
    - Standalone is the default since 19.0 (NG `CHANGELOG.md#L4862`).
    - The style guide prefers `inject()` (A22 `adev/src/content/best-practices/style-guide.md#L111-L120`).
    - angular-eslint recommended has errored on prefer-standalone and prefer-inject since v20.0.0 (AE `packages/angular-eslint/src/configs/ts-recommended.ts#L27`).
  - **History (OBSERVED):** commit 6879e5e8 (2026-09-05, empty body) made this text neutral, so reversing it is your decision (B0).
- **No injection style recorded,** `bootstrap.md` A1 (A:45 / M:123).
  - **Fact:** v22 `ng g service` emits `@Service()` (C22 `packages/schematics/angular/service/schema.json#L52`), which does not support constructor injection.
  - **Consequence (INFERRED):** in a repo that uses constructor injection, `ng g service` produces a class that cannot take constructor dependencies.
- **Eval `angular-001`** (`cases.yaml` A:18-20 / M:148-150) does not catch `@Service()` as a root provider (A22 `adev/src/content/guide/di/creating-and-using-services.md#L44-L111`).
- **`metrics.ps1` `new XService(`** (A:25 / M:51) misses suffix-less 2025-style names. OBSERVED (slice): it reports 0 for `new User()`.

**M7 — HTTP provider and backend** [CMD-08]

- **Where:** `bootstrap.md` A5 (A:81 / M:159), which records interceptors only.
- **Facts:**
  - HttpClient has been in root since v21.
  - v22 makes fetch the default, deprecates `withFetch`, and needs `withXhr` for upload progress; `reportProgress` is deprecated (NG `CHANGELOG.md#L1126-L1127`; A22 `packages/common/http/src/provider.ts#L308-L334`).
  - JSONP is deprecated in 22.1.
- **Fix:** CMD-08's corrected bullet, which searches for both the old and the new progress option names.

**M8 — Strictness**

- **`strict: true`, no weakening overrides,** `docs/defaults.md` A:89 / M:206.
  - The v22 migration writes `strictTemplates: false` into every upgraded workspace (A22 `packages/core/schematics/migrations.json#L13-L17`), and the docs do not say how to classify it.
  - Fix: "`strict` and `strictTemplates` on; a migration-written `strictTemplates: false` is debt, not convention."
- **`metrics.ps1` `ts_strict`,** A:41-42 / M:72-73 [HSE-5].
  - It is true only when a config literally says `"strict": true`. The v22 template omits it because TypeScript 6 makes strict the default (github.com/angular/angular-cli/commit/f3d9ef60adc48aa9c4ac3ecd1b497834c2a45d06). OBSERVED (slice): false on a v22-shaped fixture.
  - Fix: make the result tri-state.

**M9 — Version pivot and upgrade awareness** [CMD-02, CMD-04, CMD-09, MD-10, routing missed]

- **`bootstrap.md` A:21, A:153 and M:249** pivot on "17+" and "below 17". The pivot separates nothing, and standalone became the default in 19, not 17.
- **`rebootstrap.md` A6** (A:105 / M:131) does not say what a changed major implies. The baseline counts `package.json` by presence only (`src/core/scripts/bootstrap-baseline.ps1:29`).
- **`bootstrap.md` A6** (A:89-91 / M:167-169):
  - "currency" has no reference version;
  - the builder bullet does not separate the deprecated webpack builders from esbuild `:application`/`:browser-esbuild` (CLI `CHANGELOG.md#L1067-L1079`);
  - `strictTemplates` is not covered.
- **`bootstrap.md` A1 routing** (A:49 / M:127) has no `paramsInheritanceStrategy` item. The v22 flip ships without a migration; `CanMatchFn`'s snapshot is now required (NG `CHANGELOG.md#L1117-L1120`).
- **Fix:**
  - The pre-flight records the major and the v21/v22 defaults it carries, and reports an out-of-support major as a finding (see §3).
  - When the major changes, rebootstrap A6 re-checks every convention that depends on a default and lists the migration residue.
  - Fix the A6 builder bullet as CMD-09 corrected it.

**M10 — SSR and hydration** [SSR-1, CMD-10, part of MD-14]

- **Where and today:**
  - `docs/defaults.md` A:101-102 / M:218-219 still names "Angular Universal" and uses `isPlatformBrowser` as the rule.
  - The `bootstrap.md` checklist (A:153 / M:249) omits Styling and SSR/Hydration, although `docs/defaults.md` has both sections.
- **Facts:**
  - The SSR guides use `afterNextRender`/`afterEveryRender` in v20 and v22 (A22 `adev/src/content/guide/ssr.md#L237-L264`). v22 prefers platform providers.
  - v22 turns on incremental hydration by default (NG `CHANGELOG.md#L1268`).
  - `CommonEngine` is deprecated (CLI `CHANGELOG.md#L1075`).
- **Fix:** as SSR-1 and CMD-10 propose.

**M11 — Security auditor scope** [AS-08, agents-skills missed]

- **Today:**
  - The A description (`:3`) promises CSP, but the checklist has no CSP item.
  - The secret and non-HTTPS checks (A:42/:56, M:42/:67) look only in `environments/environment*.ts`, which `ng new` no longer generates (C22 `packages/schematics/angular/environments/schema.json`).
- **Fix:**
  - Delete "and CSP".
  - Widen the search to "committed configuration the production build loads".
  - Optional: SSR `allowedHosts: ['*']` and JSONP items. JSONP should be flagged as deprecated only on 22.1+.

**M12 — 2025 file naming** [AS-11, CMD-15]

- **Today:**
  - The bloat-radar glob (A:21 / M:21) is `*.helper.ts|*.util(s).ts`. The style guide names `utils.ts`, `helpers.ts` and `common.ts` as the generic names to avoid (A22 `adev/src/content/best-practices/style-guide.md#L32-L41`).
  - The bootstrap examples (A:255, :386; M:360) use `*.component.ts`.
- **Fix:** add the three bare names to the glob, and add one sentence that both naming styles coexist in v20–v22 repos.

**M13 — `ng new --ai-config` output is not treated as existing AI tooling** [CMD-13]

- **Where:** `adopt.md:65-72` and `bootstrap.md:18` (both stacks).
- **Today:** these paths are not recognised:
  - v20–v21: `.claude/CLAUDE.md`, `.gemini/GEMINI.md`, `.junie/guidelines.md`, `.windsurf/rules/guidelines.md`;
  - v22 MCP configs: `.mcp.json`, `.cursor/mcp.json`, `.vscode/mcp.json`, `.codex/config.toml`, `.gemini/settings.json`.

  Sources: C20 `packages/schematics/angular/ai-config/index.ts` and C22 `packages/schematics/angular/ai-config/index.ts#L14-L60`.
- **Consequence (INFERRED):** version-specific Angular rules get read as team conventions, or go unscreened.
- **Out of scope here:** the installer side (`src/core/scripts/install.ps1:346-352`, guarded) is one BACKLOG line, not an edit.

**M14 — The baseline does not ignore `__screenshots__/`**

- **Where:** `src/core/scripts/bootstrap-baseline.ps1:35`.
- **Fact:** the CLI's `.gitignore` template has ignored it since 20.3.3 (CLI `CHANGELOG.md`, commit b7f92da78, at 20.3.3).
- **Consequence (INFERRED):** for a workspace whose `.gitignore` predates 20.3.3, Vitest browser-mode failure screenshots get hashed into the baseline. Low priority.

### 2d. Framing (no wrong behaviour on any supported major)

- **F1 — Version-gate examples** [VER-1, MD-13].
  - Where: `As/` and `Ms/` `.github/instructions/framework-rules.instructions.md/verif-rules:3` (always loaded); `README.md:19` in both stacks; `docs/ARCHITECTURE.md` A:132 / M:133.
  - All four examples (signals, control flow, `inject()`, `takeUntilDestroyed`) exist on v20, so none of them is a real gate.
  - Delete the example sentence from the carrier. README and ARCHITECTURE should name the real gates: Signal Forms, `resource`/`httpResource`, `@Service`, `Eager`.
- **F2 — Stale floors and labels** [VER-2, MD-11, MD-12, MD-14]. Handled in §3.
- **F3 — State inventory, `bootstrap.md` A2** (A:53,57 / M:131,135) [CMD-11]. Add `resource`/`httpResource`/`rxResource` (experimental before v22; A22 `packages/core/src/resource/resource.ts#L50`) and NgRx SignalStore.
- **F4 — Monorepo rebootstrap skill numbering,** `Ms/.agents/skills/rebootstrap/SKILL.md/summary:1` [CMD-14]. It says ".NET A1–A8 / Angular A1–A7". The command defines .NET A1–A7, Angular A1–A6, W1–W3 and a shared A8.
- **F5 — Monorepo `/test` naming,** `M/.claude/commands/test.md:28` [MD-16]. It imposes `should … when …` unconditionally. The A copy (`:28`) applies it only when the repo has no convention of its own.
- **F6 — NgModule-era deltas** (commands missed).
  - `rebootstrap.md` A:90 / M:116 treats "new standalone components" as the delta. The delta worth noting now is `standalone: false` or a new NgModule.
  - `bootstrap.md` A:48 / M:126: "Shared/core module boundaries".
- **F7 — Lockfile assumption,** `bootstrap.md` A:297 / M:404 [commands missed]. Only `package-lock.json` is read. Say "the lockfile": yarn, pnpm and bun are allowed too (C22 `packages/angular/cli/lib/config/workspace-schema.json#L47-L51`, *slice*).
- **F8 — Environment files, `bootstrap.md` 3d-ter** (A:360 / M:472). It assumes `environment*.ts`.
- **F9 — Adopt 1h toolchain list,** `adopt.md:119`. It lacks the Vitest config and `karma.conf.js`.
- **F10 — Update Guide,** `dependency-audit` A:66-69 / M:136-139 [AS-13]. Add the Update Guide. Its data lives in `adev/src/app/features/update/recommendations.ts`.
- **F11 — Example pitfall,** `FRAMEWORK-CONTEXT.md` A:50 / M:63: "Angular 14 or below". Optional rewrite.
- **F12 — Eval `angular-006`** (`cases.yaml` A:113 / M:243): "in an HttpInterceptor". Change to "an HTTP interceptor".

### 2e. Adjacent findings, not version-related (verified)

- **`noInlineConfig` makes the red check partly false.** With `noInlineConfig: true`, ESLint reports each inline directive as a *warning* and collects no directives (`fetched lib/linter/linter.js` L1088-L1101 and L1278-L1287, ESLint main). So `reportUnusedDisableDirectives: 'error'` does nothing, and the skill's red check "show both fail" (A:34-35 / M:66-67) is false for the disable comment. Fix it in B1, since the files are the same.
- **`catchError` conflict.** `docs/defaults.md` A:80 / M:197 ("Use `catchError` to prevent stream death") conflicts with carrier Leanness #6. One BACKLOG line.

### 2f. Dropped or corrected (one line each)

- **`playbook.md:7`** "component that can't use OnPush": dropped. It is still true on v22, where that component stays `Eager`. The same slice also listed it as clean.
- **README A:204 / M:207** "OnPush is intentionally excluded": dropped. The switch is still a semantic change on every major.
- **HSE-1's claim that spec and library writes regressed in v20:** dropped. `tsconfig.app.json` never included them.
- **AS-05 "breaks":** downgraded. Sibling specs are read first, and step 5 runs the spec. **CMD-11:** reclassified as framing.
- **CD-2 and MD-01 lint clauses:** corrected in M1 (the condition was inverted, and no config can require the explicit form).
- **Fact sheet, angular-eslint versus Angular on explicit OnPush:** the two do not conflict.
- **Fact sheet, "TestBed zoneless even with zone.js":** true only of raw TestBed; corrected in M3.
- **VER-2 and MD-10 floors that hard-code the version or read it from Angular's support table:** replaced by §3.
- **HSE-2 and AS-02 blanket `test.skip(` / `skipIf` blocks:** narrowed (M2).
- **HSE-4 red-first plan:** cannot go red. The ScriptBehavior fixture already holds `fit(` and the test asserts only non-zero (`src/core/tests/hooks/ScriptBehavior.Tests.ps1:263-291`, *slice*). It needs an exact-count Vitest fixture.
- **Citation fixes:** the AS-11 URL host should read `angular/angular-cli`, and the CD-1 cite `README.md:8` should be `:27`.

## 3. The README's "Angular 17+" floor

**Recommendation: raise it.** State it in `A/README.md:5`, `M/README.md:5` and the `Angular Version & Tooling` heading of `docs/defaults.md` (A:23 / M:135) as:

> Angular v20–v22: the current major and the two before it, as of 2026-10. Support status: angular.dev/reference/releases.

- **Why not tie the floor to "the oldest supported major":** that is v21 from 2026-11-28, which would drop guidance seven months before your v20 consumers move. Keep the support table for reporting only: `/bootstrap` flags an out-of-support major as a finding.
- **Why not keep "17+" and gate it:** no consumer is on v17–v19. The only text keyed to 17 is dated wrongly (standalone became the default in 19.0, NG `CHANGELOG.md#L4862`) and gates nothing. The splits that matter, at v21 and v22, are missing.
- **How to word version splits:** name the major ("v22+") at each split, and never label anything below the floor. The ~June 2027 bump to v21 then deletes the v20 branches and nothing else.

**What raising the floor lets you delete** (OBSERVED by `git grep` at HEAD):

- the 17 pivots in `bootstrap.md` A:21, A:153 and M:249;
- "(Angular 16+)" in `docs/defaults.md` A:78 / M:195 and `bootstrap.md` A:68 / M:146;
- "earlier `provideExperimentalZonelessChangeDetection`" (`bootstrap.md` A:68 / M:146);
- "Angular Universal" (`docs/defaults.md` A:101 / M:218);
- "Angular 17+" in `README.md:5` (both stacks) and `M/docs/defaults.md:3`;
- the carrier's `verif-rules:3` example sentence, `README.md:19` and `ARCHITECTURE.md` A:132 / M:133;
- `HttpClientTestingModule` and `HttpClientXsrfModule` as named alternatives (both become "mirror only");
- the "Angular 14" example in `FRAMEWORK-CONTEXT.md`;
- optionally the neutral standalone branch (B0).

**What raising it does not delete:**

- Karma/Jasmine, which is still supported in v22 (A22 `adev/src/content/guide/testing/karma.md#L3-L14`);
- zone.js paths;
- mirroring of NgModule and decorator code;
- `*ngIf` migration guidance (deprecated, not removed).

Raising the floor is about a dozen label and pivot deletions. The real work is the v21/v22 splits in §2.

## 4. Proposed change set (ordered batches)

**Every batch:**

- `scripts/build.ps1` ×3, then `validate-dist` ×3, then `context-footprint -Check`.
- Review the `src/stacks/monorepo/` sibling of each snippet or file you touch.
- Add a root `CHANGELOG.md` entry, plus the `## 0.95.0 — Unreleased` head in all three stack CHANGELOGs.

**How I read the tiers:** `src/stacks/*/files/.claude/**` and `src/core/.claude/hooks/**` are guarded (AGENTS.md:15-21). Docs, snippets, `scripts/*.ps1` and `scripts/ci/*`, evals and READMEs are ordinary. I read `.github/**` as anchored at the repo root, so `*/snippets/.github/**` is ordinary; raise it if you read it differently.

| # | Tier | Scope | Files | Red first |
|---|------|-------|-------|-----------|
| **B0** | decision | DEF-1 (reverse 6879e5e8's neutral standalone/`inject()` wording?) and the Signal Forms greenfield default for v22+ | one `meta/workspace-decisions.md` entry plus its index line, if you reverse | n/a |
| **B1** | guarded | K1, the M2 sample and skill parts, §2e `noInlineConfig` | `A/scripts/ci/eslint-standards.sample.mjs`; `{A,M}/.claude/skills/enforce-standards/SKILL.md` (merge rule, floor statement, red check using the repo runner's focus form and a disable placed above a real violation) | No in-repo instrument runs ESLint. Reproduce in a scratch workspace: `ng new` + `ng add angular-eslint`, merge the HEAD fragment, run `ng lint` and expect `Could not find plugin`. With the fix, `it.only(` in a spec goes from green to red. Not yet executed by anyone. |
| **B2** | guarded | K2, F10 | `{A,M}/.claude/skills/dependency-audit/SKILL.md` | Text-only skill edit, so there is no in-repo red. The line to paste is `ng update @angular/core@22 @angular/cli@22` on a scratch v21 + `@ngrx/store@21` workspace, failing with "Incompatible peer dependencies found" (not run). Ship B2 first: the v20 LTS deadline is 2026-11-28. |
| **B3** | guarded, review item 4 (`guard.ps1`) | M2 guard parts, including the `.test.*` tautology route | `src/core/.claude/hooks/guard.ps1:65-68`; `src/core/tests/hooks/fixtures/guard-cases.ps1`; `dist/{angular,monorepo,dotnet}` | Guard-cases rows. Block: `test.only(`, `suite.only(`, `it.concurrent.only(` and `test.skip('x'` in a `.spec.ts`; `it.only(` and `expect(true).toBe(true)` in a `.test.ts`. These exit 0 at HEAD (slice probe, OBSERVED). Allow: `test.skip(isMobile, 'r')` in an e2e spec. Run on pwsh, `powershell.exe` and CP437. Pipe a fixture JSON into the dist copy on both surfaces (exit 2 plus stderr / deny JSON). Then you read the diff, or a fresh session attacks it. |
| **B4** | guarded, escaped defect | K3, plus M14 (kept here so B7 stays ordinary; 08562cad treated the baseline script as guarded) | `{A,M}/.claude/hooks/post-write.ps1`; `src/core/tests/hooks/PostWriteRouting.Tests.ps1`; `src/core/scripts/framework-doctor.ps1:558,560`; `src/core/docs/enforcement-surfaces.md`; `src/core/scripts/bootstrap-baseline.ps1:35` + `BootstrapBaseline.Tests.ps1` | Reuse the existing `POSTWRITE_ARGS` shim (`PostWriteRouting.Tests.ps1:173-198`) over a root `{"files":[],"references":[…]}` with no `tsconfig.app.json`. At HEAD it logs `-p tsconfig.json` (red); assert no `tsc` call and the not-verified note. For the baseline, an untracked `src/app/__screenshots__/x.png` gets hashed at HEAD. Both hosts and CP437, plus a dist pipe. Add the three-sentence RCA. |
| **B5** | guarded | M1 (A3/rebootstrap), M3, M4 (A3, bloat-radar, test-critic), M5 (A3), M6 (A1), M7, M9, M10 checklist, M11, M12, M13 (adopt/bootstrap guard), D1 (`test.md`), D2, D3, D5, F3–F9 | `{A,M}/.claude/commands/{bootstrap,rebootstrap,test,adopt}.md`; `{A,M}/.claude/agents/{bootstrap-pass,security-auditor,bloat-radar,test-critic}.md`; `{A,M}/.claude/skills/add-tests/SKILL.md`; `Ms/.agents/skills/rebootstrap/SKILL.md/summary`. Splitting into 5a (commands) and 5b (agents/skills) keeps each diff reviewable. | Text-only, so there is no behaviour to show red. Where an instrument is possible, add an eval case run against HEAD first. Example: a v22 fixture with three components without `changeDetection` and one `Eager` component; must_match names the `Eager` one as the gap, must_not_match is "add ChangeDetectionStrategy.OnPush". The eval harness is external. |
| **B6** | ordinary | M1 (`docs/defaults.md`, Boy Scout, ARCHITECTURE), M2 (`docs/defaults.md:115`), M3 (`:24`), M4, M5, M6 per B0, M8 (`:89`), M10 comment, D1 (`docs/defaults.md`), D4, F1, F2/§3, F11 | `{A,M}/docs/{defaults,ARCHITECTURE}.md`; `{A,M}/README.md`; `{A,M}/FRAMEWORK-CONTEXT.md`; `{As,Ms}/AGENTS.md/{bs-subtract,bs-primary-add,bs-primary-subtract}`; `{As,Ms}/.github/instructions/framework-rules.instructions.md/{verif-rules,lean-test}` | Text-only. `context-footprint -Check` is the gate most likely to trip, because AGENTS.md and the carrier are always loaded; offset growth with the F1 deletion. The consumer-voice CHANGELOG entry must tell existing installs to update their own Boy Scout items 10/16 (consumer-protected). |
| **B7** | ordinary | M2/M6/M8 metrics, M3/M6 evals, F12 | `{A,M}/scripts/metrics.ps1`; `{A,M}/tests/evals/cases.yaml`; `src/core/tests/hooks/ScriptBehavior.Tests.ps1` | Add new exact-count fixtures, each a red case at HEAD (OBSERVED on scratch fixtures by the slice): Vitest-shaped `test.only`/`test.skip`/`it.skipIf` gives 0; a v22 tsconfig with no `strict` key plus TypeScript 6.x gives `ts_strict` false; `@Service() export class User{}` + `new User()` gives 0. For evals, check the `@Service` lookahead against a sample answer. |

**BACKLOG lines, not edits:**

- add the `install.ps1` `adoptionSignals` paths for `--ai-config` output (guarded installer);
- the `catchError` versus Leanness #6 conflict.

**Order.** AGENTS.md allows one push per session. A suggested split:

1. B2 + B1 (the time-sensitive breaks).
2. B3 (it needs your review of `guard.ps1`).
3. B4.
4. B0 → B6.
5. B5.
6. B7.

## 5. What stays uncertain

- **Runtime consequences were inferred, never executed:**
  - K1: no ESLint run.
  - K2: no `ng update` run.
  - K3: the empty compile (the probe had no TypeScript, and the shim exits 0).
  - zone.js 0.16.2's vitest-patch on v21 (AS-14).
  - The M6 `@Service` hazard and the M3 eval rendering.
- **Playwright conditional skips.** My narrowing of the `.skip` block in M2 and B3 rests on my knowledge of Playwright's `test.skip(condition, reason)`. I did not fetch Playwright's docs this session.
- **angular-eslint after `ng update`.** I did not check whether angular-eslint's own v22 update relaxes `prefer-on-push…` for migrated `Eager` components. That decides how loud M1 is in your consumers' CI.
- **Not re-checked by me:**
  - that `runner` is required with no default in the v20 unit-test schema (AS-04);
  - the `[field]` → `[formField]` rename window (FORMS-1);
  - `ScriptBehavior.Tests.ps1:263-291` and the workspace-schema `packageManager` enum (slice cites).
- **Source freshness.** I read the Angular facts from copies saved earlier this run (`ng-changelog.md`, `cli-changelog.md`, `releases-main.md`, `carrier/`, `src/`). I did not re-fetch GitHub. The patch numbers in the fact sheet are not used here.
- **TypeScript 6 strict-by-default** rests on the CLI commit and template, not on TypeScript's release notes.
- **Snippet tier.** Whether `*/snippets/.github/**` falls under guarded `.github/**` is a reading of AGENTS.md:21; I treated it as ordinary.
- **Context footprint.** The effect of B6 is unknown until you run `-Check`.
- **v23.** No 23.0.0-next exists. Only `@angular/animations` and server-side XHR carry a v23 removal target, and the shipped tree has no animations guidance (`git grep` found none). D5 is the only pre-emptive change.
- **"Within 1–2 versions of latest"** is read as latest, latest-1 and latest-2, which gives v20–v22. If you meant at most one major behind, the floor is v21, and the v20 branches in §2 can be dropped now.

## Addendum 2026-10-09: consumers are on Angular 21.2 (maintainer)

- **Scope narrows to v21-v22.** The floor is v21, the target v22 (their next `ng update`). Every v20 branch in §2 and the v20 LTS
  deadline in §1 drop out; version splits become "v21: …; v22+: …".
- **Order changes.** K2 (dependency-audit stalls on NgRx peers) is their 21 → 22 upgrade, so it stays first; the urgency is
  their upgrade date, not 2026-11-28. K1 stays. K3 applies only to library-only workspaces.
- **21.2 facts that shape the fixes** (fact sheet §4-§6): `ChangeDetectionStrategy.Eager` exists and `Default` is deprecated in
  21.2, so "set OnPush" stays right on 21 and the v22 Eager residue lands at their upgrade; Signal Forms and
  `resource`/`httpResource` are experimental on 21, so the greenfield forms default stays reactive until they are on 22 (B0's
  Signal Forms question resolves to "detect, do not default"); `provideHttpClientTesting()` alone works on 21; `fakeAsync` under
  Vitest is unsupported on 21 per the v21 docs, so test-critic's "vitest-patch, Angular 22 or later" is right for them; a repo
  upgraded from v20 keeps `provideZoneChangeDetection` and usually Karma, while a repo created on 21 is zoneless with Vitest.
- **Field report #9** can record Angular 21.2 as captured (maintainer, 2026-10-09) in the first batch commit.
