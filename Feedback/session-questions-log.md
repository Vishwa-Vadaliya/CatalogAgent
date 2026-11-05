---
type: Feedback Log
title: Session Questions Log
description: Append-only chronological log of non-trivial questions Claude asked the user — split into avoidable (the answer was already findable) and necessary (real ambiguity or missing knowledge) — so recurring avoidable asks can be turned into rules/knowledge via /retro-feedback.
tags: [feedback, questions, log, retro]
timestamp: 2026-11-05
---

# Session Questions Log

Every time Claude asks a non-trivial question (via AskUserQuestion, or a written "which do you
want?" in chat), an entry goes here **without being asked** — what was asked, why, and whether it
was avoidable. Trivial one-line disambiguations covered by A0's "skip for a trivial ask" don't need
an entry; this is for questions that stopped real work.

## How to classify

- **Avoidable** — the answer was already sitting in `Rules/`, `Knowledge/`, `Documents/`, the schema,
  or earlier in the conversation, and Claude should have found it instead of asking. These are the
  ones worth turning into a rule/fact via `/retro-feedback` (e.g. "always check X before asking about
  X").
- **Necessary** — genuine ambiguity, a decision only the user can make, or a fact that doesn't exist
  anywhere in the library yet (so there was nothing to look up). Logged for visibility, not
  necessarily actionable — though a recurring "necessary" question about the same topic may mean a
  new Knowledge/ fact should be captured once the answer is known, so it's necessary only once.

## Entries

1. **Session 2026-11-05 — Rolex nickname task: which level and playbook?**
   Asked: "This doesn't match an existing playbook row... catalog side (EWMaster) or watch side
   (EveryWatch)?" Reason: `Playbooks/ROUTER.md` has no row for nickname-assignment work, and
   `tbl_CAT_Catalog_d.NicknameId` / `tblWatch_d.NickNameId` both exist, pointing at two different
   databases with no existing convention saying which one "add nicknames to the catalog" means.
   **Necessary** — no knowledge gap on my part to fix; the gap is that nickname work has no playbook
   row at all. Worth adding a `nickname` row to `ROUTER.md` once this task settles on a repeatable
   shape, so the next nickname task doesn't re-ask this.
   -> Promoted: `nickname` row added to `ROUTER.md`, pointing at `Knowledge/workflows/nickname-assignment.md`.

2. **Session 2026-11-05 — Rolex nickname task: where does the mapping come from?**
   Asked whether a reference->nickname mapping sheet already existed. Reason: searched
   `Knowledge/`, `Documents/Brands/`, and `Data/Sheets.md` for "nickname" and found only the schema
   (`tbl_CAT_Nickname(_d)`, `tblNickName`), no existing list of which Rolex references carry which
   collector nickname. **Necessary** — this fact genuinely doesn't exist yet in the library; it has
   to be researched once, and the decision (reference-number-only vs. dial-text-assisted matching)
   is a design call the user confirmed.
   -> Promoted: `Knowledge/workflows/nickname-assignment.md` (section 1) now names `Data/data.py`'s
   `nicknameArray` as the first place to check, so this doesn't need re-discovering next time.

## See also

[session-corrections-log.md](session-corrections-log.md) — the corrections log (what Claude did
wrong, not what it asked). `retro-feedback` reviews both.
