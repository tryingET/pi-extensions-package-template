#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${TMPDIR:-}" ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" && -n "${RUNNER_TEMP:-}" && -d "${RUNNER_TEMP:-}" ]]; then
    TMPDIR="$RUNNER_TEMP"
  else
    echo "TMPDIR must point to managed disk-backed scratch storage." >&2
    exit 1
  fi
fi
if [[ ! -d "$TMPDIR" ]]; then
  echo "TMPDIR does not exist: $TMPDIR" >&2
  exit 1
fi
TMPDIR_RESOLVED="$(node -e 'console.log(require("node:fs").realpathSync(process.argv[1]))' "$TMPDIR")"
if [[ "$TMPDIR_RESOLVED" == "/tmp" || "$TMPDIR_RESOLVED" == /tmp/* ]]; then
  echo "TMPDIR must not use /tmp: $TMPDIR" >&2
  exit 1
fi
export TMPDIR
export TMP="$TMPDIR"
export TEMP="$TMPDIR"

NAME="$(node -p "JSON.parse(require('node:fs').readFileSync('package.json', 'utf8')).name")"
VERSION="$(node -p "JSON.parse(require('node:fs').readFileSync('package.json', 'utf8')).version")"
REPOSITORY_URL="$(node -p "(() => { const pkg = JSON.parse(require('node:fs').readFileSync('package.json', 'utf8')); const repo = pkg.repository; if (typeof repo === 'string') return repo.trim(); if (repo && typeof repo === 'object' && typeof repo.url === 'string') return repo.url.trim(); return ''; })()")"

echo "== template release-check: ${NAME}@${VERSION}"

if [[ -z "$REPOSITORY_URL" ]]; then
  echo "package.json repository.url is required for provenance release publishing." >&2
  exit 1
fi

if [[ "$NAME" != "${NAME,,}" ]]; then
  echo "Invalid npm package name: must be lowercase: $NAME" >&2
  exit 1
fi

echo "== npm pack --dry-run --json"
PACK_JSON="$(npm pack --dry-run --json)"
echo "$PACK_JSON"
PACK_JSON="$(printf '%s' "$PACK_JSON" | node "$ROOT_DIR/scripts/npm-pack-json.mjs")"

PACK_JSON="$PACK_JSON" node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const normalize = (value) => value.replace(/^\.\//, "").replace(/\\/g, "/");

const fail = (msg) => {
  console.error(msg);
  process.exit(1);
};

const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
const filesEntries = Array.isArray(pkg.files)
  ? pkg.files.map((entry) => normalize(String(entry).trim())).filter(Boolean)
  : [];

if (filesEntries.length === 0) {
  fail("package.json must define a non-empty files array for deterministic publish artifacts.");
}

const expectedExact = new Set(["package.json", "copier.yml"]);
const expectedDirPrefixes = [];
const expectedPatternPrefixes = [];

const binEntries =
  typeof pkg.bin === "string"
    ? [normalize(pkg.bin)]
    : pkg.bin && typeof pkg.bin === "object"
      ? Object.values(pkg.bin).map((entry) => normalize(String(entry)))
      : [];
for (const entry of binEntries) expectedExact.add(entry);

for (const entry of filesEntries) {
  if (/[*?\[]/.test(entry)) {
    const prefix = normalize(entry.split(/[*?\[]/, 1)[0]);
    if (!prefix) {
      fail(`Unsupported files[] wildcard entry without prefix: ${entry}`);
    }
    expectedPatternPrefixes.push(prefix);
    continue;
  }

  const fullPath = path.resolve(entry);
  if (!fs.existsSync(fullPath)) {
    fail(`files[] entry does not exist: ${entry}`);
  }

  const stat = fs.statSync(fullPath);
  if (stat.isDirectory()) {
    const prefix = entry.endsWith("/") ? entry : `${entry}/`;
    expectedDirPrefixes.push(prefix);
  } else {
    expectedExact.add(entry);
  }
}

const pack = JSON.parse(process.env.PACK_JSON || "[]");
if (!Array.isArray(pack) || pack.length !== 1 || !pack[0] || !Array.isArray(pack[0].files)) {
  fail("Could not parse normalized npm pack --dry-run --json output.");
}
if (pack[0].name !== pkg.name || pack[0].version !== pkg.version) {
  fail(
    `Packed identity mismatch: expected ${pkg.name}@${pkg.version}, got ${pack[0].name}@${pack[0].version}`,
  );
}

const actual = pack[0].files.map((f) => normalize(String(f.path || ""))).filter(Boolean).sort();
const actualSet = new Set(actual);

const allowByAlwaysIncluded = (filePath) => {
  return (
    /^README(?:\.[^/]+)?$/i.test(filePath) ||
    /^LICENSE(?:\.[^/]+)?$/i.test(filePath) ||
    /^NOTICE(?:\.[^/]+)?$/i.test(filePath)
  );
};

const missing = [];
for (const filePath of expectedExact) {
  if (!actualSet.has(filePath)) {
    missing.push(filePath);
  }
}
for (const prefix of expectedDirPrefixes) {
  if (!actual.some((filePath) => filePath.startsWith(prefix))) {
    missing.push(`${prefix}*`);
  }
}
for (const prefix of expectedPatternPrefixes) {
  if (!actual.some((filePath) => filePath.startsWith(prefix))) {
    missing.push(`${prefix}*`);
  }
}

const extra = actual.filter((filePath) => {
  if (expectedExact.has(filePath)) return false;
  if (expectedDirPrefixes.some((prefix) => filePath.startsWith(prefix))) return false;
  if (expectedPatternPrefixes.some((prefix) => filePath.startsWith(prefix))) return false;
  if (allowByAlwaysIncluded(filePath)) return false;
  return true;
});

if (missing.length || extra.length) {
  console.error("Publish file whitelist mismatch.");
  if (missing.length) console.error(`Missing: ${missing.join(", ")}`);
  if (extra.length) console.error(`Extra: ${extra.join(", ")}`);
  process.exit(1);
}

console.log(`File whitelist OK (${actual.length} files).`);
NODE

echo "== npm publish --dry-run"
set +e
PUBLISH_DRY_RUN_OUTPUT="$(npm publish --dry-run 2>&1)"
PUBLISH_DRY_RUN_EXIT=$?
set -e
echo "$PUBLISH_DRY_RUN_OUTPUT"
if [[ "$PUBLISH_DRY_RUN_EXIT" -ne 0 ]]; then
  if grep -qiE "You cannot publish over the previously published versions|previously published version .* is higher than the new version" <<<"$PUBLISH_DRY_RUN_OUTPUT"; then
    echo "npm publish --dry-run hit registry version guard (${VERSION}); continuing."
  else
    echo "npm publish --dry-run failed." >&2
    exit "$PUBLISH_DRY_RUN_EXIT"
  fi
fi

TMP_DIR=""
TARBALL_PATH=""
cleanup() {
  if [[ "${KEEP_RELEASE_ARTIFACTS:-0}" != "1" ]]; then
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
      rm -rf "$TMP_DIR"
    fi
    if [[ -n "$TARBALL_PATH" && -f "$TARBALL_PATH" ]]; then
      rm -f "$TARBALL_PATH"
    fi
  fi
}
trap cleanup EXIT

install_generated_repo_deps() {
  local repo_dir="$1"
  (
    cd "$repo_dir"
    if [[ -f package-lock.json ]]; then
      npm ci
    else
      npm install --package-lock-only --ignore-scripts
      npm ci
    fi
  )
}

resolve_pi_extensions_root() {
  local configured_root="${PI_EXTENSIONS_ROOT:-}"
  local sibling_root="$ROOT_DIR/../pi-extensions"
  local canonical_root="$HOME/ai-society/softwareco/owned/pi-extensions"
  for candidate in "$configured_root" "$sibling_root" "$canonical_root"; do
    if [[ -n "$candidate" && -x "$candidate/scripts/package-quality-gate.sh" ]]; then
      (cd "$candidate" && pwd)
      return 0
    fi
  done
  echo "full simple-package release smoke requires a pi-extensions owner checkout; set PI_EXTENSIONS_ROOT to its pinned path" >&2
  return 1
}

prepare_monorepo_host() {
  local host_root="$1"
  local owner_root="$2"
  mkdir -p "$host_root/scripts" "$host_root/packages/pi-eval-kernel/scripts"
  for support_script in \
    package-quality-gate.sh \
    file-budget-audit.mjs \
    validate-local-package-links.mjs \
    npm-pack-json.mjs; do
    cp "$owner_root/scripts/$support_script" "$host_root/scripts/$support_script"
  done
  cp \
    "$owner_root/packages/pi-eval-kernel/scripts/npm-pack-json.mjs" \
    "$host_root/packages/pi-eval-kernel/scripts/npm-pack-json.mjs"
  chmod +x "$host_root/scripts/package-quality-gate.sh"
  git -C "$host_root" init -q
}

assert_generated_release_config_mode() {
  local repo_dir="$1"
  local expected_mode="$2"
  (
    cd "$repo_dir"
    node - "$expected_mode" <<'NODE'
const fs = require("node:fs");
const expectedMode = process.argv[2];
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
const answers = fs.readFileSync(".copier-answers.yml", "utf8");
const actualMode = pkg["x-pi-template"]?.releaseConfigMode;
if (actualMode !== expectedMode) {
  console.error(`Expected x-pi-template.releaseConfigMode=${expectedMode}, got ${actualMode}`);
  process.exit(1);
}
const escaped = expectedMode.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const answerPattern = new RegExp(`^release_config_mode:\\s*['\"]?${escaped}['\"]?\\s*$`, "m");
if (!answerPattern.test(answers)) {
  console.error(`Expected .copier-answers.yml release_config_mode=${expectedMode}`);
  process.exit(1);
}
NODE
  )
}

echo "== npm pack"
TARBALL="$(npm pack --silent | tail -n 1)"
TARBALL_PATH="$ROOT_DIR/$TARBALL"
echo "Tarball: $TARBALL_PATH"

echo "== CLI help smoke"
node ./bin/new-pi-extension-repo.mjs --help >/dev/null

if [[ "${SKIP_COPIER_SMOKE:-0}" == "1" ]]; then
  echo "Skipping copier smoke tests (SKIP_COPIER_SMOKE=1)."
else
  if ! command -v copier >/dev/null 2>&1; then
    echo "copier is required for full release checks." >&2
    echo "Tip: set SKIP_COPIER_SMOKE=1 for artifact-only checks." >&2
    exit 1
  fi

  TMP_DIR="$(mktemp -d "$TMPDIR/pi-template-release-check.XXXXXX")"

  echo "== local CLI generation smoke"
  LOCAL_SMOKE_DIR="$TMP_DIR/local-cli-smoke"
  node ./bin/new-pi-extension-repo.mjs local-cli-smoke --target-dir "$LOCAL_SMOKE_DIR" --mode standalone-repo
  install_generated_repo_deps "$LOCAL_SMOKE_DIR"
  (
    cd "$LOCAL_SMOKE_DIR"
    npm run check
  )

  PI_EXTENSIONS_OWNER="$(resolve_pi_extensions_root)"

  echo "== local CLI simple-package generation smoke"
  LOCAL_MONO_HOST="$TMP_DIR/local-cli-monorepo-host"
  LOCAL_MONO_SMOKE_DIR="$LOCAL_MONO_HOST/packages/local-cli-monorepo-smoke"
  prepare_monorepo_host "$LOCAL_MONO_HOST" "$PI_EXTENSIONS_OWNER"
  node ./bin/new-pi-extension-repo.mjs local-cli-monorepo-smoke --target-dir "$LOCAL_MONO_SMOKE_DIR" --mode simple-package --workspace-path packages/local-cli-monorepo-smoke --release-component local-cli-monorepo-smoke --monorepo-repo pi-extensions
  assert_generated_release_config_mode "$LOCAL_MONO_SMOKE_DIR" component
  install_generated_repo_deps "$LOCAL_MONO_SMOKE_DIR"
  (
    cd "$LOCAL_MONO_SMOKE_DIR"
    PI_EXTENSIONS_TMPDIR="$TMP_DIR/local-cli-monorepo-gate" npm run check
  )

  if [[ "${SKIP_PACKAGED_CLI_SMOKE:-0}" != "1" ]]; then
    echo "== packaged CLI generation smoke (npm exec --package <tarball>)"
    PACKAGED_SMOKE_DIR="$TMP_DIR/packaged-cli-smoke"
    npm exec --yes --package "$TARBALL_PATH" -- new-pi-extension-repo packaged-cli-smoke --target-dir "$PACKAGED_SMOKE_DIR" --mode standalone-repo
    install_generated_repo_deps "$PACKAGED_SMOKE_DIR"
    (
      cd "$PACKAGED_SMOKE_DIR"
      npm run check
    )

    echo "== packaged CLI simple-package generation smoke"
    PACKAGED_MONO_HOST="$TMP_DIR/packaged-cli-monorepo-host"
    PACKAGED_MONO_SMOKE_DIR="$PACKAGED_MONO_HOST/packages/packaged-cli-monorepo-smoke"
    prepare_monorepo_host "$PACKAGED_MONO_HOST" "$PI_EXTENSIONS_OWNER"
    npm exec --yes --package "$TARBALL_PATH" -- new-pi-extension-repo packaged-cli-monorepo-smoke --target-dir "$PACKAGED_MONO_SMOKE_DIR" --mode simple-package --workspace-path packages/packaged-cli-monorepo-smoke --release-component packaged-cli-monorepo-smoke --monorepo-repo pi-extensions
    assert_generated_release_config_mode "$PACKAGED_MONO_SMOKE_DIR" component
    install_generated_repo_deps "$PACKAGED_MONO_SMOKE_DIR"
    (
      cd "$PACKAGED_MONO_SMOKE_DIR"
      PI_EXTENSIONS_TMPDIR="$TMP_DIR/packaged-cli-monorepo-gate" npm run check
    )
  fi
fi

echo "== npm view ${NAME} version (pre-publish may be 404)"
set +e
npm view "$NAME" version --json --registry https://registry.npmjs.org/
VIEW_EXIT=$?
set -e
echo "npm view exit: $VIEW_EXIT"
if [[ "$VIEW_EXIT" -ne 0 ]]; then
  echo "Package likely not published yet (expected for first release)."
fi

echo "template release-check done"
