# Retired impact compatibility artifacts

This directory remains temporarily so a future framework update can safely recognise and remove
the paths it previously installed. It is not an executable impact harness.

The former pre/post experiment is invalid: its supposed pre-adoption reference was captured after
the framework had already been installed, so it cannot support a comparative or causal claim.
`scripts/impact-run.ps1` and `.sh` are inert, non-zero tombstones. They do not invoke agents,
tools, or worktrees.

`config.json` records this retired status. Stack-specific `tasks.json` files remain unchanged only
as compatibility data until the planned retirement update removes the full path set. For a useful
record today, `/impact` may compare archived configuration with installed capabilities and publish
a clearly labelled current repository scorecard; neither is an A/B result or proof that adoption
caused a later change.
