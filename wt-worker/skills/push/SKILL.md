---
description: Host-side push of a worker's branch — the human-gated path for branches that change .github/workflows, which the worker's scoped GitHub App token cannot push by design. Previews the diff, then pushes (the push prompts for permission).
disable-model-invocation: true
---

# /wt-worker:push

Push a worker's branch to `origin` **from the host (commander) side**. The user
invoked this skill with: `$ARGUMENTS` (expected to be a single branch name).

## When to use this

Workers push over the sbx proxy using a **scoped GitHub App token** that has
`repo` (contents) permission but **not** `workflows`. GitHub rejects any
App-token push that touches `.github/workflows/*`:

```
! [remote rejected] ... (refusing to allow a GitHub App to create or update
  workflow `.github/workflows/build.yml` without `workflows` permission)
```

This is intentional — a workflow file is CI arbitrary-code-execution + secrets
access, so we don't grant a semi-autonomous worker the `workflows` scope. When a
worker hits this it **stops and reports** that a host-side push is needed. This
skill performs that push over the host's own transport (SSH), which is not
subject to the App-token restriction. It also works as a generic fallback for
ordinary branches when the worker's scoped token can't push (e.g. expired).

## How to run it (two commands, by privilege)

The push is split into a **read-only preview** and the **actual push**, so the
human gate lives at the permission layer rather than in a flag the agent could
pass itself.

**Step 1 — preview (read-only, auto-allowed).** Fetch the worker's commits and
show the changed files + workflow diff, without pushing:

```bash
wt-worker preview-push "<branch>"
```

Present the changed-file list — **especially any `.github/workflows/*` diff** —
to the user and get their explicit approval before continuing.

**Step 2 — push (privileged, prompts for permission).** Only after the user
approves, run:

```bash
wt-worker push "<branch>"
```

`wt-worker push` is configured in this repo's `.claude/settings.json` to require
a permission prompt (the `ask` tier), so the human approves the actual push at
the harness prompt. That prompt **is** the gate — do not try to bypass it.
Report the result (pushed / rejected) back to the user.

## Prerequisites

- The worker's `sbx run` session is **still live** — the `sandbox-<name>` git
  remote this fetches from only exists while the session runs. Push before
  cleanup, or the commits are out of the host's reach.
- The worker has **committed** on `<branch>`.
- The host's `origin` is reachable over SSH (the case this is built for; an
  https origin only pushes workflow files if the host's git credentials are
  allowed to update workflows — a classic PAT's `workflow` scope / an OAuth
  token's `workflow` scope, which is distinct from the GitHub App's `workflows`
  permission named above).
