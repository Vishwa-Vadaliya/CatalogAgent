---
type: Data Index
title: Skills index
description: The skills available in this agent — they live in .claude/skills/.
tags: [index, skills]
timestamp: 2026-11-04
---

# Skills — index

The skills themselves live in `.claude/skills/<name>/SKILL.md`, so they're picked up automatically.
Only a skill's description sits in context until it's invoked.

- **`/brand-ref-agent <Brand>`** — build the maximum set of unique, correct, full watch reference
  numbers for a brand from the `RawRefsToAssign` sheet: research the brand's numbering, decide which
  structures to keep, validate, flag partial/duplicate/invalid refs, add variations and best images,
  fill dial and case, check against master values, and generate catalog INSERTs. Resume with
  `/brand-ref-agent <Brand> from step 4`.
- **`/image-match-review <Brand>`** — review the manufacturer-wide image match (type 5) and the
  multiple-ENR image similarity (type 1) for one brand: the setup questions, the five SQL queries to
  hand over, the Google Sheet from the template, and the final summary.
- **`/retro-feedback`** — review `Feedback/session-corrections-log.md` for recurring mistake patterns
  and propose permanent fixes as new rules in `Rules/` or facts in `Knowledge/`. Nothing is promoted
  without the user's go-ahead.

Playbooks in [../Playbooks/index.md](../Playbooks/index.md) get promoted to skills once they've
proven out. Subagents will live in `.claude/agents/`, which is empty for now.
