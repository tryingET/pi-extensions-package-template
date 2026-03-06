# Justfile for pi-extensions-template_copier
# Run `just` to list available recipes.

_default:
    @just --list

# ============================================================================
# Quality Gates
# ============================================================================

# Fast template guardrails (pre-commit baseline)
check:
    npm run check

# Full validation suite (guardrails + smoke + contract + idempotency)
check-full:
    npm run check:full

# Check pinned dependencies
check-pinned:
    npm run check:pinned

# ============================================================================
# Release
# ============================================================================

# Full release preflight (run before publishing)
release-check:
    npm run release:check

# Quick release preflight (skip copier smoke)
release-check-quick:
    npm run release:check:quick

# ============================================================================
# Template Generation
# ============================================================================

# Generate a new extension repo (positional: repo-name [command-name])
new repo-name command-name="":
    #!/usr/bin/env bash
    set -euo pipefail
    args=("$repo-name")
    if [[ -n "{{ command-name }}" ]]; then
        args+=("{{ command-name }}")
    fi
    bash ./new-pi-extension-repo.sh "${args[@]}"

# Generate with explicit target directory
new-at repo-name target-dir command-name="":
    #!/usr/bin/env bash
    set -euo pipefail
    args=("--target-dir" "{{ target-dir }}" "$repo-name")
    if [[ -n "{{ command-name }}" ]]; then
        args+=("{{ command-name }}")
    fi
    node ./bin/new-pi-extension-repo.mjs "${args[@]}"

# Smoke test: generate to temp dir
smoke:
    bash ./scripts/smoke-test-template.sh

# Contract test: validate generated repo structure
contract:
    bash ./scripts/generated-contract-test.sh

# Idempotency test: update/recopy should not change repo
idempotency:
    bash ./scripts/idempotency-test-template.sh

# ============================================================================
# Repo Updates (generated repos)
# ============================================================================

# Update all generated repos under ~/programming/pi-extensions (dry-run)
update-dry ref:
    bash ./scripts/update-generated-repos.sh --ref {{ ref }} --dry-run

# Update all generated repos with pre/post commits
update ref:
    bash ./scripts/update-generated-repos.sh --ref {{ ref }} --pre-commit --post-commit

# Update with parallel workers (requires GNU parallel)
update-parallel ref workers="4":
    bash ./scripts/update-generated-repos.sh --ref {{ ref }} --pre-commit --post-commit --parallel {{ workers }}

# Update from local HEAD (for testing)
update-head:
    bash ./scripts/update-generated-repos.sh --ref HEAD --pre-commit --post-commit

# ============================================================================
# Git Hooks
# ============================================================================

# Install local pre-commit guardrails
install-hooks:
    bash ./scripts/install-hooks.sh

# ============================================================================
# Code Metadata
# ============================================================================

# List code files with top-level metadata comments
code-list *args:
    node ./scripts/code-list.mjs {{ args }}

# JSON output
code-list-json:
    node ./scripts/code-list.mjs --json

# Strict mode (fail on files without metadata)
code-list-strict:
    node ./scripts/code-list.mjs --strict

# ============================================================================
# NPM Publishing
# ============================================================================

# Bootstrap publish for a new package (positional: project-path)
bootstrap-publish project:
    node ./bin/npm-bootstrap-publish.mjs --project {{ project }}

# Bootstrap publish with 1Password token reference
bootstrap-publish-op project op-ref:
    node ./bin/npm-bootstrap-publish.mjs --project {{ project }} --op {{ op-ref }}

# ============================================================================
# Info
# ============================================================================

# Show current version
version:
    @node -p "JSON.parse(require('node:fs').readFileSync('package.json', 'utf8')).version"

# Show package name
name:
    @node -p "JSON.parse(require('node:fs').readFileSync('package.json', 'utf8')).name"

# Show all npm scripts
scripts:
    @node -e "const pkg = require('./package.json'); Object.entries(pkg.scripts || {}).forEach(([k, v]) => console.log(k + ':', v))"
