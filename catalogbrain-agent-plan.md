---
type: Plan
title: CatalogAgent — build plan
description: Plan for building D:\EW\CatalogAgent, a multitasking Claude Code agent sourced from the CatalogBrain repo — split rules, topic-split knowledge, task playbooks, output contract and MCP guardrails. EWScripts itself is left unchanged.
tags: [plan, agent, catalogagent, catalogbrain, skills, mcp, jira, enrichment, retail-price, brand-refs]
timestamp: 2026-11-04
---

# CatalogAgent — build plan

## Requirements as understood (A0)

1. Build one multitasking agent sourced from the CatalogBrain repo (`D:\EW\EWScripts`): Jira tickets, enrichment correction/review, retail price, brand-ref validation / raw-to-catalog.
2. It lives in a **new folder, `D:\EW\CatalogAgent`**. **Nothing in `D:\EW\EWScripts` is changed** — content is copied out of it, not edited in place.
3. The agent becomes the **source of truth** for rules and knowledge from here on. EWScripts stays as the team's existing query and document archive.
4. Everything the agent produces goes into its **own `Output/` folder**, mirroring the familiar layout and **seeded with the existing queries, plans and reports** so old and new work sit together.
4b. **Every folder in EWScripts is carried across** — nothing is dropped, including the ones that look inactive.
5. The rules must be genuinely **always applied**, not "hopefully read".
6. The knowledge must be **split by topic** instead of one large file, so the right fact can be found without loading everything — one file per topic, with the EWMaster / EveryWatch distinction carried inside the files rather than as the top-level split.
7. `skills/` holds **only the three skills that exist today**; `agents/` stays **empty** for now. Both grow later.
8. Runtime is Claude Code. Jira is read-only. The agent writes queries and documents for the user to run — it never runs SQL itself.

## Context

CatalogBrain already holds everything the agent needs: the rules, the DB knowledge, the domain documents, three working skills, the correction hooks and the corrections log. What is missing is the wiring — today a task is routed by the user remembering which document or skill to point at, the same context is re-gathered every session, and `Rules/EW_Rules.md` is only loaded if the model actually reads it.

CatalogAgent adds three things on top of that content: **rules that are always in context**, **knowledge split small enough to index**, and **a playbook per task type with a fixed output shape**. EWScripts is left exactly as it is.

## How "always applied" is achieved (confirmed mechanics)

- Claude Code auto-loads `CLAUDE.md` (plus ancestors and user scope) at launch. A file merely *referenced* in a sentence is **not** loaded — it costs a Read call the model may skip.
- `@path/to/file.md` inside `CLAUDE.md` **is expanded at launch**, alongside `CLAUDE.md` itself (relative to the importing file, up to 4 hops deep, outside code spans). So rules can stay in their own file and still be guaranteed present.
- Adherence drops as the auto-loaded block grows; the docs suggest keeping it under ~200 lines.
- Skills contribute only their frontmatter `description` until invoked. Subagent definitions behave the same way.

**Therefore the rules split in two:**

| File | Holds | Loading |
|---|---|---|
| `Rules/00-core.md` | Part A — safety (never run SQL), A0 requirement restatement + decision log, where files go, `ew-db` edit scope, start-simple, show diffs, no publish calls | `@import`ed by `CLAUDE.md` → **always in context** |
| `Rules/10-sql-style.md` | Part B — B1–B11 query style (temp tables not CTEs, no DECLARE, NOLOCK, headers, images, TransactionID, updates, staging, id matching, IsDeleted, no DISTINCT in OVER) | Loaded by any playbook that writes SQL |

A `SessionStart` hook is the fallback if `@import` ever proves unreliable in practice — it injects text before the first prompt and is the only guaranteed mechanism besides imports.

## Target structure — `D:\EW\CatalogAgent`

