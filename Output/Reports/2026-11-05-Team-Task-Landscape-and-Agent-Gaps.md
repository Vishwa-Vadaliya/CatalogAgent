---
type: Report
title: Team task landscape & agent gaps
description: What Vishva, Janvi and Ravi actually work on (68 ECH tickets + CMS tickets + Slack/Granola intake), grouped into 12 task families, each checked against what CatalogAgent already knows and what it still needs.
tags: [report, review, agent-improvement, jira, task-analysis]
timestamp: 2026-11-05
---

# Team task landscape & agent gaps

## What I looked at

| Source | What I pulled |
|---|---|
| Jira ECH | **68 tickets** — every ECH issue ever assigned to Vishva Vadaliya, Janvi Rupapara or Ravi Aajugiya (`assignee WAS IN (...)`, so Done and reassigned ones are included). Range: 2026-03-25 → 2026-11-04. Full descriptions read. |
| Jira CMS | ~30 CMS-project tickets that appear in the shared sheet — a **second Jira project the agent has never been told about**. |
| Sheet `All Tasks` | 34 merged cross-channel tasks (T01–T34) + the Jira pull-through. |
| Sheet tabs `Slack` / `Granola` / `Waiting For Approval` | How work actually arrives and who is waiting on whom. |

Per-person split of the 68 ECH tickets: **Ravi 24, Janvi 17, Vishva 11**, and **16** currently sit
with someone else (Vishnu, Dhara, Pauline, Mayur, Nadia) but passed through one of the three.

---

## 1. Where the work comes from — the intake map

This is the first thing the agent is missing. `ROUTER.md` assumes a task arrives as a Jira ticket.
In reality it arrives through **four channels**, and about **half of it never becomes an ECH ticket**:

| Channel | Share | Shape |
|---|---|---|
| **Jira ECH** | the backlog | A proper ticket with a description, a sheet link, and a named reporter (Ana Faria, Bhargavi Sheth, Nadia, Dhara). |
| **Jira CMS** (`CMS-nnnnn`) | large, invisible to the agent | CMS-side work: Master Management values, reference enrichment pages, case-number cleanup, auto-create rules. Lives at `cms.everywatch.com`. |
| **Slack** | ~20 live asks in 2 weeks | `#enrichment`, `#ew-devs`, `#data-intelligence-enr`, `#next-ticket-to-be-open` + DMs. One-line asks: "ENR 86532 has the wrong model", "replace the watermarked image on ENR 85105". Many are never ticketed. |
| **Granola meetings** | weekly decisions | Decisions made with Thomas / Nadia / Ana that become the requirement — e.g. the Asprey-vs-Rolex vintage rule came out of a meeting, not a ticket. |

**Recurring cadence work** (also undocumented): AP enrichment improvement at month end;
weekly/twice-weekly new-manufacturer-ref run (ECH-693); monthly AI raw-reference cleanup
(CMS-12502); the monthly `<Name> - On-Going Work - <Month>` umbrella ticket per person
(ECH-56/57/59 → 545/546/548 → 820/821/823).

---

## 2. The twelve task families

Counts are indicative — many tickets sit in two families.

| # | Family | ~Tickets | Mostly | Example tickets |
|---|---|---|---|---|
| F1 | Enrichment QA — rule value vs enrichment image | 8 | Ravi, Janvi | ECH-238, 442, 443, 449, 232, 251, 786 |
| F2 | Image-match enrichment tuning (type 5 / type 1) | 10 | Vishva | ECH-288, 605, 638, 735, 608, 139, 590, 630, 763 |
| F3 | Multiple-ENR, clustering & disambiguation | 7 | Ravi | ECH-284, 515, 372, 126, 129, 112, 315 |
| F4 | Reference-number cleanup & validation | 9 | Janvi, Ravi | ECH-76, 82, 90, 103, 804, 555, 519, 217 |
| F5 | Master values & mapping hygiene | 6 | Janvi, Ravi | ECH-409, 742, 743, 215, 686 |
| F6 | Retail price & production status | 6 | Janvi, Vishva | ECH-462, 298, 110, 159, 138 |
| F7 | Catalog fill — brands, refs, CMS fields | 5 | Ravi, Vishva | ECH-579, 116, 693, 77 |
| F8 | New enrichment attributes (OCR, signatures, complications) | 7 | Janvi, Ravi | ECH-314, 696, 705, 119 |
| F9 | Agent / automation design | 5 | Ravi, Vishva | ECH-135, 126, 693, 840, 692 |
| F10 | Reports & coverage analysis | 5 | all | ECH-90, 82, 129, 304, 665 |
| F11 | Decision / confirmation tickets (no SQL at all) | 8 | Ravi | ECH-192, 215, 555, 742, 743, 414, 736 |
| F12 | Catalog-resync fallout | 2 | Ravi | ECH-786, 686 |

