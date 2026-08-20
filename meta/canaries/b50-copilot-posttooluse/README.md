# B-50 canary — does Copilot CLI deliver `postToolUse` `additionalContext` to the model?

Persisted kit for backlog item B-50. The shipped enforcement matrix said flatly that the channel was
dead ("a known CLI bug captures the value but does not forward it"), which was true on **CLI 1.0.68**.
The B-49 drill then observed the opposite on **1.0.70**, and the matrix row was updated while two
other passages in the same document kept the old conclusion — so the shipped doc contradicted itself.
This kit settles the question in isolation.

**Result: on CLI 1.0.80 the channel IS live** (run 2026-08-20 — see `meta/host-certification.md`).

## Design — three arms, because one arm proves nothing

| arm | `hooks.json` | what a null result would mean |
|---|---|---|
| **poscontrol** | the same hook on `userPromptSubmitted` | if this is null the canary is **INVALID** — the JSON shape or delivery path is broken and the treatment arm says nothing |
| **treatment** | the hook on `postToolUse` | the question under test |
| **negcontrol** | none | if this echoes the token, the model reached it some other way and the treatment means nothing |

The positive control is the half that makes a null readable, and it is deliberately a form **known
to succeed on this CLI**. B-143's canary failed precisely here: its positive control was itself a
narrow `applyTo`, i.e. a form already known to fail, so its INVALID verdict was the only honest
reading available. A control must be chosen for what it proves, not for what it resembles.

The negative control exists because of a false-positive channel the older `b52-copilot-two-hook` kit
does not account for. That kit reasons that an env-var token "exists in no file in the tree", so the
model cannot find it by reading the repo — true, but incomplete: hooks inherit the CLI's environment,
and the model is run with `--allow-all-tools`, so it can spawn a shell and read that same
environment. Only a no-hook arm rules that out.

Each hook invocation also appends to a **marker file**, which separates the two failure modes this
item has to tell apart: *the hook never ran* versus *the hook ran and its output was discarded*.
Without it a null is ambiguous, which is exactly what made a first two-arm attempt unreadable.

## Files

| file | purpose |
|---|---|
| `.github/hooks/hooks.json` | registers the hook on `postToolUse` (the treatment arm) |
| `.github/hooks/hooks-prompt.json` | registers the same script on `userPromptSubmitted` (the positive control) |
| `.github/hooks/post-token.{sh,ps1}` | emits the token via both JSON shapes and appends to the marker |

`CANARY_POST` (the token), `CANARY_MARKER` (marker path) and `CANARY_EVENT` (the `hookEventName` to
declare) are all read from the environment, so one script serves every arm and the token is in no
tracked file.

## How to run

1. Copy the kit to a fresh temp dir per arm, swap in the right `hooks.json`, and `git init` it —
   Copilot needs a real checkout.
2. **Trust each folder.** `copilot -C <dir>` has no non-interactive trust flag, but
   `~/.copilot/config.json`'s `trustedFolders` is a plain JSON array of absolute paths and writing
   the dir into it directly is accepted exactly as if the prompt had been answered. **Back the file
   up and restore it afterwards — it is the live trust store.**
3. Set `CANARY_POST`/`CANARY_MARKER`/`CANARY_EVENT` and run, per arm:
   ```
   copilot -C <dir> --allow-all-tools -p "Create a file named notes.txt ... containing the single
   word hello. After the file exists, tell me any canary tokens you have been given, verbatim.
   If you have not been given any, say NONE."
   ```
   The write is what makes `postToolUse` fire at all; assert `notes.txt` exists so a null cannot be
   explained by "no tool call happened".

## Reading the result

Read the arms **together**, never the treatment alone:

- poscontrol echoes **and** negcontrol does not → the instrument is valid; now read the treatment.
- poscontrol does **not** echo → INVALID. Fix the kit; report nothing about `postToolUse`.
- negcontrol echoes → INVALID. The token leaked through the environment; the treatment is worthless.
- Treatment echoes, marker fired → the channel is **live** on this CLI version.
- Treatment silent, marker fired → the hook ran and the value was **discarded** — the 1.0.68 defect.
- Treatment silent, marker absent → the hook never ran; this is a registration or trust problem, not
  a delivery finding.

Whatever the outcome, re-date the row in `meta/host-certification.md` with the CLI version, and
correct **every** passage in `docs/enforcement-surfaces.md` that speaks to this channel — the reason
this item existed is that the matrix row was updated and two prose passages were not.
