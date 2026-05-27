---
summary: "Repo-local engineering-core adoption for pi-extensions-template."
read_when:
  - "You are selecting engineering lanes, disciplines, or validation evidence for pi-extensions-template work."
  - "You need repo-local deviations from shared engineering-core guidance."
type: "reference"
---

# pi-extensions-template engineering guidance

## Upstream owner

Shared engineering lane and discipline guidance comes from `/home/tryinget/ai-society/core/engineering-core`.
This file records the repo-local selected subset for pi-extensions-template, a template repo for Pi extension packages. The repo `AGENTS.md` remains the operating authority for repo-specific workflow, source-owner boundaries, and read order.

Machine-readable selection lives in `policy/engineering-lane.json`.

## Selected lanes

- `pi-ts`

```bash
uv tool -n run --from ~/ai-society/core/engineering-core engineering-core show pi-ts
```

## Selected disciplines

- `validation`
- `testing`
- `security-privacy`
- `documentation`
- `dependency-governance`
- `specification-and-dsls`
- `engineering-reasoning`

Catalog/list commands:

```bash
uv tool -n run --from ~/ai-society/core/engineering-core engineering-core catalog --pretty
uv tool -n run --from ~/ai-society/core/engineering-core engineering-core list-disciplines
uv tool -n run --from ~/ai-society/core/engineering-core engineering-core list-templates
```

## Repo-local deviations and emphasis

- Prefer repo-local deterministic wrappers, workspace commands, `Justfile` targets, and package/app-local scripts over ad-hoc commands.
- Keep package/app-local validation and release behavior in the owning package or app surface.
- Treat this file as a selector and override note, not a replacement for `AGENTS.md` or runtime task/evidence authority.
- When local practice intentionally diverges from engineering-core guidance, record the reason here or in the owning project/decision document.

## Canonical local commands

- `npm run check`
- `npm test`
- `npm run build`

## Repo loop validation

pi-extensions-template adopts `repo-loop-validation-v1` for Pi extension template maintenance loops. The machine-readable declaration lives in `policy/engineering-lane.json`.

- `loop-doctor`: `just loop-doctor` (non-failing git/Node/npm/Just diagnostics)
- `loop-verify-fast`: `just loop-verify-fast` (maps to `just check` / template guardrails)
- `loop-impact-plan`: `just loop-impact-plan` (changed-file listing plus run/wide recommendation)
- `loop-impact-run`: `just loop-impact-run` (maps to `just check`)
- `loop-impact-wide`: `just loop-impact-wide` (maps to `just check-full`)
- `loop-landing-check`: `just loop-landing-check` (maps to the repo-declared `just check-full` gate)

These commands produce repo-local evidence for loop orchestration. They do not replace AK task/evidence/decision authority, template propagation approval, release approval, package publication authority, or downstream generated-repo adoption authority.

## Validation evidence expectations

For engineering-core adoption metadata changes:

```bash
python -m json.tool policy/engineering-lane.json >/tmp/pi-extensions-template-engineering-lane.json
node /home/tryinget/ai-society/core/agent-scripts/scripts/docs-list.mjs --docs . --strict
```

For code/runtime changes, follow `AGENTS.md` and run the smallest truthful local validation command for the touched surface.
