---
type: Playbook
title: Output contract
description: The fixed shape every finished task takes, and where each kind of file goes.
tags: [playbook, output, deliverable, contract]
timestamp: 2026-11-04
---

# Output contract

Every task ends with the same pack, in this order. Skip a section only when it genuinely does not
apply, and say so rather than leaving it silently out.

## 1. Requirements

The numbered list from A0, as the user confirmed it. If it changed mid-task, show the current version.

## 2. Deliverable files

| What | Where |
|---|---|
| `.sql` query or script | `Output/Queries/<Person>/<Brand or Subfolder>/<Name>.sql` |
| A written guide, note or analysis | `Output/Documents/` |
| A data export (`.csv`) | `Output/Data/` |
| A finished report or write-up | `Output/Reports/` |
| A plan | `Output/Plans/<owner>/` |

- `<Person>` comes from `git config user.name` — `Ravi`, `Vishva` or `Janvi`.
- Queries follow [../Rules/10-sql-style.md](../Rules/10-sql-style.md): temp tables not CTEs, no
  `DECLARE` variables, NOLOCK after the alias, a header on the file and on every step.
- **No publish call** in a handed-off script (A9).
- Short queries (3–4 lines) stay in the chat reply — no file (A3).
- `Output/Queries/` holds only `.sql`. Documents and CSVs go in their own folders.

## 3. How to run it

State plainly what the user has to do:

- which steps to run, and in what order;
- that each step fills a `#temp` table and they inspect it with `SELECT * FROM #Step`;
- what results to paste back, if the next step depends on them;
- **the B6 caveat** when `@NewTransactionID` is used: the capture line and every step reading the
  variable must be selected and run together as one execution (no `GO` between them).

## 4. Jira comment draft

When the task came from a ticket, write the comment the user can paste — what was done, what is
attached, and what is needed from whom. **Draft only. Never post it.**

## 5. Decision log

One line per non-trivial decision:

```
Decision: <what was decided> — based on [Knowledge/retail-price.md, "PriceLastSeenDate"].
Decision: <what was decided> — no existing knowledge for this; decided by reasoning.
```

No retelling of the conversation. Skip entirely if nothing involved a judgment call.

## 6. Open questions / next step

What is still unresolved and what happens next. If a decision needs the user's sign-off before the
work can continue, say that here rather than assuming.

## Before you finish

- A correction happened this session → append it to `Feedback/session-corrections-log.md`, numbered,
  continuing the last entry. Without being asked. Never promote it into `Rules/` or `Knowledge/`
  without the user's go-ahead (`/retro-feedback`).
- A new durable fact came out of the work → add it to the matching `Knowledge/` topic file, and say
  that you did.
- Edited an existing file → show the changed lines (A8).
