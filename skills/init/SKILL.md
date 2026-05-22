---
description: Register the current WezTerm pane as the commander for ccwt. Run once per session before spawning workers.
disable-model-invocation: true
---

# /ccwt:init

Register the current WezTerm pane as the ccwt commander so subsequent `spawn` calls split panes below it.

Run:

```bash
ccwt init
```

Report the recorded pane-id and state directory back to the user verbatim.
