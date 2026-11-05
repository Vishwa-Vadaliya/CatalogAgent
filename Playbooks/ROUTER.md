---
type: Playbook
title: Task router
description: Classify an incoming task and open the right playbook. The first thing to read on every task.
tags: [playbook, router, entry-point]
timestamp: 2026-11-04
---

# Task router

Classify the task, open the playbook, follow it. If the task matches more than one row, start with
the **Jira ticket** row when there is a ticket, then route again on what the ticket actually asks for.

**If nothing in the table matches:** don't stop and ask just because no row fits. Instead —
1. Search `D:\EW\ew-db` (see [../Knowledge/ew-db-repo.md](../Knowledge/ew-db-repo.md) for the folder
   layout) for tables, views, SPs, or columns that relate to the task's own keywords — e.g. a
   "nickname" task means grep the schema for `Nickname` columns/tables, not guess a playbook name.
2. Use what that search turns up to scope the task, then do the work as an ordinary query/
   investigation task under the core rules (A0 restate-and-confirm, A6 schema-check, A7 start simple).
3. Only stop and ask if the schema search itself turns up nothing relevant, or the task stays
   genuinely ambiguous after looking — i.e. ask because of what was *found* (or not found), not
   because the router table had no row for it.

| The task mentions… | Open | Also pulls in |
|---|---|---|
| `ECH-nnn`, a Jira URL, "this ticket" | [ticket.md](ticket.md) | then routes to a domain playbook below |
| enrichment, ENR, enrichment rule, multiple match, multiple ENR, dial colour dedup, image match, image similarity, variations | [enrichment.md](enrichment.md) | `image-match-review` skill for a full brand review |
| retail price, MSRP, price last seen, `PriceLastSeenDate`, IsSeen, `IsSeenInLastRun`, private price, AP price, outlier price, production status | [retail-price.md](retail-price.md) | |
| brand refs, reference validation, `RawRefsToAssign`, valid/invalid refs, ref structure, a brand name with "references" | [brand-refs.md](brand-refs.md) | `brand-ref-agent` skill |
| new refs from raw, raw to catalog, `tbl_RAW_Catalog` → `tbl_CAT_Catalog_d`, staging, ECH-693 | [raw-to-catalog.md](raw-to-catalog.md) | |
| catalog traceback, log a catalog change, "I renamed/deleted/merged" a ref, model or catalog row | the `log-catalog-change` skill | [../Knowledge/workflows/catalog-traceback.md](../Knowledge/workflows/catalog-traceback.md) |
| "run a retro", review the feedback log, promote corrections into rules | the `retro-feedback` skill | |
| "Enrichment/model says X but the listing says Y", a CMS admin link + public listing link, "is this right?" | [mismatch-check.md](mismatch-check.md) | |
| assigning a collector nickname, nickname verification, "is this nickname valid" | [../Knowledge/workflows/nickname-assignment.md](../Knowledge/workflows/nickname-assignment.md) | |

## Always, whatever the playbook

1. `git config user.name` → `Ravi` / `Vishva` / `Janvi` — the folder for this session's output.
2. Restate the requirements as a numbered list and wait (A0).
3. Add [../Rules/10-sql-style.md](../Rules/10-sql-style.md) to context before writing any SQL.
4. Check the schema in `D:\EW\ew-db` before writing a query (A6).
5. Deliver in the shape set by [OUTPUT.md](OUTPUT.md).
6. Stay inside the limits in [MCP.md](MCP.md).
7. Close with the decision log (A0).
