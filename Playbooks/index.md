---
type: Data Index
title: Playbooks index
description: Index of the task playbooks — the router, the two contracts, and one playbook per task type.
tags: [index, playbooks]
timestamp: 2026-11-04
---

# Playbooks — index

- [ROUTER.md](ROUTER.md) — **start here on every task.** Classify the task, open the right playbook.
- [OUTPUT.md](OUTPUT.md) — the fixed shape every finished task takes, and where each file goes.
- [MCP.md](MCP.md) — which MCP tool is allowed for what, and the hard limits.

## One per task type

- [ticket.md](ticket.md) — a Jira ticket → confirmed requirements → routed to a domain playbook.
- [enrichment.md](enrichment.md) — enrichment corrections and reviews, multiple ENR, dial-colour dedup.
- [retail-price.md](retail-price.md) — price last seen, seen status, private/public prices, outliers.
- [brand-refs.md](brand-refs.md) — brand reference validation (the full run is the `brand-ref-agent` skill).
- [raw-to-catalog.md](raw-to-catalog.md) — new official-source references from raw into the catalog.

A playbook holds **steps and pointers only** — never a copy of a rule or a fact. If a playbook needs
a fact, it links to the [../Knowledge/](../Knowledge/index.md) topic file that owns it.

Playbooks that prove themselves get promoted to skills in `.claude/skills/`.
