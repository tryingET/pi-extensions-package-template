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

1. Decide whether naming stays `pi-extensions-template_copier` or moves to a package-first identity.
2. Align `package.json` metadata and README wording with the canonical repo path.
3. Resolve the local-vs-published version mismatch and prepare the next proper release/version step.

## Must-pass checks

```bash
cd ~/ai-society/softwareco/owned/pi-extensions-template
npm run check
npm run check:full
npm run release:check:quick
./scripts/ci/smoke.sh
./scripts/ci/full.sh
```
