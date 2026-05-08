# AGENTS.md — template repo guardrails

Purpose: maintain Copier template source. Not generated target repo.

## Context strategy
- Start with high-signal files (`copier-template/**`, `copier.yml`, relevant `scripts/*`).
- Skip blanket scans unless task scope is unclear.
- Once confidence is sufficient, implement complete template-safe changes, then validate.

## Invariants
- Keep template content under `copier-template/**` and `copier-template-monorepo-package/**`.
- Keep template config in `copier.yml` (+ wrapper scripts at repo root).
- Never run `copier copy ... .` into this repo root.
- Keep root `.copier-answers.yml` tracked to preserve L2 -> L3 lineage (`tpl-project-repo` source metadata).
- Generated package docs should prefer `docs/project/` for dated RFCs/runbooks/notes and `docs/adr/` for adopted decisions; do not reintroduce package-local `docs/dev/` trees.
- Generated monorepo packages should use plain installed `ak` for AK task/work-item operations rather than inventing package-local wrappers or copied launcher scripts.
- Generated monorepo packages should also state that direction authority stays at the monorepo root, with `ak direction import|check|export` run against the root repo context rather than package-local direction state.
- For AK-native task, direction, or route work, read the relevant AK task and route/open-frame status before inventing new work; generic `proceed` continues the active execution task when one exists and does not authorize lifecycle closeout, source-owner mutation, publication, or knowledge promotion.
- Handoff instead of editing by convenience when facts belong to Prompt Vault, ROCS, AK runtime, Pi/runtime, KES, steward/publication, template propagation, Oracle/DSPx, or another repo owner.
- `copier update` may be used for controlled L2 baseline sync; re-validate template guardrails afterward.

## Validation loop
- Run `bash ./scripts/template-guardrails.sh`.
- Run `bash ./scripts/smoke-test-template.sh`.
- Run `bash ./scripts/generated-contract-test.sh`.
- Run `bash ./scripts/idempotency-test-template.sh`.
- (Optional) Run `node ./scripts/code-list.mjs` to list source-file metadata headers.
- Keep contract rules in `contract/generated-repo.contract.json`.
- Install local hook once: `bash ./scripts/install-hooks.sh`.
- Keep this repo clean of generated-root artifacts.
