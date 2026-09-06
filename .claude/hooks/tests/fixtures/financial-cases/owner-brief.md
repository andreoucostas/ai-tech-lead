# Review brief

Review every method in `FinancialCases.cs` against these owner-supplied rules. The method names
describe mechanisms or selection choices; they do not state which implementation is acceptable.

- Two concurrent accepted changes of 10 start from 100. The starting state is sufficient for both,
  and the final value must reflect both changes: 80.
- The two input terms `[0.004, 0.004]` are unrounded allocation ratios. Their expected aggregate is
  0.008 with an absolute tolerance of 0.000001. Rounding belongs at the later presentation boundary,
  which is not included in this fixture.
- Within one invocation, the request identifiers are `['request-1', 'request-1']`; that bounded
  batch must produce at most one effect. No persistence across separate invocations is claimed.
- The report input contains a current row for key `A` with amount 100 and a non-current row for the
  same key with amount 50. The report includes only rows marked current, so its expected total is 100.

This fixture supplies no database, framework, deployment, policy provenance beyond these rules, or
evidence about behavior outside the shown inputs. Report such gaps as unresolved rather than
inventing them.
