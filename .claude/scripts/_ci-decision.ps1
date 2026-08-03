# The publish-phase decision table, as a pure function (B-88). Maintainer-only, does NOT ship.
#
# Dot-sourced by release.ps1 and called directly by .claude/hooks/tests/ReleaseCiWatch.Tests.ps1.
# It lives in its OWN file rather than inside watch-ci.ps1 for a mechanical reason: dot-sourcing a
# script executes its param block, and watch-ci.ps1's -Sha is [Parameter(Mandatory)] -- dot-sourcing
# it would PROMPT, and a prompt hangs a non-interactive release. (The same trap release.ps1's own
# -ReviewEvidence comment records at its param block.)
#
# Why a function at all, rather than an `if` chain inline in release.ps1: the mapping from "what CI
# said" to "do we tag, what do we print, what do we exit" is the substance of B-88, and a test that
# extracts a region of release.ps1 as text cannot prove it -- ReleaseStagingGuard.Tests.ps1:10-12
# says so about its own technique, and it had a real end-to-end release to supply the missing
# evidence. This is callable, so the test calls the code that runs.

# Returns the publish decision. NOTE the deliberate default at the bottom: any exit code this
# function does not recognise is treated as UNVERIFIED and does NOT tag. A future watch-ci exit code
# must never fall through to "green" -- that is the failure class this repo keeps removing (B-64,
# B-72, B-74, B-75: instruments that could not fail, reporting success).
function Get-CiPublishDecision {
    param(
        # Watched  = the watch ran and $WatchExit carries its verdict
        # NoPush   = -NoPush: nothing reached origin, so there is no CI run to have an opinion
        # Override = -AllowUnverifiedCi: the operator waived the check. NOT the same fact as
        #            CANT-VERIFY, and deliberately worded differently everywhere it surfaces.
        [ValidateSet('Watched', 'NoPush', 'Override')][string]$Mode = 'Watched',
        [int]$WatchExit = 0
    )
    switch ($Mode) {
        'NoPush' {
            return [pscustomobject]@{
                Status = 'LOCAL'; Tag = $true; ReleaseExit = 0
                TagNote = ' (not pushed; CI not run)'
                Message = 'Not pushed (-NoPush), so there is no CI run to watch. The local tag records a locally-green release only.'
            }
        }
        'Override' {
            return [pscustomobject]@{
                Status = 'NOT-CHECKED'; Tag = $true; ReleaseExit = 0
                TagNote = ' (CI unverified: operator override)'
                Message = 'CI NOT CHECKED -- operator override (-AllowUnverifiedCi). The tag is annotated so the waiver travels with the artifact whose meaning it changes.'
            }
        }
    }
    switch ($WatchExit) {
        0 {
            return [pscustomobject]@{
                Status = 'GREEN'; Tag = $true; ReleaseExit = 0
                TagNote = ''
                Message = 'CI green for the release commit.'
            }
        }
        1 {
            return [pscustomobject]@{
                Status = 'RED'; Tag = $false; ReleaseExit = 1
                TagNote = ''
                Message = 'CI is RED for the release commit. NOT tagging: a release tag means CI-verified green.'
            }
        }
        default {
            # 3 (CANT-VERIFY) and anything unrecognised. Exit 3 propagates rather than completing:
            # mapping "cannot observe CI" onto a successful exit is exactly the blindness B-88 exists
            # to remove, and callers consume exit status, not prose.
            return [pscustomobject]@{
                Status = 'UNVERIFIED'; Tag = $false; ReleaseExit = 3
                TagNote = ''
                Message = 'CI could not be verified for the release commit. NOT tagging: an unverifiable result is not a green one.'
            }
        }
    }
}
