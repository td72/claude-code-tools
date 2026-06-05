---
description: Stop a worker's Docker sandbox, kill its WezTerm pane, drop the sandbox-<name> git remote, and stop its token refresher.
---

# /wt-worker:cleanup

Clean up a worker. The user invoked this skill with: `$ARGUMENTS` (expected to be a single branch name).

Run:

```bash
wt-worker cleanup "<branch>"
```

This stops the background GitHub-token refresher, removes the sandbox
(`sbx rm --force`), drops the `sandbox-<name>` git remote, and kills the WezTerm
pane. Under `--clone` there is no host-side worktree or local branch to remove
(the work lived in the in-container clone); the worker's pushed branch stays on
GitHub.

## Re-testing / iteration hygiene

When iterating on a worker — re-running a task, or recovering from a worker that
got into a bad state (e.g. the REPL shows "Not logged in") — **clean up the
existing pane before spawning again.** `spawn` never reuses or replaces a live
worker; leaving obsolete or broken panes around just clutters the window and
wastes a sandbox. The pane is going to be discarded anyway, so cleanup first,
then re-spawn.
