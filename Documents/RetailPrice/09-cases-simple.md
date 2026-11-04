---
type: Document
title: Retail Price Cases
description: Short management version: words, where prices come from, one cases table with reasons, points to discuss, open points.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Audience: Management / non-technical (short version of 06)
Related: 06-cases-management-non-technical.md
---

# Retail Price Cases

## Words used

| Term | Meaning |
|---|---|
| **Reference** | One watch reference number. |
| **Verified price** | From the manufacturer's own website, or given by the manufacturer. |
| **Non-verified price** | From another source (info-source sites and similar). Shown publicly only if verified prices are not available. |
| **Private price** | Given to us directly by the manufacturer and not shown publicly. |
| **Production status** | In Production, Out of Production, Phasing Out, or none yet. |
| **Still listed** | The watch was still on the website at the last data collection. |
| **Last-seen date** | The last day we know the watch was on the website or had the price. |
| **Price history** | Several prices for the same reference and country over time. |

## Where retail prices come from

| Kind of price | Source | Shown publicly | Still-listed flag | Last-seen date |
|---|---|---|---|---|
| **Verified, public** | Manufacturer's website (collected automatically), or added by an external trusted person (for example Thomas) who gives us the retail price | Yes | Yes if still on the website, no if it was removed | Only when the price was removed from the website, or a date is known |
| **Non-verified, public** | Other sources (not the manufacturer), or added by an external trusted person (for example Thomas) who gives us the retail price | Yes, if verified prices are not available | Always set to "still listed" | Only when we know a discontinued date for the reference |
| **Private** | Given directly by the manufacturer | No | Always set to "still listed" and "verified" | Only when we know when the watch stopped |

## Cases and reasons

| Production status | Case | Reason |
|---|---|---|
| In Production | Verified, on the website now, no last-seen date | The normal case and the largest group. The price is on the manufacturer's website today, so there is no end date. Many of these also have older prices behind them, and those older prices have last-seen dates. |
| In Production | Verified, price removed from the website, has a last-seen date | We saw the reference on the website before, the price is gone now, so we record the last day it was seen. |
| In Production | Verified, available in some countries but not others | Prices are kept per country. The reference counts as in production if at least one country or source still lists it. A country that no longer shows the price is marked "not listed" and always gets a last-seen date. |
| In Production | Non-verified, other sources | Price comes from a source other than the manufacturer. It is always treated as still listed and has no last-seen date. |
| In Production | Private | Given by the manufacturer. Always treated as verified and still listed, with no last-seen date because the watch is in production. |
| Out of Production | Verified, no longer on any website, has a last-seen date | The reference is not on any manufacturer website any more. The price is marked "not listed" and has a last-seen date. |
| Out of Production | Non-verified, has a last-seen date | The reference is not on the manufacturer's website, but we have a price from another source. The date comes from the reference's discontinued date. |
| Out of Production | Non-verified, no last-seen date | Price from another source; we have no discontinued date for this reference and no crawled data from the manufacturer. |
| Out of Production | Private, has a last-seen date | Manufacturer-given price. Only a few of these are ever found by our collection (crawled data), which is where the date comes from. |
| Out of Production | Private, no last-seen date | Manufacturer-given price. We do not collect these references at all, or we have no discontinued date. |
| No status | Verified | Many brands have no data collected from the manufacturer's website, but we still hold verified prices for them. Verified prices can also be added by an external person, and then we do not know the production status. |
| No status | Non-verified, has a last-seen date | We took the date from the reference's discontinued date. Richard Mille and F.P. Journe are in this group: they have only non-verified prices from other sources, and many variations of one reference, so we do not know which variation is in production and which is out. |
| No status | Non-verified, no last-seen date | We do not know a discontinued date for the reference. Same brand note as above applies (Richard Mille, F.P. Journe). |
| No status | Private | Given by the manufacturer. |
| Phasing Out | Non-verified, has a last-seen date | Parmigiani only, where the manufacturer itself told us the status. Some prices have the date. |
| Phasing Out | Non-verified, no last-seen date | Parmigiani only. Other prices do not have the date. |
| Phasing Out | Private | Parmigiani only. Always treated as "verified" and "still listed". |

## Points to discuss

1. **About 3,000 to 4,000 non-verified retail prices have a last-seen date that is earlier than the effective date of the price (its created date).** For non-verified prices the last-seen date comes from the reference's discontinued date. For a price from a non-manufacturer source, the created date is the day we collected it, which can be long after the source first showed that price, so the discontinued date can be earlier than the created date. This is a data-timing effect, not an error in the price. WatchBase had the same effect and was fixed: we read the prices and their dates from the website's chart by hand and loaded them into the catalog. Other sources were not fixed.
2. **WatchCharts issue: WatchCharts shows 2026 dates even for references that are still in production.** The discontinued date is taken from WatchBase and WatchCharts. If both have a date for the reference, we compare them and keep the later one, so a wrong WatchCharts date can become the discontinued date.
3. **History and last-seen dates.** When a reference has several prices over time, the older price's last-seen date is the day the next price was created. So older prices have a last-seen date, and the latest price often does not: either we have no date to add, or the watch is in production and the price is still on the website.

## Open points

| # | Point | Why it matters |
|---|---|---|
| 1 | Private prices of Out of Production watches have no last-seen date. | The discontinued date could fill it, but we do not have discontinued date data. |
| 2 | Many non-verified prices have no last-seen date because we have no discontinued date for the reference. | A source of discontinued dates for these references would close the gap. |
| 3 | Some references have no production status. | These cannot be told apart as current or discontinued. |
