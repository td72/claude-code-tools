---
description: Send a follow-up message to an already-spawned worker Claude through its WezTerm pane.
disable-model-invocation: true
---

# /worker:tell

Send a message to an existing worker. The user invoked this skill with: `$ARGUMENTS`

Parse `$ARGUMENTS` as: the first whitespace-separated token is the branch name, and the rest is the message.

Then run:

```bash
wt-worker tell "<branch>" "<message>"
```

The command produces no output on success. After it returns, briefly confirm to the user which worker received the message.
