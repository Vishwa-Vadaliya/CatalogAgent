---
type: Rule
title: Core working rules (always applied)
description: Part A — how Claude works on EveryWatch catalog tasks: session capture, execution safety, where files go, chat vs file, ew-db edit scope. Imported by CLAUDE.md, so always in context.
tags: [rules, workflow, safety, always-on]
timestamp: 2026-11-04
---

# Core working rules

Always applied — this file is imported by `CLAUDE.md` and is in context from the start.
SQL *style* rules live in [10-sql-style.md](10-sql-style.md); load that file for any task that
writes SQL. Facts about the data live in [../Knowledge/index.md](../Knowledge/index.md).

## A0. Session requirement capture & end-of-task decision log

**At the start of a task** — within the user's first 1–2 messages that contain a ticket, ask, or
requirement — restate what was understood as a short numbered list before starting any work:

```
Requirement 1: ...
Requirement 2: ...
```

Keep each point short and limited to what was actually asked. This is for the user to confirm or
correct *before* work begins, not a summary written after the fact. Skip it for a trivial one-line
ask with nothing to disambiguate (e.g. "run this query", "what does X mean") — use judgment, don't
bureaucratize small asks.

**At the end of the task**, write a crisp decision log — one line per non-trivial decision:

- Decision that used existing knowledge: `Decision: <what> — based on [file or specific rule/fact name].`
- Decision with nothing to go on: `Decision: <what> — no existing knowledge for this; decided by reasoning.`
  (Or ask first, if the decision genuinely needs sign-off before being taken rather than after.)

One line per decision, no retelling of the conversation. Skip it entirely when nothing in the task
involved a judgment call.

## A1. Execution & safety

- **Never run a SQL query against any database yourself** — not via `sqlcmd`, `bcp`, Bash,
  PowerShell, or a DB driver — with one exception: the everywatch MCP SQL tools (below).
  - This holds even if the user explicitly says "yes", "go ahead", or "run it" for any path other
    than the MCP exception. Do not treat that approval as authorization to execute SQL directly.
  - Otherwise: write/update the `.sql` script and hand it to the user (or state clearly that it's
    ready) so **they** run it in their own DB tool (SSMS, DataGrip, etc.) and share results back.
  - Applies to every database in scope (MasterDB, EveryWatchDDL, any other project database) and to
    read-only `SELECT` queries just as much as writes.
  - **Exception — everywatch MCP (`mcp__everywatch__sql__*`), read-only `SELECT` only:** first show
    the user the exact query and ask whether to run it through the MCP. Run it only after the user
    says yes in reply to that specific ask; if they say no or don't answer, hand over the script.
    Ask again for each new query — one approval doesn't cover later ones. Never run writes or
    procedures (`INSERT`/`UPDATE`/`DELETE`/DDL/`execute_procedure`) through the MCP.
  - **Carve-out — `/log-catalog-change` only:** that skill may bundle the lookups for **one** logged
    change (or one batch) into a single approval, provided every query is shown **verbatim** in that
    one ask. It covers only that skill's fixed-shape record lookups, and only for the change being
    logged — the next change asks again. It does not extend to any other skill or query.
- **Never `git commit` or `git push` without being asked.** Do the work, then stop and say it's
  ready — leave the changes in the working tree for the user to review.
  - This holds for every repo, including this one, and for any route to the same effect: the `git`
    CLI, a git MCP tool, a GUI, or a script that commits as a side effect.
  - **One approval covers one action.** "Commit and push this" authorizes *that* commit and push,
    not the next one. Ask again each time, however small the follow-up change.
  - Don't stage-and-commit "to keep things tidy", to checkpoint before a risky edit, or because a
    task feels finished. Finishing work is not a trigger to publish it.
  - Creating or changing a remote, force-pushing, branching, tagging, rewriting history, reverting
    and merging follow the same rule — ask first.
  - Allowed without asking: read-only inspection (`git status`, `git diff`, `git log`, `git show`)
    and adding to `.gitignore` to keep a secret or artefact out of a commit.
  - A push is irreversible in practice — it is visible to others the moment it lands, and deleting
    it afterwards doesn't un-publish it. Treat it as the user's call, every time.
- When asked to diagnose, don't change the SP or file — give read-only queries and ask for results.
- Ask, don't assume, when a definition is unclear.
- The user can't create SPs in EveryWatch and prefers not to in EWMaster → give plain scripts in parts.

## A2. Where files go

Everything the agent produces goes under `Output/`. The reference library (`Rules/`, `Knowledge/`,
`Documents/`, `Data/`, `PythonScripts/`) is read, not written to, except when a fact or rule is
being deliberately updated.

