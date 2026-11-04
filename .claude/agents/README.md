# Subagents — empty for now

This folder will hold subagent definitions (`<name>.md`, frontmatter + a system prompt body).
Nothing lives here yet, by decision — subagents get added once the playbooks have proven out.

Planned, when we get to them:

- **`schema-checker`** — read-only. Given a table or column, look it up in `D:\EW\ew-db` and report
  what actually exists, so the main session doesn't spend context reading DDL files.
- **`knowledge-finder`** — read-only. Given a question, find the fact in `Knowledge/` and
  `Documents/` and return the answer plus its source file, instead of the files themselves.

Both would be read-only: a subagent must never gain a path around rule A1 (never run SQL) or the
MCP limits in `Playbooks/MCP.md`.

Only a subagent's `description` sits in context until it runs; the body is its system prompt and
loads in its own window, so it does not inherit this session's rules automatically — restate the
limits that matter inside each definition.
