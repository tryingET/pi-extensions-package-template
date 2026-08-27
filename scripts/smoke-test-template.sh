#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=fixture-npm-isolation.sh
source "$ROOT_DIR/scripts/fixture-npm-isolation.sh"
TEMPLATE_SRC="${1:-$ROOT_DIR}"
REPO_NAME="${SMOKE_REPO_NAME:-template-smoke}"
COMMAND_NAME="${SMOKE_COMMAND_NAME:-template-smoke}"
NPM_ORG="${SMOKE_NPM_ORG:-tryinget}"
RAW_SCAFFOLD_MODE="${SCAFFOLD_MODE:-standalone-repo}"
SCAFFOLD_MODE="$RAW_SCAFFOLD_MODE"
if [[ "$RAW_SCAFFOLD_MODE" == "monorepo-package" ]]; then
  SCAFFOLD_MODE="simple-package"
fi
WORKSPACE_RELATIVE_PATH="${WORKSPACE_RELATIVE_PATH:-packages/$REPO_NAME}"
RELEASE_COMPONENT_KEY="${RELEASE_COMPONENT_KEY:-$REPO_NAME}"
RELEASE_CONFIG_MODE="${RELEASE_CONFIG_MODE:-component}"
MONOREPO_REPO_NAME="${MONOREPO_REPO_NAME:-pi-extensions}"
TEMPLATE_REF="${PI_TEMPLATE_REF:-HEAD}"

if ! command -v copier >/dev/null 2>&1; then
  echo "copier is required for smoke testing" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required for smoke testing" >&2
  exit 1
fi

if [[ "$RAW_SCAFFOLD_MODE" != "standalone-repo" && "$RAW_SCAFFOLD_MODE" != "monorepo-package" && "$RAW_SCAFFOLD_MODE" != "simple-package" ]]; then
  echo "Invalid SCAFFOLD_MODE: $RAW_SCAFFOLD_MODE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
DEST_DIR="$TMP_DIR/$REPO_NAME"

if [[ "$SCAFFOLD_MODE" == "simple-package" ]]; then
  configured_root="${PI_EXTENSIONS_ROOT:-}"
  sibling_root="$ROOT_DIR/../pi-extensions"
  canonical_root="$HOME/ai-society/softwareco/owned/pi-extensions"
  if [[ -n "$configured_root" && -x "$configured_root/scripts/package-quality-gate.sh" ]]; then
    PI_EXTENSIONS_ROOT="$(cd "$configured_root" && pwd)"
  elif [[ -x "$sibling_root/scripts/package-quality-gate.sh" ]]; then
    PI_EXTENSIONS_ROOT="$(cd "$sibling_root" && pwd)"
  elif [[ -x "$canonical_root/scripts/package-quality-gate.sh" ]]; then
    PI_EXTENSIONS_ROOT="$(cd "$canonical_root" && pwd)"
  else
    echo "simple-package smoke requires a pi-extensions owner checkout; set PI_EXTENSIONS_ROOT to its pinned path" >&2
    exit 1
  fi

  HOST_ROOT="$TMP_DIR/monorepo"
  DEST_DIR="$HOST_ROOT/$WORKSPACE_RELATIVE_PATH"
  mkdir -p \
    "$HOST_ROOT/scripts" \
    "$HOST_ROOT/packages/pi-eval-kernel/scripts" \
    "$(dirname "$DEST_DIR")"
  for support_script in \
    package-quality-gate.sh \
    file-budget-audit.mjs \
    validate-local-package-links.mjs \
    npm-pack-json.mjs; do
    cp "$PI_EXTENSIONS_ROOT/scripts/$support_script" "$HOST_ROOT/scripts/$support_script"
  done
  chmod +x "$HOST_ROOT/scripts/package-quality-gate.sh"
  cp \
    "$PI_EXTENSIONS_ROOT/packages/pi-eval-kernel/scripts/npm-pack-json.mjs" \
    "$HOST_ROOT/packages/pi-eval-kernel/scripts/npm-pack-json.mjs"
  git -C "$HOST_ROOT" init -q
fi

