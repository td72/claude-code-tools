---
description: Read a worker Claude's pane output to observe its progress and assess whether it is done, stuck, or needs follow-up.
disable-model-invocation: true
---

# /worker:logs

Read the recent output of a worker's WezTerm pane. The user invoked this skill with: `$ARGUMENTS`

Parse `$ARGUMENTS` as: the first token is the branch name; an optional `-n <number>` that follows overrides the default line count (200).

Run:

```bash
wt-worker logs "<branch>" [-n <lines>]
```

Show the output verbatim, then briefly assess:
- Is the worker still running (claude prompt visible at bottom)?
- Does the output show a completed task, an error, or a question directed at the user?
- Is any follow-up needed — a `/worker:tell` with clarification, or is the worker done?