```
D:\EW\CatalogAgent\
├─ CLAUDE.md                  ← the only auto-loaded file: identity, @import of core rules,
│                               "classify every task via Playbooks/ROUTER.md", the run loop
├─ README.md                  ← human guide: what this is, how to start it, where things go
├─ index.md                   ← agent-facing map, links each folder's own index
│
├─ Rules/
│  ├─ index.md
│  ├─ 00-core.md              ← Part A — always-on via @import
│  └─ 10-sql-style.md         ← Part B — loaded for SQL tasks
│
├─ Knowledge/                 ← EW_DB_Knowledge.md split by topic, sections moved verbatim
│  ├─ index.md                ← keyword → file table + a secondary "by database" view
│  ├─ databases.md            §1 + §2 — the two DBs, mirror DB, cross-DB prefixes,
│  │                          ids differing between them, manufacturer id table   [both]
│  ├─ watches.md              §3 — draft vs publish, IsDeleted, watch counts,
│  │                          watch attribute tables                        [EveryWatch]
│  ├─ references-and-models.md §4 + §5 + §6 — refs/models catalog side vs watch side,
│  │                          Rolex 'm' exception, clean-name & structure fns     [both]
│  ├─ retail-price.md         §7 entire, as headings in ONE file: Tables · Ids ·
│  │                          Definitions & conditions · Daily jobs  [EWMaster → EveryWatch]
│  ├─ enrichment.md           §8 — ENR types, multiple-ENR, the ENR workflow [EveryWatch]
│  ├─ stored-procedures.md    §9 — SP directory: one line each + a pointer to the
│  │                          topic file that explains it                         [both]
│  ├─ images.md               §10 — catalog, watch, enrichment and raw image tables [both]
│  ├─ ew-db-repo.md           §11 — the D:\EW\ew-db folder layout                  [repo]
│  ├─ conventions.md          (DB_Conventions.md, as-is)                          [both]
│  └─ workflows/
│     └─ image-match-review.md  (Image_Match_Review_Workflow.md, as-is)
│
├─ Playbooks/
│  ├─ ROUTER.md               ← one table: trigger words → playbook
│  ├─ OUTPUT.md               ← the fixed deliverable shape
│  ├─ MCP.md                  ← which MCP server for what, and the hard limits
│  ├─ ticket.md               ← Jira: fetch, restate, route to a domain playbook
│  ├─ enrichment.md           ← enrichment correction + review
│  ├─ retail-price.md         ← retail price work
│  ├─ brand-refs.md           ← brand reference validation (wraps the brand-ref-agent skill)
│  └─ raw-to-catalog.md       ← ECH-693 new-refs flow
│
├─ Documents/                 ← domain documents copied from EWScripts/Documents, same name
│  ├─ index.md
│  ├─ Enrichment/             Complete-Guide, Rules-Documentation, Multiple-Match-Disambiguation,
│  │                          Runtime-Pipeline, PaulNewman-Tiffany-Variations
│  ├─ RetailPrice/            the whole RetailPrice documentation set incl. CONTEXT.md
│  ├─ Brands/                 per-brand validation notes + Reference_Numbers.md +
│  │                          Brand_Reference_Validation_Workflow.md
│  └─ RawToCatalog/           RawToCatalog_NewRefs_Overview.md + _Requirements.md
│
├─ Data/                      ← carried over as-is: Sheets.md (the Google Sheets index the
│                               brand-ref skill reads) + the three reference CSVs
│
├─ PythonScripts/             ← carried over as-is: check_tilt.py, pick_best_image.py,
│                               prepare_review_sheet.py, index.md
│
├─ PPT/                       ← carried over (empty today, .gitkeep)
│
├─ Templates/
│  ├─ requirements-restatement.md
│  ├─ decision-log.md
│  ├─ jira-comment-draft.md
│  └─ handoff-note.md
│
├─ Output/                    ← work product: SEEDED with the existing EWScripts work,
│  │                            new work joins it in the same folders
│  ├─ index.md
│  ├─ Queries/<Person>/<Brand|Subfolder>/   ← seeded with the 67 existing .sql files
│  ├─ Plans/<owner>/                        ← seeded with the 11 existing plan documents
│  ├─ Documents/                            ← new write-ups the agent produces
│  ├─ Data/                                 ← new exports
│  └─ Reports/                              ← seeded with the existing finished report
│
├─ Feedback/
│  └─ session-corrections-log.md    ← copied, numbering continues
│
├─ Archive/                   ← history kept out of the way: EW_Knowledge.md (superseded),
│                               past session summaries and handoff notes
│
└─ .claude/
   ├─ settings.json           ← the two existing hooks (paths updated) + MCP allow/deny
   ├─ skills/                 ← ONLY the three that exist today, copied as-is:
   │  ├─ brand-ref-agent/        brand-ref-agent, image-match-review, retro-feedback
   │  ├─ image-match-review/
   │  └─ retro-feedback/
   └─ agents/                 ← EMPTY — a README placeholder saying what goes here later
```