cleanup() {
  if [[ "${KEEP_SMOKE_DIR:-0}" == "1" ]]; then
    echo "Keeping smoke directory: $TMP_DIR"
  else
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

copier_args=(
  copy
  --trust
  --defaults
  -d "scaffold_mode=$SCAFFOLD_MODE"
  -d "repo_name=$REPO_NAME"
  -d "command_name=$COMMAND_NAME"
  -d "npm_org=$NPM_ORG"
  -d "workspace_relative_path=$WORKSPACE_RELATIVE_PATH"
  -d "release_component_key=$RELEASE_COMPONENT_KEY"
  -d "release_config_mode=$RELEASE_CONFIG_MODE"
  -d "monorepo_repo_name=$MONOREPO_REPO_NAME"
)

if [[ -n "$TEMPLATE_REF" ]]; then
  copier_args+=(--vcs-ref "$TEMPLATE_REF")
fi

copier "${copier_args[@]}" "$TEMPLATE_SRC" "$DEST_DIR"
fixture_npm_isolation_prepare "$DEST_DIR" "$TMP_DIR"

(
  cd "$DEST_DIR"

  if [[ "$SCAFFOLD_MODE" == "simple-package" ]]; then
    export PI_EXTENSIONS_TMPDIR="$TMP_DIR/gate-scratch"
  fi

  # Basic structure validation
  node - "$REPO_NAME" "$COMMAND_NAME" "$NPM_ORG" "$SCAFFOLD_MODE" "$WORKSPACE_RELATIVE_PATH" "$RELEASE_COMPONENT_KEY" "$RELEASE_CONFIG_MODE" <<'NODE'
const fs = require("node:fs");

const expectedRepoName = process.argv[2];
const expectedCommandName = process.argv[3];
const expectedNpmOrg = process.argv[4];
const expectedMode = process.argv[5];
const expectedWorkspacePath = process.argv[6];
const expectedReleaseComponent = process.argv[7];
const expectedReleaseConfigMode = process.argv[8];
const expectedPackageName = `@${expectedNpmOrg}/${expectedRepoName}`;
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
const answers = fs.readFileSync(".copier-answers.yml", "utf8");

const fail = (msg) => {
  console.error(msg);
  process.exit(1);
};

if (pkg.name !== expectedPackageName) {
  fail(`package.json name mismatch: expected ${expectedPackageName}, got ${pkg.name}`);
}

if (!pkg.pi?.extensions?.includes(`./extensions/${expectedCommandName}.ts`)) {
  fail(`package.json pi.extensions missing ./extensions/${expectedCommandName}.ts`);
}

const hasAnswer = (key, value) => {
  const escaped = String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`^${key}:\\s*['\"]?${escaped}['\"]?$`, "m");
  return pattern.test(answers);
};

for (const [key, value] of [
  ["repo_name", expectedRepoName],
  ["command_name", expectedCommandName],
  ["npm_org", expectedNpmOrg],
  ["scaffold_mode", expectedMode],
]) {
  if (!hasAnswer(key, value)) {
    fail(`.copier-answers.yml missing ${key}: ${value}`);
  }
}

if (expectedMode === "monorepo-package" || expectedMode === "simple-package") {
  if (fs.existsSync(".github")) {
    fail("simple-package mode must not generate .github directory");
  }
  if (fs.existsSync(".githooks")) {
    fail("simple-package mode must not generate .githooks directory");
  }
  if (pkg.repository?.directory !== expectedWorkspacePath) {
    fail(`package.json repository.directory mismatch: expected ${expectedWorkspacePath}, got ${pkg.repository?.directory}`);
  }

  const meta = pkg["x-pi-template"];
  if (!meta) {
    fail("package.json missing x-pi-template metadata");
  } else {
    if (meta.scaffoldMode !== "simple-package" && meta.scaffoldMode !== "monorepo-package") {
      fail(`x-pi-template.scaffoldMode mismatch: ${meta.scaffoldMode}`);
    }
    if (meta.workspacePath !== expectedWorkspacePath) {
      fail(`x-pi-template.workspacePath mismatch: expected ${expectedWorkspacePath}, got ${meta.workspacePath}`);
    }
    if (meta.releaseComponent !== expectedReleaseComponent) {
      fail(`x-pi-template.releaseComponent mismatch: expected ${expectedReleaseComponent}, got ${meta.releaseComponent}`);
    }
    if (meta.releaseConfigMode !== expectedReleaseConfigMode) {
      fail(`x-pi-template.releaseConfigMode mismatch: expected ${expectedReleaseConfigMode}, got ${meta.releaseConfigMode}`);
    }
  }
}

console.log("Structure validation passed");
NODE

  if [[ -f package-lock.json ]]; then
    fixture_npm_isolation_run "$DEST_DIR" npm ci
  else
    fixture_npm_isolation_run "$DEST_DIR" npm install --package-lock-only --ignore-scripts
    fixture_npm_isolation_run "$DEST_DIR" npm ci
  fi

  fixture_npm_isolation_run "$DEST_DIR" npm run check
)

echo "Smoke test passed: $DEST_DIR"
