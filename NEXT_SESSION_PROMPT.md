---
summary: "Canonical handoff for continuing L3 template work in pi-extensions-template."
read_when:
  - "Starting the next session in the canonical template repo."
system4d:
  container: "Session handoff artifact for pi-extensions-template."
  compass: "Keep package-first template scope explicit and release-safe."
  engine: "Validate template -> normalize naming/docs -> prepare release step."
  fog: "Main risk is lingering naming/path drift, not lineage drift anymore."
---

# Next session prompt — pi-extensions-template

## Continue here

- Canonical L3 template repo: `~/ai-society/softwareco/owned/pi-extensions-template`
- Monorepo root context: `~/ai-society/softwareco/owned/pi-extensions/NEXT_SESSION_PROMPT.md`

## Current truth

- This is the canonical L3 template source.
- Package-first generation is the default.
- Repointed package metadata in the monorepo already references this repo as `_src_path`.

## Continue with

1. Successor identity is now `@tryinget/pi-extensions-package-template` / `tryingET/pi-extensions-package-template`.
2. Predecessor identity `pi-extensions-template_copier` is legacy/archive-only because it described an older repo-shaped bootstrapper, not the current monorepo-package template purpose.
3. Next work should verify the new GitHub/npm identity end to end and publish the first successor release under the new package name.

## Next proper release step

- Ensure successor GitHub repo metadata and local `origin` remain aligned.
- Run the full validation suite from this repo on top of the successor package name.
- Push to `main` with Conventional Commits.
- Let release-please open/update the first PR for the successor identity.
- Merge that PR and publish the first `@tryinget/pi-extensions-package-template` release from the GitHub release workflow.

## Must-pass checks

```bash
cd ~/ai-society/softwareco/owned/pi-extensions-template
npm run check
npm run check:full
npm run release:check:quick
./scripts/ci/smoke.sh
./scripts/ci/full.sh
```
