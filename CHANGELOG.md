---
summary: "Change log for pi-extensions-template."
read_when:
  - "Reviewing template history or release changes."
type: "reference"
---

# Changelog

> Repository/package identity is transitioning to `tryingET/pi-extensions-package-template` / `@tryinget/pi-extensions-package-template`.
> Historical entries before that transition still reference `pi-extensions-template_copier`.


## [0.6.0](https://github.com/tryingET/pi-extensions-package-template/compare/v0.5.1...v0.6.0) (2026-08-27)


### Features

* adopt engineering-core package contract ([6abc591](https://github.com/tryingET/pi-extensions-package-template/commit/6abc59190aea6ca6821f41d5dbf789f102cc008a))
* **template:** adopt simple-package as canonical scaffold mode ([7931a87](https://github.com/tryingET/pi-extensions-package-template/commit/7931a876e01a7240e21b808a5f32da9e127c01ac))
* **template:** enforce canonical Pi host baseline ([1b735fd](https://github.com/tryingET/pi-extensions-package-template/commit/1b735fdaff8d3a3cdc3f855c4b8f4a42c0b2cc3f))
* **template:** rename package template identity ([9147080](https://github.com/tryingET/pi-extensions-package-template/commit/9147080fd580c1a7bfae987605eb47027425f102))
* **template:** restore l3 lineage and package-first docs ([101acb7](https://github.com/tryingET/pi-extensions-package-template/commit/101acb7d0decb02959d62919b65108eabe2c7cdb))


### Bug Fixes

* **ci:** provide managed template guardrail scratch ([fa3e10d](https://github.com/tryingET/pi-extensions-package-template/commit/fa3e10dd5586c3d882253b073b634f12c84b02b5))
* **ci:** scope runner temp to guardrail step ([8bcc39a](https://github.com/tryingET/pi-extensions-package-template/commit/8bcc39a85a62b6b8dc4b96e5879f79b4e97d8192))
* **ci:** support isolated monorepo package gate validation ([4ae4d04](https://github.com/tryingET/pi-extensions-package-template/commit/4ae4d041da0dcfe3a34361e31588e44da35db69f))
* **release:** harden generated package validation ([75a19ca](https://github.com/tryingET/pi-extensions-package-template/commit/75a19ca9262fce7ca271c611085c4be124fc7da8))
* **release:** use current Pi ownership and isolation ([6d385a3](https://github.com/tryingET/pi-extensions-package-template/commit/6d385a36a62f1df4d37371184a4374348b13ab1b))
* **test:** compare fixture npm config byte-exactly ([b551ac7](https://github.com/tryingET/pi-extensions-package-template/commit/b551ac71a35169b835350b8731ab1d0d9bdbe799))

## [0.5.1](https://github.com/tryingET/pi-extensions-template_copier/compare/v0.5.0...v0.5.1) (2026-02-27)

### Bug Fixes

* **ci:** support isolated monorepo package gate validation ([4ae4d04](https://github.com/tryingET/pi-extensions-template_copier/commit/4ae4d04))

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
* **template:** extract validation to mjs and add legacy live-link helper symlink mode
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