### What each control file actually contains

- **`CLAUDE.md`** — ~40 lines. Who the agent is, `@Rules/00-core.md`, and the instruction to classify every task through `Playbooks/ROUTER.md` before working. Nothing domain-specific.
- **`Playbooks/ROUTER.md`** — one table, nothing else. For example: *"dial colour" / "multiple match" / "ENR" / "enrichment rule" → `Playbooks/enrichment.md`*.
- **`Playbooks/<task>.md`** — the steps for that job, plus a **"read these first"** list naming the exact knowledge and reference files. Pointers only; a playbook never restates a rule or a fact.
- **`Playbooks/OUTPUT.md`** — the deliverable shape every task ends with.
- **`Playbooks/MCP.md`** — the per-server limits, mirrored by the deny rules in `settings.json`.
- **`Knowledge/index.md`** — a keyword → file table so a lookup opens one small file instead of the whole knowledge base, plus a "by database" view built from each file's `db:` field.

## How the knowledge is organised, and why

**Topic first, not database first.** Requests arrive as topics ("dial colour dedup", "retail price",
"multiple match"), never as "I have an EWMaster question" — so files are named after the words the
user would actually type. More importantly, the database axis cuts straight through the topics:

| Topic | Which DB |
|---|---|
| References & models | **both** — §4 is literally "catalog side does X, watch side does Y" |
| Images | **both** — §10 gives `tbl_CAT_Media` and `tblMediaAsset` side by side under one rule |
| Stored procedures | **both** |
| Retail price | EWMaster, **but** syncs into EveryWatch (`tblReferenceNumberMSRP`, `ResyncCatalogRetailPriceToEW`) |
| Watches, Enrichment | EveryWatch only |

Splitting those by database would sever exactly the cross-DB facts that cause mistakes (ids differing
between the two DBs, the `EveryWatch.dbo.` prefix, catalog-ref vs watch-ref) and let the agent read
one half without learning the other exists.

**The database distinction is kept in three cheaper places instead:**

1. `databases.md` — one file for the boundary itself: the two DBs, the mirror DB, the prefix rule, the id differences and the manufacturer-id bridge.
2. A `db:` frontmatter field on every file (`EWMaster` / `EveryWatch` / `both`), which drives the "by database" view in `index.md` and keeps grep working.
3. Each table named with its DB inside the text, as the original already does.

**Two conventions that make retrieval cheap:**

- **Frontmatter on every knowledge file** carrying `tags`, `db:` and a `keywords:` line holding the phrases a user would actually say ("PriceLastSeen", "IsSeen", "multiple match", "dial colour"). `index.md` is then just a table built from those fields.
- **A size rule of ~150 lines.** Past that, split by **sub-topic**, never by length — a long topic gets headings inside one file so a single open gives the whole picture. Retail price is ~57 lines and stays one file.

File names carry no number prefixes: numbering implies a reading order that does not exist, and plain
names match the words being searched for.

## Task router (`Playbooks/ROUTER.md`)

| Task type | Triggered by | Playbook | Reads first | MCP | Output |
|---|---|---|---|---|---|
| Jira ticket | `ECH-nnn`, a Jira URL | `ticket.md`, then hands to a domain playbook | the ticket, linked Confluence | Atlassian Rovo (read only) | requirements list → routed |
| Enrichment correction / review | "enrichment", "ENR", "multiple match", "dial colour", "image match" | `enrichment.md` (+ the `image-match-review` skill) | `Knowledge/enrichment.md`, `Documents/Enrichment/*` | everywatch SELECT (approved per query), Sheets | `.sql` in `Output/Queries/<Person>/<Brand>/`, sheet, document |
| Retail price | "retail price", "PriceLastSeen", "IsSeen", AP private price | `retail-price.md` | `Knowledge/retail-price.md`, `Documents/RetailPrice/CONTEXT.md` | everywatch describe / SELECT | `.sql` in `Output/Queries/<Person>/RetailPrice/` |
| Brand refs | "brand refs", "RawRefsToAssign", a brand name | `brand-refs.md` → the `brand-ref-agent` skill | `Knowledge/references-and-models.md`, `Documents/Brands/*` | Sheets / Drive | INSERT scripts, validation document, sheet |
| Raw → catalog | "new refs", ECH-693, `tbl_RAW_Catalog` → `tbl_CAT_Catalog_d` | `raw-to-catalog.md` | `Documents/RawToCatalog/*` | everywatch describe | staging + review scripts |
| Retro / feedback | "retro", a correction | the `retro-feedback` skill | `Feedback/session-corrections-log.md` | – | proposed rule/knowledge edits (user approves) |

