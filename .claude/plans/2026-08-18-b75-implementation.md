# B-75 implementation report

Added reached-set assertions to `WikiCheck.Tests.ps1` and `BuildArchitectureHtml.Tests.ps1`.
`FrameworkDoctor.Tests.ps1` was not changed: `Parse-DoctorResult` already asserts the exact set of
all 12 `$DoctorRowNames` on every parsed run, so adding another assertion would duplicate it.

## Finding and changes

The first clean WikiCheck run made the new assertion red:

```text
[FAIL] fixtures reach every expected wiki-check branch -- check 'malformed frontmatter' was never reached ...
```

The case named `malformed frontmatter fails` actually contained valid opening and closing
frontmatter delimiters, so it reached missing-field checks instead. I fixed the fixture by removing
the closing delimiter; I did not trim `malformed frontmatter` from the expected set. Clean result:
`WikiCheck.Tests: 14 passed, 0 failed, 0 skipped`.

Applied red-tests via `_MutationHelper.ps1`:

- Removed the sole body-injection fixture: WikiCheck failed with
  `check 'injection marker in body' was never reached`, command exit 1, restore byte-identical.
- Removed the table input from the architecture fixture: BuildArchitectureHtml failed with
  `check '| a | b |' was never reached`, command exit 1, restore byte-identical.

Clean BuildArchitectureHtml result: `5 passed, 0 failed, 0 skipped`. The composed copies passed in
the shipped suite runs. Direct Windows PowerShell 5.1: **NOT OBSERVED**. No requested assertion was
left without a red observation; FrameworkDoctor was explicitly skipped because the reached-set
assertion already existed.

Full shipped/meta aggregate results are the real numbers recorded in the B-59 report: dotnet and
monorepo each have the same two unrelated boy-scout failures, angular is green, and the meta runner
has the unrelated RepositoryPrivacy sandbox-warning failure. No out-of-scope fix was made.

