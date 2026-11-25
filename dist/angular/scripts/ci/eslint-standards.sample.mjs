// Deterministic standards floor - scaffolded by the `enforce-standards` skill.
// Merge into the repo's eslint.config.js (flat config). Zero new dependencies:
// core ESLint + typescript-eslint, which angular-eslint projects already have.
//
// Brownfield note: if existing violations are numerous, fix the cheap ones first and record the
// rest in TECH_DEBT.md (Category: Standards) - do not weaken these rules to go green.

// Test-runner globals: Jasmine/Karma, Vitest, Jest, Mocha/Cypress (`context`, `specify`) and Playwright (`test`).
const RUNNER = '/^(it|test|describe|suite|context|specify)$/';
const FOCUS_SKIP_ALIAS = '/^(fit|fdescribe|xit|xdescribe|xtest|xcontext|xspecify)$/';
// A declaration's first argument is its title: a string, a template or `X.name`.
const TITLE = `[arguments.0.type='TemplateLiteral'], [arguments.0.type='Literal'][arguments.0.raw=/^["']/], [arguments.0.type='MemberExpression'][arguments.0.property.name='name']`;

export default [
  {
    // Inline ESLint directive comments stop working: ESLint reports each one as a warning and
    // applies none of them, so the violation a comment meant to hide still fails lint.
    linterOptions: {
      noInlineConfig: true,
    },
  },
  {
    // Keep a plugin rule inside an object whose `files` match where the repository's config
    // registers that plugin. `ng add angular-eslint` registers typescript-eslint under `**/*.ts`
    // only; an unscoped rule also reaches `*.html` (inline templates included) and ESLint aborts
    // with "Could not find plugin".
    files: ['**/*.ts'],
    rules: {
      // TypeScript ignore and nocheck comments fail lint (same floor the write-time guard hook enforces at edit time).
      '@typescript-eslint/ban-ts-comment': 'error',
    },
  },
  {
    // Focused or skipped specs fail lint - a spec suite you can silently narrow enforces nothing.
    // Karma/Jasmine focuses and skips with fit/fdescribe/xit/xdescribe; Mocha and Cypress also with
    // xcontext/xspecify; Vitest, Jest, Mocha, Cypress and Playwright with .only/.skip, also chained
    // (`it.concurrent.only`, `test.describe.serial.only`, `test.only.each`, `test.skip.concurrent`,
    // `describe.skip.each`), Jest's `xtest`, and Playwright's `test.fixme`. Vitest is the default
    // runner for projects created on Angular 21 or later and runs both *.spec.ts and *.test.ts;
    // Cypress specs are *.cy.ts. A `.skip` or `.fixme` is flagged in its declaration form (a title
    // first, then the body) or with a literal `true` first, as the write-time guard hook does, so a
    // Playwright `test.skip(condition, reason)`, a bare `test.fixme()` and Vitest's runtime
    // `context.skip('reason')` stay allowed. Check that your lint target's file patterns reach the
    // folder your end-to-end specs live in (the angular-eslint schematic writes `src/**` patterns only).
    files: ['**/*.{spec,test,cy}.ts', '**/*.{spec,test,cy}.{js,mjs,cjs}'],
    rules: {
      'no-restricted-syntax': [
        'error',
        {
          selector: `CallExpression[callee.name=${FOCUS_SKIP_ALIAS}], MemberExpression[object.name=${FOCUS_SKIP_ALIAS}]`,
          message: 'Focused or skipped spec (fit/fdescribe/xit/xdescribe/xtest/xcontext/xspecify) must not be committed.',
        },
        {
          selector: `MemberExpression[object.name=${RUNNER}]:matches([property.name='only'], [property.value='only']), MemberExpression[object.object.name=${RUNNER}][property.name='only'], MemberExpression[object.object.object.name=${RUNNER}][property.name='only']`,
          message: 'Focused spec (.only) must not be committed.',
        },
        {
          selector: `CallExpression[callee.property.name=/^(skip|fixme)$/]:matches([callee.object.name=${RUNNER}], [callee.object.object.name=${RUNNER}]):matches(${TITLE})[arguments.1], CallExpression[callee.property.name=/^(skip|fixme)$/]:matches([callee.object.name=${RUNNER}], [callee.object.object.name=${RUNNER}])[arguments.0.type='Literal'][arguments.0.raw='true'], CallExpression[callee.object.property.name=/^(skip|fixme)$/]:matches([callee.object.object.name=${RUNNER}], [callee.object.object.object.name=${RUNNER}]):matches(${TITLE}), MemberExpression[object.object.name=${RUNNER}][object.property.name='skip'][property.name='each']`,
          message: 'Skipped spec (.skip/.fixme) must not be committed - delete it or fix it.',
        },
      ],
    },
  },
];