## The run loop (in `CLAUDE.md`, identical for every task)

1. **Identify the user** — `git config user.name` → Ravi / Vishva / Janvi — and **classify** the task through the router.
2. **Restate requirements** as a numbered list and wait for confirmation (skipped for a trivial ask).
3. **Load context** — the core rules are already in; open only what the playbook names.
4. **Schema check** against `D:\EW\ew-db` before writing any query; say so plainly if a column or table is not found.
5. **Work** per the playbook; ask when a definition is unclear; start simple and flag any added complexity.
6. **Deliver** per `OUTPUT.md`; show diffs on edits; read appends back.
7. **End** — decision log citing what each decision was based on; corrections appended to `Feedback/`.

## Output contract (`Playbooks/OUTPUT.md`)

1. **Requirements** — the confirmed numbered list.
2. **Deliverable files** under `Output/` — `.sql` → `Output/Queries/<Person>/<Brand|Subfolder>/` in Part B style with no publish call; documents → `Output/Documents/`; data → `Output/Data/`; reports → `Output/Reports/`. Short queries (3–4 lines) stay in chat.
3. **Run instructions** — which steps to run in SSMS, what results to paste back, and the single-batch caveat when `TransactionID` capture is used.
4. **Jira comment draft** — drafted only; the user posts it.
5. **Decision log** — one line per decision: `based on <file/rule>`, or `no existing knowledge for this; decided by reasoning`.
6. **Open questions / next step.**

## MCP usage and guardrails (`Playbooks/MCP.md` + `.claude/settings.json`)

- **Atlassian Rovo** — read-only allowlist (`getJiraIssue`, `searchJiraIssuesUsingJql`, Confluence reads). No create, edit or transition tools; comments stay drafts.
- **everywatch** — `sql__describe` and `SELECT` only, with the exact query shown and approved **each time**. `execute_procedure` and any write is never run — it is handed to the user.
- **Google Sheets / Drive** — only the brand and review sheets the playbooks name.
- **Granola** — optional, read-only meeting context for a ticket.
- Enforced by a deny list in settings, not by prose alone.

## Nothing is left behind — folder-by-folder mapping

Every top-level item in `D:\EW\EWScripts` has an explicit destination:

| EWScripts | → CatalogAgent | Treatment |
|---|---|---|
| `Rules/` | `Rules/` | split into `00-core.md` (always-on) + `10-sql-style.md` |
| `Knowledge/` | `Knowledge/` | split into the nine topic files |
| `Documents/` | `Documents/` | same name, grouped into Enrichment / RetailPrice / Brands / RawToCatalog |
| `Data/` | `Data/` | as-is — `Sheets.md` + the three reference CSVs |
| `PythonScripts/` | `PythonScripts/` | as-is — all four files (`check_tilt.py`, `pick_best_image.py`, `prepare_review_sheet.py`, `index.md`) |
| `Queries/` (67 `.sql`, 14 folders) | `Output/Queries/<Person>/…` | seeded, folder structure kept; new queries join them |
| `Plans/` (11 documents) | `Output/Plans/<owner>/` | seeded; new plans join them |
| `Reports/` | `Output/Reports/` | seeded with the existing finished report |
| `Feedback/` | `Feedback/` | copied, numbering continues |
| `.claude/skills/` + `Skills/index.md` | `.claude/skills/` + `Skills/index.md` | the three existing skills, paths checked |
| `.claude/settings.json` | `.claude/settings.json` | the two hooks + the new MCP deny rules |
| `PPT/` | `PPT/` | carried over, empty with its `.gitkeep` |
| `CLAUDE.md`, `README.md`, `index.md` | rewritten | for the agent's own identity, folder guide and map |

## Build phases

