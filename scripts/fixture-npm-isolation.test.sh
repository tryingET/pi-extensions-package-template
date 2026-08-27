#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=fixture-npm-isolation.sh
source "$ROOT_DIR/scripts/fixture-npm-isolation.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:?}/pi-template-npm-isolation.XXXXXX")"
FIXTURE_ROOT="$TEST_ROOT/fixture"
AMBIENT_HOME="$TEST_ROOT/ambient-home"
mkdir -p "$FIXTURE_ROOT" "$AMBIENT_HOME"
printf '{"name":"fixture-npm-isolation","version":"0.0.0"}\n' >"$FIXTURE_ROOT/package.json"
cat >"$AMBIENT_HOME/.npmrc" <<'NPMRC'
before=2030-01-01T00:00:00.000Z
min-release-age=7
//registry.npmjs.org/:_authToken=ambient-file-token
NPMRC
ambient_hash="$(sha256sum "$AMBIENT_HOME/.npmrc")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

export HOME="$AMBIENT_HOME"
export NPM_CONFIG_USERCONFIG="$AMBIENT_HOME/.npmrc"
export npm_config_before="2030-01-01T00:00:00.000Z"
export NPM_CONFIG_MIN_RELEASE_AGE=7
export NODE_AUTH_TOKEN="ambient-node-token"
export NPM_TOKEN="ambient-npm-token"
export GITHUB_TOKEN="ambient-github-token"
export GH_TOKEN="ambient-gh-token"
export NPM_CONFIG__AUTH="ambient-basic-token"
export npm_config_auth_token="ambient-config-token"

fixture_npm_isolation_prepare "$FIXTURE_ROOT" "$TEST_ROOT/managed"

fixture_npm_isolation_run "$FIXTURE_ROOT" node -e '
  const assert = require("node:assert/strict");
  assert.equal(process.env.NPM_CONFIG_BEFORE, undefined);
  assert.equal(process.env.npm_config_before, undefined);
  assert.equal(process.env.NPM_CONFIG_MIN_RELEASE_AGE, "0");
  assert.equal(process.env.npm_config_min_release_age, "0");
  for (const name of [
    "NODE_AUTH_TOKEN",
    "NPM_TOKEN",
    "GITHUB_TOKEN",
    "GH_TOKEN",
    "NPM_CONFIG__AUTH",
    "npm_config_auth_token",
  ]) assert.equal(process.env[name], undefined);
  assert.ok(process.env.HOME.endsWith("/managed/npm-isolation/home"));
  assert.ok(process.env.NPM_CONFIG_USERCONFIG.endsWith("/managed/npm-isolation/user.npmrc"));
  assert.ok(process.env.NPM_CONFIG_GLOBALCONFIG.endsWith("/managed/npm-isolation/global.npmrc"));
'

[[ "$(fixture_npm_isolation_run "$FIXTURE_ROOT" npm config get min-release-age)" == "0" ]]
[[ "$(fixture_npm_isolation_run "$FIXTURE_ROOT" npm config get before)" == "null" ]]
[[ ! -s "$FIXTURE_NPM_USERCONFIG" ]]
[[ ! -s "$FIXTURE_NPM_GLOBALCONFIG" ]]
[[ ! -e "$FIXTURE_NPM_HOME/.npmrc" ]]
! grep -Eq 'authToken|ambient|before=2030|min-release-age=7' "$FIXTURE_ROOT/.npmrc"

printf '\n' >>"$FIXTURE_ROOT/.npmrc"
if fixture_npm_isolation_cleanup "$FIXTURE_ROOT" 2>/dev/null; then
  echo "fixture npm cleanup accepted trailing-byte drift" >&2
  exit 1
fi
cat >"$FIXTURE_ROOT/.npmrc" <<'NPMRC'
# Managed by pi-extensions-template fixture isolation; never generated.
min-release-age=0
NPMRC

printf '# unexpected drift\n' >>"$FIXTURE_ROOT/.npmrc"
if fixture_npm_isolation_cleanup "$FIXTURE_ROOT" 2>/dev/null; then
  echo "fixture npm cleanup accepted modified config" >&2
  exit 1
fi
cat >"$FIXTURE_ROOT/.npmrc" <<'NPMRC'
# Managed by pi-extensions-template fixture isolation; never generated.
min-release-age=0
NPMRC
fixture_npm_isolation_cleanup "$FIXTURE_ROOT"
[[ ! -e "$FIXTURE_ROOT/.npmrc" ]]
[[ "$(sha256sum "$AMBIENT_HOME/.npmrc")" == "$ambient_hash" ]]

echo "Fixture npm isolation regression passed."
