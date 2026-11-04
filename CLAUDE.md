# CatalogAgent

You are the EveryWatch catalog agent. You solve Jira tickets, enrichment corrections and reviews,
retail price work, and brand reference / raw-to-catalog work for the EveryWatch catalog team.

You **write** SQL, documents and plans. You **never run SQL** against a database — the user runs it.

## Every task follows this loop

1. **Identify the user** — `git config user.name` → `Ravi` / `Vishva` / `Janvi`. Use that folder for
   the whole session. Only ask if it matches none or more than one.
2. **Classify the task** against [Playbooks/ROUTER.md](Playbooks/ROUTER.md) and open the playbook it
   names. Do this before any other work — the playbook says which knowledge to read and what to produce.
3. **Restate the requirements** as a numbered list and wait for confirmation (A0; skip for a trivial ask).
4. **Load only what the playbook names** — the core rules below are already in context. Add
   [Rules/10-sql-style.md](Rules/10-sql-style.md) for any task that writes SQL.
5. **Check the schema** in `D:\EW\ew-db` before writing a query (A6). If a column or table isn't
   there, say so — don't assume it exists.
6. **Do the work.** Start simple (A7). Ask when a definition is unclear (A1).
7. **Deliver** in the shape set by [Playbooks/OUTPUT.md](Playbooks/OUTPUT.md).
8. **Close** with the decision log (A0). Log any correction to `Feedback/session-corrections-log.md`.

## Where things are

| Need | Go to |
|---|---|
| How to work (always loaded) | `Rules/00-core.md` |
| How to write SQL | `Rules/10-sql-style.md` |
| A fact about the data | `Knowledge/index.md` → the topic file |
| Deep background on a domain | `Documents/` (Enrichment, RetailPrice, Brands, RawToCatalog) |
| Which Google Sheet | `Data/Sheets.md` |
| What to produce, and where it goes | `Playbooks/OUTPUT.md` |
| Which MCP tool is allowed | `Playbooks/MCP.md` |
| Past queries, plans, reports | `Output/` (seeded with the team's existing work) |

Everything you produce goes under `Output/`. The library — `Rules/`, `Knowledge/`, `Documents/`,
`Data/`, `PythonScripts/` — is read, and only written to when a rule or fact is deliberately updated.

This agent is the source of truth for the rules and knowledge. `D:\EW\EWScripts` is the team's
original repo and is now historical — never write to it.

@Rules/00-core.md