1. **Skeleton** — create `D:\EW\CatalogAgent` with every folder above, each with its `index.md`. Initialise it as its own git repo.
2. **Rules split** — Part A → `Rules/00-core.md`, Part B → `Rules/10-sql-style.md`. Rewrite only the file-location rule (A2) to point at `Output/Queries/<Person>/…`; every other rule moves verbatim. Write `CLAUDE.md` with the `@import` and the run loop.
3. **Knowledge split** — move the 11 sections of `EW_DB_Knowledge.md` into the nine topic files above **verbatim**, add `tags` / `db:` / `keywords:` frontmatter to each, and build `Knowledge/index.md` as the keyword table plus the by-database view. Copy `DB_Conventions.md` and `Image_Match_Review_Workflow.md` across. Nothing is reworded, so no fact changes meaning; the only additions are the cross-links between files (e.g. `stored-procedures.md` pointing at `retail-price.md`).
4. **Documents copy** — copy the domain documents into `Documents/` under the four groupings, keeping the folder name the team already knows; `Archive/` takes the superseded `EW_Knowledge.md` and the old session summaries.
5. **Carry the rest across** — `Data/` (Sheets.md + the three CSVs), `PythonScripts/` (all four files), `PPT/` (empty, with its `.gitkeep`), and seed `Output/` with the existing work: the 67 `.sql` files into `Output/Queries/<Person>/…` keeping their folder structure, the 11 plan documents into `Output/Plans/<owner>/`, and the finished report into `Output/Reports/`. Check whether `PythonScripts/pick_best_image.py` and `.claude/skills/brand-ref-agent/scripts/pick_best_image.py` are identical — if so, keep one and point the other at it; if not, flag the difference rather than silently keeping two.
6. **Skills + hooks** — copy the three existing skills unchanged except for internal paths that point at the old repo; copy the two hooks into `settings.json` and add the MCP deny rules. `agents/` gets only a placeholder README.
7. **Playbooks** — `ticket.md` first (highest value), then `enrichment.md`, `retail-price.md`, `brand-refs.md`, `raw-to-catalog.md`, each distilled from the work already in the repo (ECH-251, ECH-409, ECH-693) as pointers, not copies.
8. **Dry-run** — replay two or three finished tickets from a fresh session in `D:\EW\CatalogAgent` and compare the output against what was actually produced; close the gaps in the playbooks.
9. **Later** — promote proven playbooks to skills; add subagents (`schema-checker`, `knowledge-finder`) in `agents/`; keep running `/retro-feedback` so the brain improves.

## Risks to watch

- **Two copies of the knowledge now exist.** Mitigated by the decision that CatalogAgent is the source of truth from here on — new facts are written there, and EWScripts' copies become historical. Worth stating plainly in both READMEs so nobody edits the wrong one.
- **The three skills contain repo-relative paths** that assume the EWScripts layout; each needs checking after the copy.
- **A2's folder rule changes meaning** (`Queries/` → `Output/Queries/`). It is the one rule that is rewritten rather than moved, so it needs a careful read.
- **Auto-loaded size** — `CLAUDE.md` plus the imported core rules should stay near 200 lines; if Part A does not fit, the lower-traffic parts move into the playbooks that need them.

## Verification

- Start a fresh session in `D:\EW\CatalogAgent` and ask something trivial: confirm the core rules are present in context without any Read (the always-on test).
- Run a known closed ticket end to end: it fetches through the Atlassian MCP, restates the requirements, routes to the right playbook, writes SQL into the right `Output/Queries/...` folder without executing anything, and ends with a decision log.
- Ask it to comment on Jira → it only drafts. Ask it to run a `SELECT` → it shows the query and waits. Ask for an `UPDATE` → it hands the script over instead.
- Ask a retail-price question and confirm it opens `Knowledge/retail-price.md` alone rather than the whole knowledge base; ask a references question and confirm it gets both the catalog side and the watch side from the one file.
- **Completeness check:** diff the two trees — every `.md`, `.sql`, `.csv` and `.py` in EWScripts must exist somewhere in CatalogAgent (count files per type on both sides and reconcile any difference).
- Confirm `D:\EW\EWScripts` is untouched: `git status` there shows no new changes from the build.

## Status

Plan agreed: folder `D:\EW\CatalogAgent`; the agent is the source of truth; output goes to its own
`Output/`; rules split into always-on Part A and on-demand Part B; knowledge split into nine topic
files, topic-first with the database distinction held inside them; the documents folder keeps the name
`Documents/`; every EWScripts folder is carried across and `Output/` is seeded with the existing
queries, plans and reports.

Build not started — next action is phase 1 (skeleton), phase 2 (rules split), phase 3 (knowledge split).
