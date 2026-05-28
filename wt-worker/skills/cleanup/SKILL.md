---
description: Stop a worker's Docker sandbox, kill its WezTerm pane, remove its git worktree and branch, and stop its token refresher.
disable-model-invocation: true
---

# /wt-worker:cleanup

Clean up a worker. The user invoked this skill with: `$ARGUMENTS` (expected to be a single branch name).

Run:

```bash
wt-worker cleanup "<branch>"
```

This stops the background GitHub-token refresher, removes the sandbox
(`sbx rm --force`), removes the `.sbx/` worktree and its branch, and kills the
WezTerm pane.

## Re-testing / iteration hygiene

When iterating on a worker — re-running a task, or recovering from a worker that
got into a bad state (e.g. the REPL shows "Not logged in") — **clean up the
existing pane before spawning again.** `spawn` never reuses or replaces a live
worker; leaving obsolete or broken panes around just clutters the window and
wastes a sandbox. The pane is going to be discarded anyway, so cleanup first,
then re-spawn.