---

## 3. Family by family — what it is, what exists, what's missing

### F1 — Enrichment QA: rule value vs enrichment image

**What the task is.** Take a brand's reference enrichments, compare the value stated in the
enrichment rule (dial colour, case material, manufacturer) against what the enrichment *image*
actually shows, and report the mismatches. Always the same output shape:

> ECH-442: Total Cartier records 3,748 / checked (dial colour present) 2,338 (62.38%) /
> placeholder image 52 (1.39%) / dial colour empty — skipped 1,410 (37.62%) / mismatched …
> ECH-449: 128 flagged Rolex records. ECH-786: 385 checked, 56 mismatches (14.55%).

**Already in the agent.** `Playbooks/enrichment.md`, `Knowledge/enrichment.md`,
`Documents/Enrichment/*`.

**Missing.**
- No playbook or skill for this audit, even though it is the single most repeated ticket shape.
- The **standard counts table** (Total / Checked / Placeholder / Empty-skipped / Mismatched / %)
  is reinvented every time — it should be a template.
- No fact recorded about *where the enrichment image lives* vs the rule values, or how to tell a
  placeholder image from a real one in SQL.
- No note that "manufacturer wrong" (ECH-443: a Cartier ENR showing a Rolex, a Rolex ENR showing a
  Tudor) is a **different root cause** from a dial-colour mismatch and needs a different fix.

### F2 — Image-match enrichment tuning

**What the task is.** Manufacturer-wide image match (type 5) assigns the wrong enrichment; find out
why and tune. Three distinct root causes have now been found and each got its own ticket:
threshold too high (ECH-288, Rolex only), no confidence check alongside similarity (ECH-638),
and **secondary ENR images being used as a match source** (ECH-735 — the real root cause).
ECH-605 added a per-enrichment override flag; ECH-608 is building bucket training data
(~1,000 buckets × ~100 watches) to retrain the tool.

**Already in the agent.** Strongest coverage after retail price — the `image-match-review` skill
and `Knowledge/workflows/image-match-review.md`.

**Missing.**
- **The actual threshold values per brand.** `Knowledge/enrichment.md` says "by default … 0.89" but
  nothing records that Rolex was reverted to a different value, or what it was reverted to.
  Every tuning ticket starts by re-deriving this.
- The ECH-605 **override column name** — a new nullable enrichment-level flag — is not in
  `Knowledge/enrichment.md`, so the agent will not know it exists next time.
- Nothing on the ECH-735 rule: **only the primary ENR image is a valid match source.**
- Nothing on the "bucket" data format used for retraining (ECH-608).

### F3 — Multiple-ENR, clustering & disambiguation

**What the task is.** A watch gets no enrichment or alternating enrichments. ECH-515 works from
`tbl_RE_WatchEnrichmentLogs` (the change log introduced in ECH-368) to find **alternating
assignments** and **reference-only matches** (a newer ENR matching on reference number but not on
properties). ECH-284 handles **multiple peaks per enrichment reference** from Abhar's audit.
ECH-126 is the LLM approach: ask the model targeted yes/no questions ("Arabic or stick indices?",
"diamond or ruby embellishment?") derived from the candidate enrichments.

**Already in the agent.** `Documents/Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md`,
multiple-ENR facts in `Knowledge/enrichment.md`.

**Missing.**
- **`tbl_RE_WatchEnrichmentLogs` is not in the knowledge base at all** — not in `enrichment.md`,
  not in `stored-procedures.md`. It is the table the whole alternating-enrichment investigation runs on.
- No definition of "alternating enrichment", "reference-only match" or "multiple peaks".
- The LLM-question approach (ECH-126) is a technique the agent could *execute*; nothing captures it.

### F4 — Reference-number cleanup & validation

**What the task is.** Per-brand hygiene on reference numbers, with a growing list of **brand-specific
exceptions** that are the whole difficulty of the task:

| Rule | Exception recorded in |
|---|---|
| Delete 2-digit references | …except **F.P. Journe**, where they are valid (ECH-82) |
| References should be uppercase | **Breguet** (ECH-103), **Tudor** (ECH-804) |
| Unify to the manufacturer's own format | **Omega**: `1315405` → `131.5405`, `1490061SC` → `14900 SC-61` (ECH-76) |
| One reference → one model | …but Tudor refs legitimately span Black Bay *and* Heritage; current fallback is "model with the highest watch count" (ECH-90) |
| Reference ≠ model name | …but **Furlan Marri**, **Czapek & Cie**, **Armin Strom** genuinely use the model name as the reference (ECH-555) |

