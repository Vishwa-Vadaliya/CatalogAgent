---
type: Data Index
title: Feedback index
description: The corrections log — what Claude got wrong, what the user said, and the right way.
tags: [index, feedback, corrections]
timestamp: 2026-11-04
---

# Feedback — index

- [session-corrections-log.md](session-corrections-log.md) — the append-only corrections log, carried
  over from the original repo with its numbering intact.

## How it works

- Every time Claude does something wrong and the user redirects it, an entry is appended **without
  being asked**: what Claude did wrong, what the user said (quoted), and the right way to do it.
  Numbered, continuing the last entry.
- **Corrections only** — not a log of everything that was done.
- Nothing here is promoted into [../Rules/](../Rules/index.md) or
  [../Knowledge/](../Knowledge/index.md) without the user's explicit go-ahead. That is what
  `/retro-feedback` is for.
- Never save query files here.

A `Stop` hook flags uncommitted new entries at the end of a session and suggests running
`/retro-feedback`.
