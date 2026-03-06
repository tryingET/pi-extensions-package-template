#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

chmod +x \
  .githooks/pre-commit \
  scripts/install-hooks.sh \
  scripts/template-guardrails.sh \
  scripts/smoke-test-template.sh \
  scripts/generated-contract-test.sh \
  scripts/idempotency-test-template.sh

git config core.hooksPath .githooks

echo "Installed git hooks path: .githooks"
