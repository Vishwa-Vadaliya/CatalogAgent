---
type: Knowledge Fact
title: Nickname assignment methodology
description: How to assign collector nicknames to catalog references — image verification, the Data/data.py source, what counts as a nickname vs. not, and evidence labelling. Distilled from the Rolex nickname-assignment session.
tags: [knowledge, workflow, nickname, rolex, catalog, image-verification]
db: EWMaster
keywords: [nickname, NickName, tbl_CAT_Nickname, tblNickName, collector slang, image verification, Data/data.py, synonym]
timestamp: 2026-11-06
---

# Nickname assignment methodology

How to assign a collector nickname to a catalog reference correctly — not just plausibly.
Schema: `tbl_CAT_Nickname(_d)` (catalog) / `tblNickName` (app) — see [../databases.md](../databases.md)
for the sync relationship.

## 1. Check `Data/data.py` before researching from the web

The repo already carries a curated `nicknameArray` with reference → nickname entries (currently
Rolex). Check it first — it has caught real errors in web/model research before (a reference
mismatched to the wrong nickname, a nickname with no real source). A reference in this list is a
**base reference, never a prefix** — don't prefix-match it onto catalog refs. `1655` (Freccione)
must not capture `16550`, a different generation; a `/` suffix extends the same reference, but extra
digits make a different watch.

## 2. The catalog image is the last gate — not optional

Whenever a nickname depends on something visible (dial, bezel, bracelet), the catalog image has to be
checked before the row becomes assignable — a reference number or a web/source match alone is never
sufficient. This caught real cases: a bezel-dependent name wrongly spread across a whole reference, a
dial-dependent name needing a split, a bracelet-only variant, and a name that applied to only one of
several references sharing a base number. Download and review the image for every row that will be
assigned, not a sample.

## 3. When the image doesn't settle it, use the EveryWatch search index

`watchTitle` in the EveryWatch search index is searchable and shows exactly which references the
market actually attaches a given nickname to in listing titles — use it as the ground-truth
cross-check when a name can't be confirmed visually (e.g. a historical/rare nickname, or one that
isn't dial/bezel-visible).

## 4. What counts as a nickname (and what doesn't)

A nickname is **collector slang the market invented** — not a name the manufacturer gave the watch.
Before a term enters the nickname list, check which field it actually belongs to:

| Not a nickname | Where it belongs instead |
|---|---|
| Dial signature (e.g. a dial-text variant) | `DialStamp` / `tbl_CAT_DialStamp_d` |
| Official model name | `tblModel` |
| Material/finish trademark | A case attribute, not a nickname |
| A depth/spec designation | Not a nickname field at all |

A flagged doubt in prose ("arguably a model name") is not resolved until the term is actually moved
to the right field or dropped — don't leave it sitting in the nickname list with a caveat attached.

## 5. A synonym must be a genuinely distinct name

Only add a synonym when it's a name the market **also** uses for the same watch — not a spelling or
casing variant of the primary nickname, not an abbreviation/acronym of it, and not a description of
its dial or movement. Spelling/casing variants belong in matching/cleanup logic, not the nickname
list itself.

## 6. Every verdict needs a visible evidence level

A result column must say *what checked it*, not just what the answer is — image-confirmed,
index-confirmed, or not checked — and rows with no evidence must look visibly different from rows
that passed a check. Don't let an unverified row read as a confirmed one just because it carries a
`FinalNickname` value.

## See also

- [../../Feedback/session-corrections-log.md](../../Feedback/session-corrections-log.md) entries
  43, 45–49 — the original corrections this file was distilled from.
