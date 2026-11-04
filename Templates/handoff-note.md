---
type: Template
title: Session handoff note
description: What to leave behind when a task spans sessions or passes to someone else.
tags: [template, handoff, session]
timestamp: 2026-11-04
---

# Session handoff note

Save as `Output/Documents/Session_Handoff_<Topic>_<YYYY-MM-DD>.md` when a task is paused mid-flight
or passed to another person.

```markdown
# Handoff — <topic>, <date>

## Where this stands
<One paragraph: what is done, what is not.>

## Confirmed requirements
1. ...

## What exists already
- <path> — <what it does, and whether it has been run>

## Results so far
<Numbers the user pasted back, with the query that produced them.>

## Decisions taken
- <decision> — based on <file/rule>, or: no existing knowledge; decided by reasoning.

## Next step
<The literal next action, and anything it is blocked on.>

## Open questions
- <question, and who can answer it>
```

Keep results that the user pasted back — they are expensive to reproduce and the next session can't
re-run the query itself.
