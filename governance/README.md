---
summary: "Governance for pi-extensions-template: the Agent Kernel DB is the sole work authority; the work-items projection is retired."
read_when:
  - "You are looking for deferred or active work for pi-extensions-template."
  - "You are tempted to reintroduce a checked-in governance/work-items.json projection."
type: "reference"
---

# Governance — pi-extensions-template

Deferred and active work for this repo lives in the **Agent Kernel DB** (`ak task ...`).
The AK DB is the sole work authority; no checked-in work-items projection exists or should be reintroduced.

The retired `governance/work-items.cue` schema had no checked-in `work-items.json` instance and carried no work items; nothing was lost at retirement.

## Non-negotiable

- Do not leave deferred work as ad-hoc TODO comments or scattered markdown notes.
- Do not reintroduce a checked-in `governance/work-items.json` projection; the AK DB is authoritative.
