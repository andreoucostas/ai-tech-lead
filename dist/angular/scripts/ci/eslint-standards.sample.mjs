// Deterministic standards floor - scaffolded by the `enforce-standards` skill.
// Merge into the repo's eslint.config.js (flat config). Zero new dependencies:
// core ESLint + typescript-eslint, which angular-eslint projects already have.
//
// Brownfield note: if existing violations are numerous, fix the cheap ones first and record the
// rest in TECH_DEBT.md (Category: Standards) - do not weaken these rules to go green.

// Test-runner globals: Jasmine/Karma, Vitest, Jest, Mocha/Cypress (`context`) and Playwright (`test`).
const RUNNER = '/^(it|test|describe|suite|context)$/';
const FOCUS_SKIP_ALIAS = '/^(fit|fdescribe|xit|xdescribe|xtest)$/';

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
    // Karma/Jasmine focuses and skips with fit/fdescribe/xit/xdescribe; Vitest, Jest, Mocha, Cypress
    // and Playwright with .only/.skip, also chained (`it.concurrent.only`, `test.only.each`,
    // `describe.skip.each`) and Jest's `xtest`. Vitest is the default runner for projects created on
    // Angular 21 or later and runs both *.spec.ts and *.test.ts; Cypress specs are *.cy.ts. A `.skip`
    // is flagged only in its declaration form (a string, template or `X.name` title first), so a
    // Playwright `test.skip(condition, reason)` stays allowed.
    files: ['**/*.spec.ts', '**/*.test.ts', '**/*.cy.ts'],
    rules: {
      'no-restricted-syntax': [
        'error',
        {
          selector: `CallExpression[callee.name=${FOCUS_SKIP_ALIAS}], MemberExpression[object.name=${FOCUS_SKIP_ALIAS}]`,
          message: 'Focused or skipped spec (fit/fdescribe/xit/xdescribe/xtest) must not be committed.',
        },
        {
          selector: `MemberExpression[object.name=${RUNNER}]:matches([property.name='only'], [property.value='only']), MemberExpression[object.object.name=${RUNNER}][property.name='only']`,
          message: 'Focused spec (.only) must not be committed.',
        },
        {
          selector: `CallExpression[callee.property.name='skip']:matches([callee.object.name=${RUNNER}], [callee.object.object.name=${RUNNER}]):matches([arguments.0.type='TemplateLiteral'], [arguments.0.type='Literal'][arguments.0.raw=/^["']/], [arguments.0.type='MemberExpression'][arguments.0.property.name='name']), MemberExpression[object.object.name=${RUNNER}][object.property.name='skip'][property.name='each']`,
          message: 'Skipped spec (.skip) must not be committed - delete it or fix it.',
        },
      ],
    },
  },
];
