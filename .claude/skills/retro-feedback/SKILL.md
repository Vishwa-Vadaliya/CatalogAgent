---
name: retro-feedback
description: Review the Feedback/session-corrections-log.md for recurring mistake patterns and propose permanent fixes (new rules in Rules/ or facts in Knowledge/). Use when asked to "run a retro", "review the feedback log", "do a corrections retro", or periodically to turn one-off corrections into standing rules.
tags: [skills, retro, feedback, rules, knowledge]
timestamp: 2026-10-24
---

# Retro Feedback

Turns the append-only corrections log into permanent improvements, so mistakes
caught once don't need to be caught again in every future session.

This skill is project-level (lives in this repo's `.claude/skills/`), so it
works the same way for everyone who clones `CatalogBrain` — no per-person
install needed.

## When to run this

- The user asks to "run a retro", "review the feedback log", "do a corrections
  retro", or similar.
- Periodically (e.g. weekly, or every handful of sessions) as general
  maintenance, if the user asks for that cadence.

## Steps

1. **Read the log.** Open [Feedback/session-corrections-log.md](../../../Feedback/session-corrections-log.md) in full.

2. **Group entries by theme.** Don't treat each entry in isolation — look for
   patterns across entries, e.g.:
   - The same missing filter/condition showing up on different tables or
     queries (signals a convention that should be a default, not a
     case-by-case fix).
   - The same kind of SQL mistake (syntax, join logic, windowing) recurring.
   - The same "design redirect" being suggested more than once (signals a
     preferred pattern that should be written down, not re-explained).

3. **Classify each theme:**
   - **Actual mistakes** that recur → candidate for a new rule in
     [Rules/00-core.md](../../../Rules/00-core.md) (how to work) or [Rules/10-sql-style.md](../../../Rules/10-sql-style.md) (SQL style) or
     a fact in the matching [Knowledge/](../../../Knowledge/index.md) topic file (if it's about what a table/id
     means or a condition that should always apply).
   - **Design redirects** that recur → candidate for a documented pattern,
     either as a rule (if it's a hard preference) or a note in `Documents/`
     (if it's more of a guideline/example).
   - **One-off, non-recurring items** → leave as-is in the log; don't
     over-generalize a single occurrence into a standing rule.

4. **Propose changes, don't just make them.** Present the grouped findings and
   the specific rule/knowledge wording you'd add, file by file. Wait for the
   user's go-ahead before editing `Rules/` or
   `Knowledge/` — these are shared, always-applied files
   used by all three people, so changes should be confirmed, not silent.

5. **Mark promoted entries.** Once the user approves a rule/knowledge update
   for a given log entry (or group of entries), add a short `-> Promoted to
   Rules/00-core.md (section X)` note next to that entry in
   `Feedback/session-corrections-log.md`, so the log doesn't need to be
   re-reviewed for the same item next time. Don't delete the original entry —
   it's still useful history of what the mistake was and how it was caught.

6. **Keep scope tight.** This skill only reads/writes within
   `Feedback/`, `Rules/`, `Knowledge/`, and optionally `Documents/`. It never
   touches `Queries/`, `Plans/`, or the `ew-db` database repo.
