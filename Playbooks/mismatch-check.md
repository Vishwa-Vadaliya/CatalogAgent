---
type: Playbook
title: Enrichment vs listing-description mismatch check
description: What to do when asked "Enrichment/model says X, but the listing(s)/description(s) say Y — is that right?", usually with a CMS admin link and/or a public everywatch.com listing link attached.
tags: [playbook, enrichment, verification, mismatch]
timestamp: 2026-11-05
---

# Playbook — enrichment vs listing-description mismatch check

## Steps

1. **Don't waste turns on WebFetch for CMS/login-gated or JS-rendered pages.** The CMS admin link
   (`cms.everywatch.com/...`) is behind login and the public everywatch.com pages are JS-rendered —
   WebFetch will not reliably return the real data for either. Skip straight to the DB: write a plain
   `SELECT *` (or a targeted `SELECT` once the right table/columns are known) against the relevant
   record, and ask the user to run it and **share a screenshot of the result** (no DB MCP connection
   for this — see [MCP.md](MCP.md) for what is available) — per A1, write the query, they run it.
   This is the actual way to "check the link" for this kind of task, not a fallback. If a usable DB
   connection is available (the everywatch MCP read-only path), use that instead of asking for a
   screenshot.
2. **Do the actual research** — don't stop at "I can't access this." Use domain knowledge (case
   shapes, informal dealer terminology, known reference history) plus the `SELECT *` results and any
   screenshots already given to reason about which side (Enrichment vs. listing text) is correct.
3. **Give a final, direct verdict** — e.g. "Enrichment says Royal Oak, listing says Octagonal; Royal
   Oak is correct because Octagonal is dealer slang for the case shape, not a distinct AP model" — not
   a list of options or a request for the user to decide. End with the recommended fix/action (e.g.
   "link these listings to the same Enrichment ID" / "re-tag the model") if one follows from the
   verdict.
4. Only fall back to asking a clarifying question if something is genuinely blocking (e.g. the
   fetched/screenshotted data is ambiguous even after research) — not merely because a link needed
   login.
