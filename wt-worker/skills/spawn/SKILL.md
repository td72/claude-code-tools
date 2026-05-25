---
description: Spawn a new worker Claude in a Docker sandbox bound to a fresh git worktree, opened as a new WezTerm pane below the commander.
disable-model-invocation: true
---

# /worker:spawn

Spawn a worker. The user invoked this skill with: `$ARGUMENTS`

Parse `$ARGUMENTS` as: the first whitespace-separated token is the branch name, and the rest (if any) is the initial task description.

Then run:

```bash
wt-worker spawn "<branch>" "<task>"
```

(If no task is given, omit the second argument.)

After it succeeds, report the worker's branch, pane-id, worktree path, and container name in one short paragraph.

If `worker init` has not been run in this session, the command will fail with a clear error — surface it to the user and suggest running `/worker:init` first.
