---
type: Data Index
title: Knowledge index
description: Lookup entry point for the EveryWatch data facts — keyword to topic file, plus a by-database view.
tags: [index, knowledge, lookup]
timestamp: 2026-11-04
---

# Knowledge — index

Facts about the data. **How to work** is in [../Rules/00-core.md](../Rules/00-core.md); **how to
write SQL** is in [../Rules/10-sql-style.md](../Rules/10-sql-style.md); deep background is in
[../Documents/](../Documents/index.md).

Open the one file the keyword points at — not the whole folder.

## Find a fact by what you're working on

| If the task mentions… | Open |
|---|---|
| which database, EWMaster vs EveryWatch, mirror, a brand's manufacturer id, cross-DB ids | [databases.md](databases.md) |
| draft vs publish, `tblWatch`/`tblWatch_d`, watch count, `IsDeleted`, assigned vs raw ref, lot status | [watches.md](watches.md) |
| reference numbers, models, synonym, merge, parent/child, PartialReference, Rolex leading 'm', clean name, ref structure | [references-and-models.md](references-and-models.md) |
| retail price, MSRP, `PriceLastSeenDate`, `IsSeenInLastRun`, private vs public price, outliers, production status, the daily price jobs | [retail-price.md](retail-price.md) |
| enrichment, ENR, multiple match, enrichment type ids, image similarity, dial-colour variations | [enrichment.md](enrichment.md) |
| "what does `sp_…` do", which procedure to call, the functions | [stored-procedures.md](stored-procedures.md) |
| images, media, primary image, `Preview960`, raw media | [images.md](images.md) |
| where a table's DDL lives, the schema check before writing a query | [ew-db-repo.md](ew-db-repo.md) |
| the four data layers, `MA_Id` writeback, synonym resolution, lot-status lifecycle, live-vs-scratch naming | [conventions.md](conventions.md) |
| reviewing a brand's image match (type 5) and multiple-ENR (type 1) | [workflows/image-match-review.md](workflows/image-match-review.md) |
| logging a catalog rename / delete / merge, catalog traceback, the change log | [workflows/catalog-traceback.md](workflows/catalog-traceback.md) |

## By database

| Database | Files |
|---|---|
| **EveryWatch** (app DB) | [watches.md](watches.md), [enrichment.md](enrichment.md) |
| **EWMaster** (catalog DB) | [retail-price.md](retail-price.md) *(syncs into EveryWatch)* |
| **Both** | [databases.md](databases.md), [references-and-models.md](references-and-models.md), [stored-procedures.md](stored-procedures.md), [images.md](images.md), [conventions.md](conventions.md) |
| **Repo, not a database** | [ew-db-repo.md](ew-db-repo.md) |

Many topics genuinely span both databases — that is why the split is by topic, not by database.
`references-and-models.md` and `images.md` each describe the catalog side and the watch side
together, and that contrast is the point.

## House rules for this folder

- Always confirm columns against `D:\EW\ew-db` before using them. Items marked **(?)** are
  unconfirmed — ask before relying on them.
- When two sessions disagree, the **newest** rule wins; the older one is noted.
- Each fact is written **once**, in one file. Add a new fact to the topic file it belongs to.
- Keep a file under about 150 lines. Past that, split by **sub-topic** — never by length alone.
- Frontmatter carries `db:` and `keywords:`; this index is built from them, so update both together.

Recurring corrections are promoted into these files from
[../Feedback/session-corrections-log.md](../Feedback/session-corrections-log.md) via the
`retro-feedback` skill — never without the user's go-ahead.

## History

[../Archive/EW_Knowledge.md](../Archive/EW_Knowledge.md) is the original, superseded version of the
knowledge base, kept for history only.
