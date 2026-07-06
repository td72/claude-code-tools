---
description: Run a branch's test suite in a clean CI-parity linux container (native bindings, browsers), since the worker's dev sandbox can't run e2e against host-mounted node_modules.
---

# /wt-worker:verify

Verify a branch by running its test suite in a clean linux container. The user
invoked this skill with: `$ARGUMENTS` (expected to be a single branch name).

Run:

```bash
wt-worker verify "<branch>"
```

This exports the **committed** branch tree (via `git archive`, so no
host `node_modules` / `target`) into a fresh container, then runs the
`[verify].command` declared in `~/.config/wt-worker/config.toml`. The command's
exit code is the result: `0` = pass, non-zero = fail. Caches (pnpm store, cargo,
playwright browsers) persist across runs as per-repo named docker volumes.

After it finishes, report PASS/FAIL and surface the relevant failing output.

## Why this exists (don't run e2e inside the worker sandbox)

The worker sandbox direct-mounts the host worktree, so its `node_modules` holds
**host-OS (macOS) native binaries**. Tools with native bindings — vite-plus /
rolldown / oxc / esbuild — and Playwright's browser binaries can't load or run
in the linux container, so `vp build`, the e2e webServer, and the browsers all
fail there. `verify` sidesteps this by doing a clean install in a container that
matches CI, giving a local red/green **before** pushing instead of a blind
push-and-watch-CI loop.

## Prerequisites

- `docker` available on the host (the commander side).
- A `[verify]` section in `~/.config/wt-worker/config.toml` with at least
  `command`. Without it, `verify` exits 1 and prints an example. See
  `examples/config.toml`.
- `verify` tests the committed HEAD of the branch — commit first.