**Already in the agent.** `Knowledge/references-and-models.md` (52 lines), `Playbooks/brand-refs.md`,
the `brand-ref-agent` skill — but that skill **builds new refs from raw**, it does not clean
existing catalog refs. Different task.

**Missing.**
- A **reference-hygiene playbook** separate from brand-refs, and the exception table above as a
  standing fact file. Today each of these tickets re-discovers its own exception.
- Nothing on the "reference active and deleted at the same time" state (ECH-519).
- Nothing on capitalisation standardisation across brand/model/colour/embellishment/material (ECH-217).

### F5 — Master values & mapping hygiene

**What the task is.** The Master Management value tables drift. ECH-409: "Brown ombrè" exists three
times (IDs 4524, 4545, 4549) with the *same watches* assigned to all three. ECH-742/743 are plain
mapping-change approval tables (`light brown sunburst` → was `Smoked brown`, should be `Brown`;
`DLC-Coated Titanium` → was `Black DLC + PVD-coated titanium`, should be `Black DLC + DLC-coated
titanium`). ECH-215 is the parent/child problem: if `navy blue` is a child of `blue` and the parent
changes in CMS, what happens to the enrichment value already derived from the old parent?

**Already in the agent.** Almost nothing. `Knowledge/conventions.md` §3 describes the synonym
raw-text→ID moderation pattern generically. That is the closest thing.

**Missing — this is the biggest single hole.**
- No `Knowledge/master-values.md`: which tables hold dial colour / case material / embellishment,
  how parent–child works, how a value gets deactivated, what happens to watches already mapped.
- No dedup procedure (find duplicate master values → pick the survivor → remap → deactivate).
- No home for the colour/material mapping decisions in ECH-742/743 — those mappings are *knowledge*
  that will be needed again and currently live only in a Jira table.

### F6 — Retail price & production status

**What the task is.** ECH-462 (AP private price, `pricelastseendate` from the crawl date, else the
discontinued date), ECH-298 (YOP range — unverified prices have no history and no discontinued
year; manufacturer sites delete discontinued watches), ECH-110 (production status at
**reference level**, not model level, indexed into OpenSearch), ECH-159 (FPJ: many catalog
variations share one reference, so the one-to-one auto price mapping never fires).

**Already in the agent.** By far the best-covered area — `Documents/RetailPrice/` (13 files +
7 SP write-ups), `Knowledge/retail-price.md`, `Playbooks/retail-price.md`.

**Missing (small).**
- The **multi-variation → single-reference** mapping problem (ECH-159) isn't described anywhere.
- Ingesting prices **from a PDF as unverified** (ECH-138/159) has no documented route.
- Production status is documented as a concept but not as "how to fill it for a new brand".

### F7 — Catalog fill: brands, refs, CMS fields

**What the task is.** ECH-579 is a flat list: 18 independent brands with manufacturer IDs already
supplied (Kudoke 934, Bernhard Lederer 15661, Paul Gerber 705, Raúl Pagès 17552 …) that must be
added catalog-side. ECH-693 wants the manual "add new manufacturer refs" job turned into an agentic
flow run weekly. ECH-77 prioritises independent brands from the `brand_metrics` sheet.

**Already in the agent.** `Playbooks/raw-to-catalog.md`, `Documents/RawToCatalog/*`.

**Missing.**
- "Add a missing brand to the catalog" is a small, repeating, fully mechanical task with **no
  documented steps**. It should be a one-page playbook or a skill.
- `brand_metrics` and the other working sheets are **not registered in `Data/Sheets.md`** — which
  currently has exactly one named sheet (Catalog Traceback) plus one marked "(name TBD)".

### F8 — New enrichment attributes

**What the task is.** A steady stream of *new kinds of data* to capture: complications (ECH-314),
**retailer signatures / double-signed dials** with a full data dictionary and OCR synonym handling
(ECH-705), OCR dial-stamp vs brand confusion (ECH-696), special editions, the **aftermarket flag**
for modern Asprey (while vintage 1970s Asprey×Rolex is a genuine collaboration and *should* get a
variation), Coveted watch descriptions field mapping (ECH-119).

**Already in the agent.** Nothing. This vocabulary — retailer signature, double-signed dial, dial
stamp, special edition, aftermarket — appears nowhere in `Knowledge/` or `Documents/`.

