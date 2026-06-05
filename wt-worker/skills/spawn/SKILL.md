---
description: Spawn a parallel worker Claude in a Docker sandbox (in-container clone) shown in a new WezTerm pane below the commander. Use this to delegate or parallelize a task to a worker (e.g. "wt-worker に投げて", "ワーカーに実装させて"). Do NOT substitute the built-in Agent/Task tool, and never claim wt-worker ran when it didn't.
---

# /wt-worker:spawn

Spawn a worker. The user invoked this skill with: `$ARGUMENTS`

**This is how delegation to a parallel worker happens.** The built-in Agent/Task
tool is **not** wt-worker — it opens no WezTerm pane and runs no Docker sandbox.
Never use it as a stand-in, and never report that wt-worker ran when something
else did. If wt-worker genuinely can't run (not inside WezTerm, or `wt-worker`
is not on PATH), say so and stop rather than quietly substituting another
mechanism.

Parse `$ARGUMENTS` as: the first whitespace-separated token is the branch name, and the rest (if any) is the initial task description.

Then run:

```bash
wt-worker spawn "<branch>" "<task>"
```

(If no task is given, omit the second argument.)

The worker runs on a private **in-container clone** — the host repo is mounted
read-only and there is no host-side worktree. It creates the branch itself and
pushes to GitHub directly. For `.github/workflows` changes its scoped token
can't push, see `/wt-worker:push`.

After it succeeds, report the worker's branch, pane-id, and sandbox name in one
short paragraph.

> Tip: for a long or detailed plan, spawn with a short task (or none), then send
> the full plan with `/wt-worker:tell <branch> <plan>` — it's easier to manage
> than cramming everything into the initial task.
