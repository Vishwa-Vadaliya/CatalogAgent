---
type: Template
title: Decision log
description: The A0 closing — one line per non-trivial decision, citing the knowledge it came from.
tags: [template, a0, decision-log]
timestamp: 2026-11-04
---

# Decision log (A0)

Write this at the end of the task. One line per non-trivial decision. No retelling of the
conversation.

```
**Decision log**
- Decision: <what was decided> — based on [Knowledge/retail-price.md, "PriceLastSeenDate"].
- Decision: <what was decided> — based on [Rules/10-sql-style.md, B2].
- Decision: <what was decided> — no existing knowledge for this; decided by reasoning.
```

- Cite tightly: the file plus the rule or fact name, not just "the knowledge base".
- When nothing covered it, say so plainly rather than implying it came from somewhere.
- If a decision genuinely needed sign-off *before* being taken, ask at the time instead of logging
  it after the fact.
- Skip the log entirely when nothing in the task involved a judgment call.
