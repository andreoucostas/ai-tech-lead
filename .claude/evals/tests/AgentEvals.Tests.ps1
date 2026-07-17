# No-network recurrence test for the B-41 live harness.
$ErrorActionPreference = 'Stop'
$runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'run-agent-evals.ps1'
& pwsh -NoProfile -File $runner -SelfTest
if ($LASTEXITCODE -ne 0) { throw "Agent eval self-test failed with exit $LASTEXITCODE" }

