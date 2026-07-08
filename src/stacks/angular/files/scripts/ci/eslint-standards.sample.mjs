// Deterministic standards floor - scaffolded by the `enforce-standards` skill.
// Merge into the repo's eslint.config.js (flat config). Zero new dependencies:
// core ESLint + typescript-eslint, which angular-eslint projects already have.
//
// Brownfield note: if existing violations are numerous, fix the cheap ones first and record the
// rest in TECH_DEBT.md (Category: Standards) - do not weaken these rules to go green.

export default [
  {
    // Inline `// eslint-disable` comments stop working; leftovers are flagged as errors.
    linterOptions: {
      noInlineConfig: true,
      reportUnusedDisableDirectives: 'error',
    },
    rules: {
      // @ts-ignore / @ts-nocheck fail lint (same floor the write-time guard hook enforces at edit time).
      '@typescript-eslint/ban-ts-comment': 'error',
    },
  },
  {
    // Focused or skipped specs fail lint - a spec suite you can silently narrow enforces nothing.
    files: ['**/*.spec.ts'],
    rules: {
      'no-restricted-syntax': [
        'error',
        { selector: "CallExpression[callee.name='fit']", message: 'Focused spec (fit) must not be committed.' },
        { selector: "CallExpression[callee.name='fdescribe']", message: 'Focused suite (fdescribe) must not be committed.' },
        { selector: "CallExpression[callee.name='xit']", message: 'Skipped spec (xit) must not be committed - delete it or fix it.' },
        { selector: "CallExpression[callee.name='xdescribe']", message: 'Skipped suite (xdescribe) must not be committed - delete it or fix it.' },
      ],
    },
  },
];
