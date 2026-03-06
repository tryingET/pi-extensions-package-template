#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_SRC="${1:-$ROOT_DIR}"
REPO_NAME="${SMOKE_REPO_NAME:-template-smoke}"
COMMAND_NAME="${SMOKE_COMMAND_NAME:-template-smoke}"
NPM_ORG="${SMOKE_NPM_ORG:-tryinget}"
SCAFFOLD_MODE="${SCAFFOLD_MODE:-standalone-repo}"
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

if [[ "$SCAFFOLD_MODE" != "standalone-repo" && "$SCAFFOLD_MODE" != "monorepo-package" ]]; then
  echo "Invalid SCAFFOLD_MODE: $SCAFFOLD_MODE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
DEST_DIR="$TMP_DIR/$REPO_NAME"

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

(
  cd "$DEST_DIR"

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

if (expectedMode === "monorepo-package") {
  if (fs.existsSync(".github")) {
    fail("monorepo-package mode must not generate .github directory");
  }
  if (fs.existsSync(".githooks")) {
    fail("monorepo-package mode must not generate .githooks directory");
  }
  if (pkg.repository?.directory !== expectedWorkspacePath) {
    fail(`package.json repository.directory mismatch: expected ${expectedWorkspacePath}, got ${pkg.repository?.directory}`);
  }

  const meta = pkg["x-pi-template"];
  if (!meta) {
    fail("package.json missing x-pi-template metadata");
  } else {
    if (meta.scaffoldMode !== "monorepo-package") {
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
    npm ci
  else
    npm install --package-lock-only --ignore-scripts
    npm ci
  fi

  npm run check
)

echo "Smoke test passed: $DEST_DIR"
