---
type: Document
title: Retail Price Cases: Overview for a Mixed Audience
description: Mixed-audience overview of the retail price cases: switches, rules of thumb, cases table, date facts and open points.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Audience: Mixed (product, data, engineers)
Confidence: Medium (cases from the team's run; reasons as stated by the team; counts deliberately left out for now)
Related: 06-cases-management-non-technical.md (plain), 07-cases-technical.md (full tables), 05-data-snapshot-flag-groups.md (all rows, with counts)
---

# Retail Price Cases: Overview for a Mixed Audience

## In plain words

For every watch reference and country we keep a **latest price**, plus older prices when the price changed. Each latest price has a few switches that tell us where it came from and how current it is. This document lists every combination of switches we have today and why.

## The switches

| Switch | Values | Meaning |
|---|---|---|
| Production status | In Production, Out of Production, Phasing Out, No status | State of the watch reference. |
| `IsVerified` | 1 = manufacturer's site or manufacturer-given; 0 = other source | Where the price comes from. |
| `IsPrivate` | 1 = given by the manufacturer, hidden from the public; 0 = public | Who can see it. Public non-verified prices are shown only if verified prices are not available. |
| `IsSeenInLastRun` | 1 = the watch was still on the website at the last collection; 0 = gone | Is the price still on the source. |
| `PriceLastSeenDate` (HasPLS) | has a date / no date | Last day we know the watch was on the website or had the price. |

## Rules of thumb that explain most cases

1. **Public verified:** `IsSeenInLastRun` is set per country (1 listed, 0 gone). **Seen = 0 always has a last-seen date.**
2. **Non-verified:** `IsSeenInLastRun` is always 1. A last-seen date exists only if we know a discontinued date for the reference.
3. **Private:** always `IsVerified = 1` and `IsSeenInLastRun = 1`. A date exists only if crawling or a discontinued date gives one.
4. **In Production and listed:** no last-seen date on the latest price.
5. **History:** an older price's last-seen date is the next price's created date, so history rows have dates while the latest row often has none.

## Cases at a glance

| Production status | Case | Has date | Why (short) |
|---|---|---|---|
| In Production | Public verified, listed | No | On the site now. Many have older prices. |
| In Production | Public verified, listed, with date | Yes | Price was removed after being seen. Seen=1 here does not match, to confirm. |
| In Production | Public verified, not listed in some countries | Yes | Per-country flag: gone in one country, still in production elsewhere. |
| In Production | Public non-verified | No | Other source, always "listed", no date. |
| In Production | Private | No | Manufacturer-given, in production. |
| Out of Production | Public verified, not listed | Yes | Gone from all sites. |
| Out of Production | Public non-verified, with date | Yes | Date from discontinued date. |
| Out of Production | Public non-verified, no date | No | No discontinued date, no crawled data. |
| Out of Production | Private, with date | Yes | Date from crawling (rare). |
| Out of Production | Private, no date | No | Not crawled or no discontinued date, and no discontinued date data exists to fill it. |
| No status | Public verified | Mostly no | No crawled data for the brand, or added by an external person. |
| No status | Public non-verified, with date | Yes | Date from discontinued date. |
| No status | Public non-verified, no date | No | No discontinued date. |
| No status | Private | No | Manufacturer-given. |
| Phasing Out | Public non-verified | Partly | Parmigiani, status from the manufacturer. |
| Phasing Out | Private | No | Parmigiani. |

## Why no production status

- Many brands have no crawled data from the manufacturer's site, but we hold prices for them.
- Verified prices added by an external person: the production status is not known.
- Richard Mille and F.P. Journe: only non-verified prices; each reference has many variations and we do not know which ones are in or out of production.
- Parmigiani is the exception that has "Phasing Out", given by the manufacturer.

## Dates: what to know

| Topic | Fact | Detail |
|---|---|---|
| **Created later than last-seen** | About 3,000 to 4,000 non-verified rows | The date is the discontinued date. `CreatedAt` is when **we** collected the price, which can be later. WatchBase was fixed (dates read from the site's graph); other sources were not. |
| **Discontinued date** | From WatchBase and WatchCharts | If both have one, the **later** date is kept. |
| **WatchCharts dates** | Often present, but shows 2026 for in-production references | Less reliable alone. |
| **History** | Older price date = next price's created date | The latest price often has no date (unknown, or still listed). |

## Open points

1. Out of Production private prices have no date and we have no discontinued date data to fill it.
2. Non-verified prices without a date have no known discontinued date.
3. Some references have no production status.
4. Groups that do not match the stated rules: No status verified Seen=0 no date, In Production verified Seen=1 with date.
5. The rows with created later than last-seen were fixed only for WatchBase.
6. Where the "history date = next price's created date" rule is applied is not in the daily update SP, to confirm.
