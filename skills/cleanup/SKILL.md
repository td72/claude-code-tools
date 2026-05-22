---
description: Stop a worker's Docker container and kill its WezTerm pane. The worktree is intentionally left in place for review.
disable-model-invocation: true
---

# /ccwt:cleanup

Clean up a worker. The user invoked this skill with: `$ARGUMENTS` (expected to be a single branch name).

Run:

```bash
ccwt cleanup "<branch>"
```

The worktree is intentionally not removed. After cleanup, remind the user that `gwq remove <branch>` is the next step if they're done with that branch.
