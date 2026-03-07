---
summary: "Decision note for package-first L3 template positioning and tracked L2 lineage."
read_when:
  - "Changing template scope, Copier lineage, or downstream migration policy."
---

# Decision: package-first L3 template with tracked root lineage

## Status

Accepted.

## Context

`~/ai-society/softwareco/owned/pi-extensions-template` is the L3 template source for generating package workspaces inside the `pi-extensions` monorepo.

The intended chain is:

`tpl-template-repo (L0) -> softwareco (L1) -> tpl-project-repo (L2) -> pi-extensions-template (L3) -> generated package`

During migration into `softwareco/owned`, the repo became functionally valid as an L3 template source, but the update lineage back to `tpl-project-repo` was temporarily unclear.

## Decision

1. **Package-first is the canonical mode.**
   - Default scaffold mode is `simple-package`.
   - `monorepo-package` is retained as a compatibility alias for older callers.
   - The main target is `~/ai-society/softwareco/owned/pi-extensions/packages/*`.

2. **Standalone repo mode remains compatibility-only.**
   - It is kept as an explicit opt-in path.
   - Docs and CLI examples should lead with package generation, not standalone repo bootstrap.

3. **Root `.copier-answers.yml` stays tracked in the L3 template repo.**
   - It is required to preserve L2 -> L3 lineage to `tpl-project-repo`.
   - This is a repo-level exception to the usual “generated repos only” mental model.

4. **Downstream package repoints must be migration-aware.**
   - Existing generated packages may have substantial local deltas.
   - Blind `copier copy`/`recopy` from the new L3 source can overwrite product code and docs.
   - Repointing must therefore be validated package-by-package, with backups first.

## Consequences

### Positive

- L3 can evolve with `ak` / `rocs` / project-scaffold tooling while still remembering its L2 origin.
- Operators get one canonical package-first source for future scaffolds.
- Guardrails can enforce lineage instead of relying on tribal memory.

### Tradeoffs

- The L3 repo must tolerate tracked root generated metadata (`.copier-answers.yml`).
- Existing packages cannot all be mass-repointed safely in one blind pass.

## Operational policy

- In the L3 template repo:
  - keep root `.copier-answers.yml` tracked
  - validate with `npm run check`, `npm run check:full`, and CI lanes
- In generated packages:
  - keep `.copier-answers.yml` tracked
  - update from a clean destination repo or after making a backup
  - prefer `copier update --trust`; use `copier recopy --trust` only when update is unavailable or intentionally reset

## Deferred migration note

At least one downstream package (`prompt-template-accelerator`) has enough custom drift that a blind repoint from the new L3 source would rewrite implementation files. That migration should be handled as a dedicated package update pass, not bundled into L3 lineage restoration.
