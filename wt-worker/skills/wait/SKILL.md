---
description: Poll a worker Claude's pane until a turn completes (✻ Worked for … appears), then exit 0.
disable-model-invocation: true
---

# /worker:wait

Wait for a worker to finish its current task. The user invoked this skill with: `$ARGUMENTS`

Parse `$ARGUMENTS` as: the first token is the branch name; an optional `-t <seconds>` sets a hard timeout; an optional `-i <seconds>` overrides the poll interval (default 10 s, or `WT_WORKER_WAIT_INTERVAL`).

Run:

```bash
wt-worker wait "<branch>" [-t <timeout>] [-i <interval>]
```

Exit codes:
- **0** — a new `✻ Worked for …` line appeared since `wait` was invoked (one Claude turn finished).
- **1** — timed out (`-t`) before a completion signal was seen.

When the command returns, report whether the worker finished or timed out, then suggest the next step:
- On success: `/worker:logs <branch>` to see the output, or `/worker:tell <branch>` to give follow-up instructions.
- On timeout: advise increasing `-t` or running `/worker:logs` to check the worker's current state.
