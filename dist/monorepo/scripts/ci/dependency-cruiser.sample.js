// Sample dependency-cruiser config — copy to .dependency-cruiser.js and adjust the globs to your
// layering. Makes layer/feature dependency direction a BUILD-BREAKING gate, complementing the
// semantic `solid-check` agent. Scaffolded by the `enforce-architecture` skill. See CLAUDE.md > SOLID.
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      comment: 'Circular dependencies break layering and make code hard to reason about.',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    {
      name: 'core-shared-not-depend-on-features',
      comment: 'core/shared are lower layers — they must not depend on feature code (inward-only).',
      severity: 'error',
      from: { path: '^src/app/(core|shared)/' },
      to: { path: '^src/app/features/' },
    },
    {
      name: 'no-cross-feature-imports',
      comment: 'Features must not import each other directly — go through shared/core.',
      severity: 'error',
      from: { path: '^src/app/features/([^/]+)/' },
      to: { path: '^src/app/features/(?!$1)[^/]+/' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.json' },
  },
};
