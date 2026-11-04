---
type: Document
title: Retail Price Cases by Flag Combination (Technical)
description: Technical version of the retail price cases: flag columns, the stated flag rules, date data-quality points and questions. No counts.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Audience: Engineers / data
Confidence: Medium (cases from the team's run of RetailPrice_DistinctGroups_LatestOnly.sql; reasons as stated by the team; some points marked "to confirm"; counts deliberately left out for now)
Source query: Queries/Janvi/RetailPrice/RetailPrice_DistinctGroups_LatestOnly.sql
Related: 05-data-snapshot-flag-groups.md (all rows, with counts), 06-cases-management-non-technical.md, 08-cases-combined.md
---

# Retail Price Cases by Flag Combination (Technical)

## Scope and definitions

- Table: `tbl_CAT_CatalogRetailPrice_d`, rows with `StatusID = 1`.
- **Pair** = (`CatalogID`, `CountryId`). **Latest row** = the pair's row with the highest `CreatedAt` (ties: highest `CatalogRetailPriceID`).
- The cases below describe the **latest row of each pair**. "Single" = the pair has exactly one active row in total; "History" = the pair has two or more.
- Production status: `tbl_CAT_Catalog_d.RefProductionStatusID` -> `tbl_CAT_Reference_ProductionStatus_d`.
- `HasPLS` = `PriceLastSeenDate IS NOT NULL`. `PriceLastSeenDate` = the last day we know the watch was on the website or had the price.
- Public verified = `IsPrivate = 0` and `IsVerified = 1`. Private prices are always `IsVerified = 1`.
- The counts (Pairs, Catalogs, Single, History) are in the query output and are not repeated here.

## Rules the team states for the flags

| Flag | Rule as stated | Where it shows in the data |
|---|---|---|
| `IsSeenInLastRun` (verified, public) | Set per country. 1 when that country's listing is on the site, 0 when it is gone. `IsSeenInLastRun = 0` always has a `PriceLastSeenDate`. | In Production Seen=0 with a date; Out of Production Seen=0 with a date. |
| `IsSeenInLastRun` (non-verified) | Always set to 1. | Almost all non-verified groups are Seen=1. |
| Visibility of non-verified public prices | Shown publicly only if verified prices are not available. | Applies to all public non-verified groups. |
| `IsVerified`, `IsSeenInLastRun` (private) | Always set to 1 and 1. | All private groups are Verified=1, Seen=1. |
| Reference production status | Set to In Production when at least one country or source still lists the reference. | In Production with Seen=0 for countries without a price. |
| `PriceLastSeenDate` on history | An older row's date = the `CreatedAt` of the next price. The latest row often has none (no date known, or the reference is in production and listed). | In Production, public verified, Seen=1, no date: many pairs have history. |

## Cases (latest rows)

Pri = `IsPrivate`, Seen = `IsSeenInLastRun`, Ver = `IsVerified`, PLS = has `PriceLastSeenDate`.

### No status

| Pri | Seen | Ver | PLS | Reason (team) |
|---|---|---|---|---|
| 0 | 1 | 1 | 1 | See "Why status is missing" below (applies to No status verified; to confirm for the next two rows). |
| 0 | 1 | 1 | 0 | See below. |
| 0 | 0 | 1 | 0 | See below. Seen=0 with no date: exception to the stated rule, to confirm. |
| 0 | 1 | 0 | 1 | `PriceLastSeenDate` filled from the reference's discontinued date. |
| 0 | 1 | 0 | 0 | No discontinued date known for the reference. |
| 1 | 1 | 1 | 0 | Private. Reason as for the other private groups. |

**Why status is missing.** Many brands have no crawled data from the manufacturer's site, yet we hold verified or non-verified prices for them. Verified public prices may be added by an external person, and then the production status is not known. Non-verified prices come from other sources, also without a status. Two brands (Richard Mille and F.P. Journe) have non-verified prices only: one reference has many variations and we do not know which are in or out of production.

### In Production

| Pri | Seen | Ver | PLS | Reason (team) |
|---|---|---|---|---|
| 0 | 1 | 1 | 1 | Reference was seen on the site, price removed now, so it has a last-seen date. Note: Seen=1 with a date does not match that reason, to confirm. |
| 0 | 1 | 1 | 0 | In production and on the site: no date. History rows carry the older dates. |
| 0 | 0 | 1 | 1 | Several countries. Reference is "in production" if at least one country or source lists it. Seen is per country, and Seen=0 always has a date. |
| 0 | 1 | 0 | 0 | Non-verified from other sources. Seen is always 1, no date. |
| 1 | 1 | 1 | 0 | Private. Verified=1, Seen=1 always, no date because in current production. |

### Out of Production

| Pri | Seen | Ver | PLS | Reason (team) |
|---|---|---|---|---|
| 0 | 0 | 1 | 1 | Not available on any source's site. Seen=0 and a date. |
| 0 | 1 | 0 | 1 | Not on the manufacturer's site; non-verified price kept with Seen=1, and a date. |
| 0 | 1 | 0 | 0 | Not from the manufacturer's site; no crawled data; Seen=1 always; no date. |
| 1 | 1 | 1 | 1 | Private. The date comes from crawling, found for very few catalogs. |
| 1 | 1 | 1 | 0 | Private. Reference not crawled at all, or no discontinued date. We have no discontinued date data for these, so the date cannot be filled today. |

### Phasing Out

| Pri | Seen | Ver | PLS | Reason (team) |
|---|---|---|---|---|
| 0 | 1 | 0 | 1 | Parmigiani only: status given by the manufacturer. Some prices have a date. |
| 0 | 1 | 0 | 0 | Same, no date. |
| 1 | 1 | 1 | 0 | Parmigiani private prices. Verified=1, Seen=1 always. |

## Dates: three data-quality points

### 1. Non-verified rows with `CreatedAt` later than `PriceLastSeenDate` (about 3,000 to 4,000 rows)

- For non-verified rows the date comes from `DiscontinuedDate` of the reference (in `tbl_CAT_Catalog_d`), and `DiscontinuedDate` can be earlier than `CreatedAt`.
- Reason: for non-manufacturer sources `CreatedAt` is the date **we collected** the price, which is later than the date the source first showed it.
- WatchBase had the same effect (collected later, price detected in an earlier year). **Fixed** by reading the website graph by hand and loading each price with its graph date.
- **Other sources were not fixed.** `CreatedAt` = collection date; `PriceLastSeenDate` = discontinued date.
- Note: `RetailPrice_DistinctGroups_LatestOnly.sql` step 6 currently selects the opposite direction (`PriceLastSeenDate > CreatedAt`). Switch the comparison to list these rows.

### 2. How the reference's discontinued date is chosen

- Sources: WatchBase and WatchCharts.
- If both have a date, compare them and **take the later one**.
- WatchCharts has many dates, but it shows **2026 dates for references that are in production**, so a WatchCharts-only date is less reliable.

### 3. History and `PriceLastSeenDate`

- Stated rule: an older price's `PriceLastSeenDate` equals the `CreatedAt` of the next price.
- The latest row often has no date: either no date is known, or the reference is in production and the price is on the site.
- To confirm: the daily update SP (see `sp/03`) does not itself write this date on older rows; where this rule is applied is to confirm (one-time fix, WatchBase load, or another job).

## Questions to settle

1. Group "In Production, public, Seen=1, verified, has date": is the date correct when Seen=1?
2. Group that breaks the stated rules: No status verified Seen=0 no date.
3. Private rows of Out of Production references without a date: we have no discontinued date data for them. Is there a source?
4. Which rows are the 3,000 to 4,000 `CreatedAt > PriceLastSeenDate` rows, and by which source (needs a `SourceId` / `TransactionId` split)?
