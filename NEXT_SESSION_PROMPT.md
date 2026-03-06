---
summary: "Handoff after moving pi-extensions-template_copier into softwareco/owned project scaffold with package-first defaults."
read_when:
  - "Starting the next session in the new template control-plane repo."
system4d:
  container: "Session handoff artifact for pi-extensions-template."
  compass: "Keep package-first template scope explicit and reproducible."
  engine: "Validate -> tighten defaults/docs -> prepare canonical adoption path."
  fog: "Main risk is leaving mixed messaging between package-first intent and standalone-repo legacy mode."
---

# Next session prompt — pi-extensions-template

## Workspace

- `~/ai-society/softwareco/owned/pi-extensions-template`

## What was done this session

- Created this repo from `softwareco/copier/tpl-project-repo`.
- Imported `pi-extensions-template_copier` source into this repo.
- Added project-scaffold tooling into template repo:
  - `scripts/ci/{smoke,full}.sh`
  - `scripts/rocs.sh`
  - `governance/work-items.{cue,json}`
  - `ontology/manifest.yaml` + ontology scaffold files
  - `tools/rocs-cli/`
- Initialized local git repo and created bootstrap commit.
- Ran and fixed deterministic tooling checks:
  - `ak work-items check` initially reported projection drift
  - exported projection via `ak work-items export`
- Flipped template generation defaults to package-first:
  - `copier.yml` default `scaffold_mode=monorepo-package`
  - wrapper defaults (`new-pi-extension-repo.sh`, `bin/new-pi-extension-repo.mjs`) now default to `monorepo-package`
- Updated README to reflect package-first scope + new repo path references.
- Added `ontology/dist/` to `.gitignore` to keep ROCS outputs out of status noise.

## Current validated state

Run in this repo and currently passing:

```bash
npm run check
npm run check:full
npm run release:check:quick
./scripts/ci/smoke.sh
./scripts/ci/full.sh
./scripts/rocs.sh --doctor
ak work-items check --repo . --path ./governance/work-items.json
```

## Priority objective next session

Use this repo as the canonical package-first L3 template source for `owned/pi-extensions`, with tracked root lineage back to `tpl-project-repo` and migration-aware downstream adoption.

## Immediate execution queue

1. **Naming + positioning cleanup**
   - Decide if npm package/repo naming should remain `pi-extensions-template_copier` or move to a package-first name.
   - Align `package.json` metadata (`repository`, `bugs`, `homepage`) with the new canonical repo path.

2. **Docs hardening**
   - Keep [package-first lineage decision](docs/decisions/package-first-lineage.md) in sync with repo guardrails and README.
   - Maintain:
     - package-first default,
     - standalone mode as opt-in compatibility path,
     - tracked root lineage for the L3 repo.

3. **Operator path integration**
   - Validate generation into monorepo destination:
     - `~/ai-society/softwareco/owned/pi-extensions/packages/<new-package>`
   - Confirm release metadata contract (`x-pi-template`) is preserved and discoverable.
   - Repoint existing packages only via dedicated migration passes; a blind recopy into `prompt-template-accelerator` was shown to overwrite implementation files.

4. **AK + ROCS guardrail tightening**
   - Keep `governance/work-items.json` projection in sync after any governance edits.
   - Ensure ontology refs and CI lanes stay deterministic in this repo and generated outputs.

## Invariants

- Treat this repo as **template source**, not generated output.
- Keep root `.copier-answers.yml` tracked to preserve L2 -> L3 lineage.
- Keep package-first as default; standalone mode must remain explicit opt-in.
- Preserve monorepo-safe output constraints for `monorepo-package` mode.
- Repoint downstream packages only with backups and package-specific validation.

## Quick start

```bash
cd ~/ai-society/softwareco/owned/pi-extensions-template
git status --short
npm run check:full
./scripts/ci/full.sh
```