**Missing.** A `Knowledge/dial-stamps-and-editions.md` (or a `Documents/` section), because this is
clearly becoming a domain of its own and the distinctions are subtle and decision-driven.

### F9 — Agent / automation design

**What the task is.** A growing share of the work is *building the automation*, not doing the data
task: ECH-135 (an agent that returns every factory configuration for a reference), ECH-126 (LLM
matching prompts), ECH-693 (agentic weekly new-ref flow), ECH-840 (connect Ravi's
auto-research-and-create-enrichment agent to the CMS flag queue and **define the flag taxonomy** —
"missing data", "wrong data", "verification"), ECH-692 (scrape Langepedia / SJX / ACM / John
Reardon's Patek research into a brand-by-brand authentication knowledge base).

**Already in the agent.** Nothing — and CatalogAgent does not know it is one of several agents in
this ecosystem.

**Missing.** A playbook for design/spec tickets whose deliverable is a **specification, taxonomy or
prompt set**, not SQL. Plus a `Knowledge/agent-ecosystem.md` naming the other agents
(enrichment agent, variation agent, image tool, OCR) and where CatalogAgent sits among them.

### F10 — Reports & coverage analysis

**What the task is.** "Produce a report for CMS" (ECH-82, ECH-90), "report ENR without
manufacturer/brand and define the assignment score threshold" (ECH-129), draft-watch breakdowns
(CMS-9695), missing core info for top auction houses (CMS-10087), global data coverage numbers,
the PostHog enrichment-ID sheet.

**Already in the agent.** `Output/Reports/` as a folder and `Playbooks/OUTPUT.md` for shape.

**Missing.** A reporting playbook: the standard counts table, the convention that the deliverable is
usually a **Google Sheet** (not a .md), and a script to push a result set into a sheet. Note that
`PythonScripts/prepare_review_sheet.py` already exists and is only wired into the image-match skill.

### F11 — Decision / confirmation tickets

**What the task is.** Roughly **one ticket in eight needs no query at all** — it needs a judgement
written down. ECH-555 ("is reference == model name expected behaviour?"), ECH-742/743 ("confirm this
mapping change"), ECH-192 ("confirm what flag he will provide and how"), ECH-215 (parent-change
semantics), ECH-840 ("specify the exact flag options"), ECH-414 (watches with collaborating brands).
Your own `Waiting For Approval` tab is full of these.

**Already in the agent.** `Templates/jira-comment-draft.md`, the A0 decision log.

**Missing.** A **decision playbook**: gather the evidence, state the options, give a recommendation,
draft the Jira comment, and record the decision somewhere durable so it becomes knowledge. Today
these decisions are made in Slack and lost.

### F12 — Catalog-resync fallout

**What the task is.** After the 28 Oct resync, 56 of 385 checked enrichments had the wrong dial
colour or case material (ECH-786). ECH-686 was a resync of the special Cartier case-number field.
ECH-537 explicitly races a resync: "finish the data-side fixes today so there's time for review
before CMS resyncs."

**Missing.** Nothing describes what a catalog resync *is*, what it overwrites, or the
check-after-resync routine — even though it is now a known, repeating source of corruption.

---

## 4. Coverage scoreboard

| Family | Knowledge | Playbook | Skill | Verdict |
|---|---|---|---|---|
| F6 Retail price | deep | yes | — | **Covered** |
| F2 Image-match tuning | partial | yes | yes | Good, missing the tuned values |
| F3 Multiple-ENR | partial | yes | partial | Missing the log table |
| F4 Reference cleanup | partial | wrong one | wrong one | **Needs its own route** |
| F1 Enrichment QA | partial | generic only | none | **Highest-volume, least supported** |
| F7 Catalog fill | partial | yes | — | Missing "add a brand" |
| F5 Master values | none | none | none | **Biggest hole** |
| F8 New attributes | none | none | none | **Whole new domain** |
| F9 Agent design | none | none | none | Not recognised as work |
| F10 Reports | none | OUTPUT.md only | — | No report shape |
| F11 Decisions | none | none | — | No route for no-SQL tickets |
| F12 Resync fallout | none | none | — | Not described |

---

## 5. What to add — prioritised

### P0 — do these first (they unblock the most tickets)

1. **`Knowledge/master-values.md`** — dial colour / case material / embellishment master tables,
   parent–child semantics, how a duplicate value is deduped and remapped, what a parent change does
   to an existing enrichment value. Fold in the ECH-742/743 mapping decisions. *(F5)*
2. **`Playbooks/enrichment-qa.md` + a counts-table template** — the rule-vs-image audit, the
   placeholder-image test, the standard count table, the per-brand sheet deliverable. *(F1, F12)*
3. **`Playbooks/reference-cleanup.md` + the brand-exception table** — casing, format normalisation,
   2-digit deletion, ref==model, ref on multiple models, with every exception found so far recorded
   in one place. *(F4)*
4. **Add the missing enrichment facts to `Knowledge/enrichment.md`** — `tbl_RE_WatchEnrichmentLogs`,
   the ECH-605 override flag, the per-brand image thresholds (current and reverted), "only the
   primary ENR image is a match source", and definitions of alternating / reference-only /
   multiple-peak.  *(F2, F3)*
5. **Register the real sheets in `Data/Sheets.md`** — `brand_metrics`, ReferenceNumberStructure,
   the enrichment-audit sheets, the mapping-review sheets. The agent currently knows one sheet.

### P1 — next

6. **`Playbooks/decision.md`** — for the one-in-eight tickets that need a recommendation and a Jira
   comment, not a query. Ends by writing the decision into `Knowledge/`. *(F11)*
7. **`Playbooks/report.md`** — report deliverables, the standard counts table, pushing results to a
   Google Sheet (reuse `PythonScripts/prepare_review_sheet.py`). *(F10)*
8. **`Knowledge/dial-stamps-and-editions.md`** — retailer signature, double-signed dial, dial stamp,
   special edition, aftermarket flag, and the Asprey vintage-vs-modern rule. *(F8)*
9. **`Knowledge/cms.md`** — the CMS side: Master Management, Reference Enrichment pages, what a
   catalog resync does and the check-after-resync routine. Add **CMS-project tickets** to the
   router's intake. *(F5, F12, intake)*
10. **`Knowledge/people-and-channels.md`** — who asks for what and who decides. Ana Faria and
    Bhargavi Sheth raise most ECH tickets; Nadia decides thresholds and priorities; Dhara owns
    clustering and reports; Thomas is the external watch expert; Ajay owns the image tool. Half the
    work arrives by Slack DM and the agent has no idea these people exist.

### P2 — structural

11. **`Playbooks/spec.md`** for F9 agent-design tickets + `Knowledge/agent-ecosystem.md`.
12. **An intake skill** (`/triage`) that reads the ECH + CMS boards and the Slack/Granola tabs and
    produces exactly the merged list your `All Tasks` sheet holds — you are maintaining that by
    hand today, and it is the highest-leverage automation in this whole review.
13. **A "month roll-over" helper** that opens the three `On-Going Work - <Month>` tickets and
    carries forward what is still open.
14. **`Rules/20-task-shapes.md`** — the recurring output shapes (counts table, enrichment-ID sheet,
    mapping before/after table, flag taxonomy) so they stop being reinvented per ticket.

### Router changes

`Playbooks/ROUTER.md` currently has 7 rows. It needs rows for: enrichment QA audit, reference
cleanup, master-value dedup / mapping change, decision-only ticket, report request, agent/spec
ticket, and CMS-project ticket. Plus a line saying work may arrive from Slack or a meeting with no
ticket at all.

---

## 6. The honest limits

Three things stop the agent from "solving all the tickets on its own", and no amount of knowledge
fixes them:

- **It can't run SQL** (by design, A1). Every data answer needs you in the loop. That is correct
  for safety, but it means the agent's realistic ceiling is *"produce the exact query and the exact
  deliverable, ready to run"* — which is worth aiming at precisely.
- **It can't see the CMS or the enrichment images.** F1 and F2 are fundamentally visual tasks. The
  agent can produce the candidate list and the counts; a human or the image tool makes the call.
- **A lot of the input is a Google Sheet or an .xlsx attached to the ticket.** Sheets it can read;
  Jira attachments it cannot. Worth standardising on sheet links in tickets.

---

## 7. Decision log

- Decision: pulled the ticket set with `assignee WAS IN (…)` rather than `assignee IN (…)` — based
  on the ask to include Done and historical tickets; the current-board filter returns 52, the full
  history returns 68.
- Decision: grouped into 12 families rather than by playbook or by person — no existing knowledge
  for a task taxonomy; decided by reasoning from the ticket descriptions.
- Decision: treated CMS-project tickets as in-scope — based on their presence throughout the shared
  sheet as work assigned to the three of you, even though the agent has never been told about them.
- Decision: filed under `Output/Reports/` — based on `Rules/00-core.md` A2 (finished write-ups go in
  `Output/Reports/`).
