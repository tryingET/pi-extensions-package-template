---
summary: "Implemented topology-first template direction for monorepo package outputs, replacing repo-topology wording as the primary model."
read_when:
  - "Changing scaffold modes in copier.yml or wrapper CLIs."
  - "Explaining the difference between a single package and an interlinked package-group."
  - "Aligning template outputs with the pi-extensions monorepo package model."
system4d:
  container: "Template mode redesign note."
  compass: "Make the template speak the same package-topology language as the monorepo."
  engine: "Clarify topology terms -> align scaffold modes -> delegate validation to monorepo root where appropriate."
  fog: "The existing wording suggests a repo-placement distinction when the real design distinction is package shape inside the monorepo."
---

# Proposal: template modes should be topology-first

## Status

Partially implemented.

## Problem

Current template language centers on:

- `standalone-repo`
- `monorepo-package`

That wording overemphasizes repository placement.

For `pi-extensions`, the more useful distinction is package topology inside the monorepo:

1. one package is enough
2. or several interlinked packages should be generated as one package-group

## Proposed canonical language

Use package-topology terms:

- `simple-package`
- `package-group`

If explicit monorepo wording is desired, use:

- `monorepo-simple-package`
- `monorepo-package-group`

## Meaning of each mode

### `simple-package`

Generate one package root such as:

```text
packages/<name>/
  package.json
  extensions/
  docs/
  tests/
```

Use for:
- `prompt-template-accelerator`
- `pi-autonomous-session-control`
- most extension packages

### `package-group`

Generate one logical group root such as:

```text
packages/<group-name>/
  package.json
  README.md
  docs/
  <subpkg-a>/package.json
  <subpkg-b>/package.json
  <umbrella>/package.json
```

Use for:
- `pi-interaction`-like families
- umbrella + helper package constellations
- cases where packages are intentionally co-developed as one capability group

## Validation consequence

For monorepo generation, template outputs should not embed a full private copy of package validation logic.

Implemented direction:
- monorepo-generated package outputs delegate to the root canonical script in `pi-extensions`
- template outputs provide thin wrappers only

Canonical root contract:

- `~/ai-society/softwareco/owned/pi-extensions/scripts/package-quality-gate.sh`

## Recommended migration policy for the template repo

### Phase 1 — terminology first
- document the topology distinction
- update README/wrapper help text to explain `simple-package` vs `package-group`
- keep old mode names as compatibility aliases temporarily if needed

### Phase 2 — root-gate delegation for monorepo outputs
- simple-package output delegates to monorepo root package-quality gate
- package-group output delegates to monorepo root package-quality gate
- monorepo package templates stop owning a full copy of quality-gate implementation

### Phase 3 — compatibility cleanup
- once callers are migrated, retire confusing old names or keep them only as aliases

## Implementation state right now

Completed:
- monorepo package template `scripts/quality-gate.sh` is now a thin wrapper that searches upward for the canonical root gate
- the wrapper can also honor `PACKAGE_QUALITY_GATE_SCRIPT` for isolated validation contexts outside the monorepo tree
- template README now describes monorepo package output as root-gate delegation rather than a private full-copy gate

Still to align:
- generated docs/contracts should consistently describe the implemented root-gate model everywhere
- broader scaffold terminology cleanup can continue incrementally

## Important clarification

This proposal is **not** saying generated things stop being packages.
Both outputs are packages.

The distinction is:
- one package root
- or one multi-package group

## Recommendation

Treat `simple-package` as the default mode.
Treat `package-group` as explicit and rarer.

That mirrors current monorepo reality better than the current wording.
