---
summary: "Canonical handoff for continuing template work in pi-extensions-template with engineering-core review and reduced-form output decisions still open."
read_when:
  - "Starting the next session in the canonical template repo."
system4d:
  container: "Session handoff artifact for pi-extensions-template."
  compass: "Keep template outputs minimal, review engineering policy boundaries deliberately, and avoid encoding root policy into every generated package by default."
  engine: "Validate template -> review engineering surfaces -> review session-prompt surfaces -> decide reduced-form template boundary -> prepare follow-up change carefully."
  fog: "Main risks are treating template output as the policy source, forgetting the root repo now owns more validation policy, or missing session/handoff prompt surfaces when changing template behavior."
---

# Next session prompt — pi-extensions-template

## Continue here

- Canonical template repo: `~/ai-society/softwareco/owned/pi-extensions-template`
- Monorepo root context: `~/ai-society/softwareco/owned/pi-extensions/next_session_prompt.md`

## Current truth

- This is the canonical L3 template source.
- Package-first generation is still the default.
- `pi-extensions` root now owns more of the `engineering-core` review/validation policy surface.
- Template outputs currently still include engineering-core artifacts such as:
  - `docs/engineering.local.md`
  - `policy/engineering-lane.json`
- the next review should decide whether the **reduced form** is better for package-shaped outputs:
  - root repo (`pi-extensions`) keeps the policy/validation stance
  - generated package templates emit only the local override file needed for repo-specific divergence
- this decision is **not** done yet and should not be applied blindly without checking review/validation consequences.
- session/handoff prompt surfaces also need to stay in scope during this review:
  - `copier-template/next_session_prompt.md.jinja`
  - `copier-template-monorepo-package/next_session_prompt.md.jinja`
  - `~/ai-society/softwareco/owned/pi-extensions/packages/pi-prompt-template-accelerator/prompts/one-line-handoff.md`
  - `~/ai-society/softwareco/owned/pi-extensions/packages/pi-prompt-template-accelerator/prompts/one-sentence-handoff.md`
- `pi-vault-client` phase-1 Nunjucks support is implemented separately; only live verification remains there.

## First review surfaces

1. `next_session_prompt.md`
2. `README.md`
3. `copier-template/docs/engineering.local.md`
4. `copier-template/policy/engineering-lane.json`
5. `copier-template/scripts/validate-structure.sh`
6. `copier-template/scripts/validate-structure.mjs`
7. `copier-template-monorepo-package/docs/engineering.local.md`
8. `copier-template-monorepo-package/policy/engineering-lane.json`
9. `copier-template-monorepo-package/scripts/validate-structure.sh`
10. `copier-template-monorepo-package/scripts/validate-structure.mjs`
11. `copier-template/next_session_prompt.md.jinja`
12. `copier-template-monorepo-package/next_session_prompt.md.jinja`
13. `~/ai-society/softwareco/owned/pi-extensions/next_session_prompt.md`

## Continue with

1. Review the `engineering-core` boundary between:
   - root policy in `pi-extensions`
   - local override files in generated repos/packages
2. Decide whether package-shaped templates should move to the reduced form:
   - keep `docs/engineering.local.md`
   - drop `policy/engineering-lane.json` from template output if the policy truly belongs upstream
   - only do this if validation/review surfaces remain coherent
3. Review handoff/session-prompt implications before changing template output:
   - generic `NEXT_SESSION_PROMPT` templates
   - `one-line-handoff` / `one-sentence-handoff` prompt surfaces
4. Keep `pi-vault-client` Nunjucks verification separate:
   - if you need to verify live rendering behavior, route back to `packages/pi-vault-client/next_session_prompt.md`

## Must-pass checks

```bash
cd ~/ai-society/softwareco/owned/pi-extensions-template
npm run check
npm run check:full
npm run release:check:quick
./scripts/ci/smoke.sh
./scripts/ci/full.sh
```
