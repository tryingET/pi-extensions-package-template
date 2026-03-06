# Changelog

## [0.5.0](https://github.com/tryingET/pi-extensions-template_copier/compare/v0.4.0...v0.5.0) (2026-02-27)


### Features

* use scoped package names by default ([ebf583c](https://github.com/tryingET/pi-extensions-template_copier/commit/ebf583c3b399c72c5a20e7614d7e004b62a14a0a))


### Bug Fixes

* **smoke:** validate scoped package names in generated repos ([a7b4e4f](https://github.com/tryingET/pi-extensions-template_copier/commit/a7b4e4fc0fe0b49719c12968f47840e021984e07))

## [0.4.0](https://github.com/tryingET/pi-extensions-template_copier/compare/v0.3.0...v0.4.0) (2026-02-26)

**Note:** Intake/interview scaffolding was **removed** in this release, not migrated. Previous commits mentioning "migrate" were superseded by removal commits.

### Features

* **tooling:** add justfile for template maintenance tasks
* **tooling:** add update-generated-repos.sh for batch template sync
* **template:** make release-check.sh test settings configurable
* **template:** convert CODEOWNERS to jinja template
* **template:** extract validation to mjs and add sync-to-live symlink mode
* add pinned dependency update checker

### Changes

* **template:** remove startup intake workflow from scaffold (simplified)
* **cli:** remove intake options from generator wrappers
* **docs:** consolidate next_steps into NEXT_SESSION_PROMPT
* **validation:** remove unused docs scaffolding (skills, goals, status, plans)
* **validation:** simplify required structure for generated repos

### Fixes

* **scripts:** pre-commit only validates staged files
* **update:** add --overwrite to recopy for conflict resolution

## [0.3.0](https://github.com/tryingET/pi-extensions-template_copier/compare/v0.2.1...v0.3.0) (2026-02-18)

### Features

* add context-aware intake scaffolding and security dependency updates
* **template:** add context-aware startup intake scaffolding

### Bug Fixes

* **security:** pin fast-xml-parser and add dependabot

### Maintenance

* update GitHub Actions majors to `actions/checkout@v6`, `actions/setup-node@v6`, `actions/setup-python@v6`, and `actions/upload-artifact@v6` across root/template workflows
* set `package-manager-cache: false` for `setup-node@v6`, document self-hosted runner requirement (`>=2.327.1`)

## [0.2.1](https://github.com/tryingET/pi-extensions-template_copier/compare/v0.2.0...v0.2.1) (2026-02-18)

### Bug Fixes

* **release:** add provenance-safe repository metadata

## [0.2.0](https://github.com/tryingET/pi-extensions-template_copier/compare/v0.1.0...v0.2.0) (2026-02-18)

### Features

* **scaffold:** add release-check baseline for generated repos
* **template:** add npm bootstrap publish helper
* **template:** add npm release automation for template package
* **template:** add profile-driven intake scaffolding
* **template:** add root vouch/issue templates and maintainer seeding
* **template:** add TS quality gate lane baseline
* **template:** harden biome-first scaffold defaults
* **template:** package live-sync extension layout
* **template:** run node tests in generated quality gate

### Bug Fixes

* **release:** stabilize release-check after first publish
* **template:** default local scaffolding to HEAD for path2 knobs
