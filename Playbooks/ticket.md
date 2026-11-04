---
type: Playbook
title: Jira ticket
description: Turn a Jira ticket into confirmed requirements and route it to the domain playbook that does the work.
tags: [playbook, jira, ticket, requirements]
timestamp: 2026-11-04
---

# Playbook — Jira ticket

This playbook does **not** do the work. It turns a ticket into a confirmed requirement list and hands
off to the domain playbook. Jira is **read-only** ([MCP.md](MCP.md)).

## Steps

1. **Fetch the ticket** — `getJiraIssue` with the key (e.g. `ECH-409`). Read the description, the
   acceptance criteria, the comments and the linked issues. Follow Confluence links the ticket names.
2. **Look for prior work in this repo before asking the user anything:**
   - `Output/Plans/` — is there already a plan for this ticket?
   - `Output/Queries/` — has someone written queries for this brand or problem before?
   - `Documents/` — is there a guide covering this area?
   - `Feedback/session-corrections-log.md` — has this kind of task gone wrong before?
3. **Restate the requirements** (A0) as a numbered list — what the ticket asks, in your words, short.
   Include anything the ticket leaves ambiguous as an explicit question. **Wait for confirmation.**
4. **Route** on what the ticket actually asks for, using [ROUTER.md](ROUTER.md), and follow that
   playbook. Say which one you picked.
5. **Close** with the output pack ([OUTPUT.md](OUTPUT.md)), including the Jira comment draft.

## What to watch for

- A ticket title rarely matches the real ask — route on the description and the acceptance criteria.
- If the ticket spans two domains (e.g. an enrichment fix that changes retail price), say so and
  agree the order with the user instead of silently doing both.
- If the ticket asks for something that would require running SQL or writing to Jira, say what you
  will hand over instead — don't ask for permission to break A1.
- A ticket that is really a question (not a change) still gets a requirement restatement, but the
  deliverable is an answer plus the queries that prove it, not a script.
