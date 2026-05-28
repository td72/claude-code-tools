---
description: Manually re-mint the scoped GitHub token for a running worker sandbox (useful when the background refresher has died or the token has expired).
disable-model-invocation: true
---

# /wt-worker:refresh

Manually refresh the GitHub token for a worker. The user invoked this skill with: `$ARGUMENTS` (expected to be a single branch name).

Run:

```bash
wt-worker refresh "<branch>"
```

This re-mints a scoped GitHub App installation token via `agent-gh-repo-token` and stores it as
the sandbox's `github` secret, extending the worker's push access for another hour.

## When to use

Under normal operation the background refresher (started automatically by `spawn`) re-mints the
token every 50 minutes — no manual action is needed. Use `/wt-worker:refresh` when:

- The refresher process died (e.g. the host machine was restarted) and the token has or will
  soon expire.
- The worker reports authentication errors (`403`, "could not read Username") when pushing.

## Error conditions to surface

- **"no recorded repo for `<branch>`"** — `spawn` was never run for this branch, or its state
  file was lost. There is no repo to mint a token for.
- **"sandbox `<name>` is gone"** — the sandbox has already been removed; cleanup is complete and
  no refresh is needed.
- **`agent-gh-repo-token` not on PATH** — the token minting CLI is not installed; `refresh` is a
  no-op. Direct the user to install it (see `wt-worker help`).