- **Query/script files (`.sql`)** go under `Output/Queries/<Person>/`, where `<Person>` is one of
  **`Ravi`**, **`Vishva`**, **`Janvi`**.
  - **Auto-detect from the machine, don't ask.** At the start of a session, before writing the first
    query, run `git config user.name` (and `user.email` if needed) and match it case-insensitively
    against "Ravi" / "Vishva" / "Janvi" — e.g. `Janvi-wb` / `janvirupapara@weybee.in` → `Janvi`. Use
    the matched folder for the rest of the session without asking.
  - **Only ask if detection fails** — no git identity set, or it matches none/more than one of the
    three names — then ask which folder to use for the rest of the session.
  - Inside the person's folder, save in the **most relevant existing subfolder** (e.g.
    `MultipleENR\`, `Enrichment_correction\`, `RetailPrice\`, `Ref_cleanup\`, `Cartier_variations\`).
  - Don't save to the person's folder root when a fitting subfolder exists. If none fits, ask before
    creating a new one.
  - **Brand-specific queries** go in a subfolder named after the brand:
    `Output/Queries/<Person>/<Brand>/<QueryName>.sql`. Create the brand folder when it doesn't exist
    (no need to ask), and keep each query in its own `.sql` file inside it.
  - `Output/Queries/` holds only `.sql` files — no `.md`, `.csv` or other documents. Written
    documents go in `Output/Documents/`, data exports in `Output/Data/`, finished write-ups in
    `Output/Reports/`.
  - Never save query files under `Feedback/`.
- **Plan documents** go under `Output/Plans/<owner>/` (`janvi/`, `ravi/`, `vishwa/`) — each plan in
  the folder of the person who owns it. Write or move it there so it stays with the project; don't
  rely on a plan existing only under a global user-level plans directory.
- **`Feedback/`** is the log of corrections: every time Claude did something wrong and the user
  redirected it, add an entry recording what Claude did wrong, what the user said, and the right way.
  Write it every time a correction happens, without being asked. Only corrections go here.
  Never promote an entry into `Rules/` or `Knowledge/` without the user's go-ahead (`/retro-feedback`).
- **New facts** about the data go in the matching `Knowledge/` topic file; **new rules** about how to
  work go here or in `10-sql-style.md`. Each fact or rule is written once, in one file only.
- **Standing file** for AP private-price queries: `Output/Queries/<Person>/RetailPrice/RawCatalog_SeenStatus_PriceLastSeen.sql`.

## A3. Chat vs file

- **"Give/write it here"** (meaning in the chat reply), or the user otherwise doesn't ask for a file
  → paste the query/script directly in the chat message. Do **not** create a `.sql` file for it.
- **Short queries (about 3–4 lines):** don't create a file — give them in the chat reply.
- **Longer queries:** create a new `.sql` file per A2, without waiting to be asked.
- If a file was already created for something that should have stayed chat-only, remove it rather
  than leaving an unwanted untracked file behind.

## A4. "Append"

- When the user says "append", add the new query to the **end of the file currently open in the
  editor**. Don't create a new file.
- Keep the existing content. Add a header comment for the appended block and follow `10-sql-style.md`.
- If you can't tell which file is open, ask. Don't guess.
- After an append, read the file back (appends were lost twice to the editor buffer).
- Every appended block re-resolves its own variables — see B2 in `10-sql-style.md`.

## A5. Sheets

- Sheet → SQL loading: one `INSERT` formula per row. URL lists: split on `' || '`.
- Sheets: keep old decision columns, add new ones beside them.

## A6. `ew-db` repo & schema checks

Applies whenever a task touches the **EW-DB** codebase (`D:\EW\ew-db`), especially `MasterDB/`.
Folder layout: [../Knowledge/ew-db-repo.md](../Knowledge/ew-db-repo.md).

- **Check the schema first.** Before writing or modifying any query, stored procedure or join, read
  the relevant table `.sql` files in `ew-db` (MasterDB / EveryWatchDDL) to confirm column names,
  datatypes and indexes. Don't assume them.
  - Check that any SP, function or view you reference exists in the correct DB folder.
  - If a column or table is not found, say so explicitly — do not assume it exists.
- **Never modify any file inside `D:\EW\ew-db`** unless the user explicitly says to change the
  `ew-db` project. If a change seems needed, ask first. Applies to all files.
- **Edit scope once `ew-db` changes are requested:**
  - Only add or modify files under `MasterDB/` (e.g. `MasterDB/dbo/stored procedures`, `.../table`).
  - Treat `EveryWatchDDL/` as **read-only** — no fixes, refactors, hint changes, bulk scripts, or git
    operations that alter those files. Read-only use is allowed.
  - Don't modify other top-level areas outside `MasterDB/` (e.g. `PostgreSQL/`, `Scripts/`) unless
    the user **explicitly** names that path.
  - `ew-db` holds the database schema only. One-time or deploy SQL — `ALTER TABLE`, data fills,
    backfills, checks — goes in `Output/Queries/<Person>/…`, never in `ew-db` (not even `Scripts/`).
    Keep the table `.sql` files in `MasterDB/dbo/table` in line with the schema change.
  - Don't create or edit anything under `ew-db/.cursor/`. Every EW-DB-related rule goes in `Rules/`.
- **Changing a stored procedure:** first do a **read-only** check whether a matching routine exists
  under `ew-db/EveryWatchDDL/dbo/routine`.
  - If it does **not** exist there: **STOP**, ask whether a new procedure should be created.
  - If similar routines exist in the same folder: mention them, don't modify them unless in scope.
- **Safety precedence:** never rename columns, drop objects, change schemas, or change unrelated
  procedures. Only change what the user explicitly scoped.

## A7. Start simple, add complexity only when needed

- Give the plain, direct query/formula/script first. Don't add filters, conditional logic, escaping,
  or validation the request didn't call for.
- Only add that extra complexity when there's an actual, identified need — and when you do, flag it
  explicitly ("I added X because Y") rather than silently building it in.
- If unsure whether extra logic is needed, ask or point it out before building it in.

## A8. Show diffs on edit

- When editing an existing file, show the user the actual changed lines (not just a description that
  it was updated), so they can review the change without opening the file themselves.

## A9. No publish calls in handed-off scripts

- Never include `sp_PublishAllDataNew` (or any other publish-to-live call) in a query/update script
  handed to the user. The user often copies just a piece of a script and runs it directly — a
  baked-in publish call risks firing unintentionally.
- End the script after the update step (preview + `COMMIT`/`ROLLBACK` commented out, per B7).
  Publishing is a separate, deliberate action the user triggers themselves — mention it in chat if
  needed, don't add it to the file.
