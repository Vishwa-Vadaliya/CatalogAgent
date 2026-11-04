---
type: Document
title: Data Snapshot: Draft Retail Price by Flag Combination
description: Count of active draft retail price rows by flag combination (production status, seen, verified, private, last-seen date), with observations.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Snapshot date: not recorded (add the date the query was run)
Confidence: Medium (numbers are from the user's run; the observations are read from the table, reasons are not yet known)
Source query: Queries/Janvi/RetailPrice/RetailPrice_DistinctGroups_Simple.sql
---

# Data Snapshot: Draft Retail Price by Flag Combination

## In plain words

This is a count of what is in the draft retail price table today (`tbl_CAT_CatalogRetailPrice_d`, rows with `StatusID = 1` only). Every row is put into a group by five things: the watch's reference production status, whether the listing was seen in the last crawl, whether the price is verified (official site), whether it is private, and whether it has a "price last seen" date. For each group the table shows how many price rows, catalogs and catalog + country pairs it holds, and how many pairs have only one price versus a price history.

**Total: 374,838 active price rows.** (Catalog and pair counts cannot be added across groups, because the same catalog can appear in several groups.)

## How to read the columns

| Column | Meaning |
|---|---|
| `RefProductionStatus` | The catalog's production status: In Production, Out of Production, Phasing Out, or No status (not set) |
| `IsSeenInLastRun` | 1 = still listed at the last crawl |
| `IsVerified` | 1 = price from the manufacturer's official website |
| `IsPrivate` | 1 = private price stream, 0 = public |
| `HasPLS` | 1 = the row has a `PriceLastSeenDate` |
| `Rows` / `Catalogs` / `Pairs` | Price rows, distinct catalogs, distinct catalog + country pairs in the group |
| `PairsSingleRow` | Pairs with exactly one row in the group (a latest price only) |
| `PairsWithHistory` | Pairs with two or more rows in the group |

**Important:** single-row and history are counted **inside each group**. A pair whose rows fall into two groups (for example an older row with a last-seen date and a latest row without) can show as "single" in both. The true history per pair needs the whole-table count (`#PairOverall` in the query).

## The data

| RefProductionStatus | Seen | Verified | Private | HasPLS | Rows | Catalogs | Pairs | PairsSingleRow | PairsWithHistory |
|---|---|---|---|---|---|---|---|---|---|
| No status | 1 | 1 | 0 | 1 | 2 | 1 | 2 | 2 | 0 |
| No status | 1 | 1 | 0 | 0 | 73 | 67 | 73 | 73 | 0 |
| No status | 0 | 1 | 0 | 0 | 13 | 13 | 13 | 13 | 0 |
| No status | 1 | 0 | 0 | 1 | 1,755 | 1,456 | 1,456 | 1,209 | 247 |
| No status | 1 | 0 | 0 | 0 | 11,445 | 11,424 | 11,442 | 11,439 | 3 |
| No status | 0 | 0 | 0 | 0 | 29 | 29 | 29 | 29 | 0 |
| No status | 1 | 1 | 1 | 1 | 143 | 54 | 54 | 11 | 43 |
| No status | 1 | 1 | 1 | 0 | 82 | 82 | 82 | 82 | 0 |
| In Production | 1 | 1 | 0 | 1 | 101,966 | 8,037 | 48,767 | 14,226 | 34,541 |
| In Production | 1 | 1 | 0 | 0 | 73,472 | 10,396 | 73,472 | 73,472 | 0 |
| In Production | 0 | 1 | 0 | 1 | 9,024 | 1,830 | 4,408 | 2,410 | 1,998 |
| In Production | 1 | 0 | 0 | 1 | 7,660 | 2,971 | 2,971 | 953 | 2,018 |
| In Production | 1 | 0 | 0 | 0 | 5,995 | 5,959 | 5,959 | 5,923 | 36 |
| In Production | 1 | 1 | 1 | 1 | 749 | 240 | 256 | 91 | 165 |
| In Production | 1 | 1 | 1 | 0 | 880 | 270 | 880 | 880 | 0 |
| In Production | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| In Production | 0 | 1 | 1 | 0 | 2 | 2 | 2 | 2 | 0 |
| Out of Production | 0 | 1 | 0 | 1 | 85,991 | 9,748 | 46,623 | 29,365 | 17,258 |
| Out of Production | 1 | 0 | 0 | 1 | 30,770 | 12,784 | 12,784 | 5,812 | 6,972 |
| Out of Production | 1 | 0 | 0 | 0 | 19,373 | 19,371 | 19,371 | 19,369 | 2 |
| Out of Production | 1 | 1 | 1 | 1 | 8,094 | 2,776 | 2,821 | 1,418 | 1,403 |
| Out of Production | 1 | 1 | 1 | 0 | 16,144 | 2,769 | 16,144 | 16,144 | 0 |
| Phasing Out | 1 | 0 | 0 | 1 | 7 | 6 | 6 | 5 | 1 |
| Phasing Out | 1 | 0 | 0 | 0 | 16 | 16 | 16 | 16 | 0 |
| Phasing Out | 1 | 1 | 1 | 1 | 96 | 96 | 96 | 96 | 0 |
| Phasing Out | 1 | 1 | 1 | 0 | 1,056 | 96 | 1,056 | 1,056 | 0 |

## Rows by production status

| Production status | Rows |
|---|---|
| In Production | 199,749 |
| Out of Production | 160,372 |
| No status | 13,542 |
| Phasing Out | 1,175 |
| **Total** | **374,838** |

## What stands out (observations only, reasons to be added)

| # | Observation | Numbers | Reason |
|---|---|---|---|
| 1 | **Out of Production catalogs have no public verified row with Seen = 1.** All their public verified rows are Seen = 0, and all of those have a last-seen date. | 85,991 rows, 9,748 catalogs | |
| 2 | **In Production public verified rows are mostly Seen = 1 (175,438 rows) and some Seen = 0 (9,024 rows, all with a last-seen date).** | Seen = 0: 1,830 catalogs, 4,408 pairs | |
| 3 | **The biggest group is In Production, public, verified, Seen = 1, with NO last-seen date.** Every pair in it has a single row. | 73,472 rows, 10,396 catalogs | |
| 4 | **History lives almost only in rows that have a last-seen date.** Pairs with history in groups without a last-seen date total 41; with a last-seen date, 64,646. (Counted inside each group, see the note above.) | 41 vs 64,646 pairs | |
| 5 | **Unverified public rows are almost all Seen = 1**, whatever the production status. Only 29 "No status" rows are Seen = 0. This includes Out of Production catalogs. | Out of Production unverified: 50,143 rows, all Seen = 1 | |
| 6 | **Most unverified public rows have no last-seen date and a single row** (No status 11,445; In Production 5,995; Out of Production 19,373). | 36,813 rows | |
| 7 | **Private rows are almost all Seen = 1.** Only 3 private rows are Seen = 0, both in In Production. Private rows without a last-seen date are all single-row pairs. | 16,144 Out of Production; 1,056 Phasing Out; 880 In Production; 82 No status | |
| 8 | **Phasing Out has no public verified row at all.** It has 23 public unverified rows and 1,152 private rows. | 1,175 rows | |
| 9 | **"No status" catalogs are mostly unverified.** Only 88 of their 13,542 rows are public verified. | 88 rows | |
| 10 | **Some groups have more pairs than catalogs**, meaning one catalog has prices in several countries. Largest: In Production, public verified, Seen = 1, with last-seen date. | 8,037 catalogs, 48,767 pairs | |

## Questions to settle (for the next team)

1. Should In Production catalogs have any public verified row with Seen = 0 (observation 2)? Are these latest rows or older history rows? This table counts every active row, so a latest-only check is needed.
2. Why do the 73,472 public verified Seen = 1 rows have no last-seen date (observation 3)?
3. Are Out of Production catalogs with Seen = 1 unverified rows (observation 5) expected?
4. Should "No status" catalogs get a production status?

## Not covered by this snapshot

- Pending (`StatusID` 2) and deleted (`StatusID` 3) rows.
- Which row is the latest and which are older history (needs the latest-only version).
- Currency, country, manufacturer and source.
