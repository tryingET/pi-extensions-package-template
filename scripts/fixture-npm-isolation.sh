#!/usr/bin/env bash

# Fixture-only npm boundary. Source this file, prepare after Copier creates the
# fixture, and remove the project config before recording an idempotency baseline.

fixture_npm_isolation_prepare() {
  local fixture_root="$1"
  local scratch_root="$2"
  local managed_tmpdir="${TMPDIR:?TMPDIR must identify managed scratch}"

  fixture_root="$(cd "$fixture_root" && pwd)"
  mkdir -p "$scratch_root"
  scratch_root="$(cd "$scratch_root" && pwd)"
  managed_tmpdir="$(cd "$managed_tmpdir" && pwd)"

  case "$scratch_root/" in
    "$managed_tmpdir"/*) ;;
    *)
      echo "npm fixture scratch must stay under managed TMPDIR: $managed_tmpdir" >&2
      return 1
      ;;
  esac

  if [[ -e "$fixture_root/.npmrc" ]]; then
    echo "Refusing to replace existing fixture npm config: $fixture_root/.npmrc" >&2
    return 1
  fi

  FIXTURE_NPM_ROOT="$fixture_root"
  FIXTURE_NPM_STATE="$scratch_root/npm-isolation"
  FIXTURE_NPM_HOME="$FIXTURE_NPM_STATE/home"
  FIXTURE_NPM_CACHE="$FIXTURE_NPM_STATE/cache"
  FIXTURE_NPM_USERCONFIG="$FIXTURE_NPM_STATE/user.npmrc"
  FIXTURE_NPM_GLOBALCONFIG="$FIXTURE_NPM_STATE/global.npmrc"

  mkdir -p "$FIXTURE_NPM_HOME" "$FIXTURE_NPM_CACHE"
  : >"$FIXTURE_NPM_USERCONFIG"
  : >"$FIXTURE_NPM_GLOBALCONFIG"
  cat >"$FIXTURE_NPM_ROOT/.npmrc" <<'NPMRC'
# Managed by pi-extensions-template fixture isolation; never generated.
min-release-age=0
NPMRC
  export FIXTURE_NPM_ROOT FIXTURE_NPM_STATE FIXTURE_NPM_HOME FIXTURE_NPM_CACHE
  export FIXTURE_NPM_USERCONFIG FIXTURE_NPM_GLOBALCONFIG
}

fixture_npm_isolation_run() {
  local fixture_root="$1"
  shift
  fixture_root="$(cd "$fixture_root" && pwd)"

  if [[ -z "${FIXTURE_NPM_ROOT:-}" || "$fixture_root" != "$FIXTURE_NPM_ROOT" ]]; then
    echo "npm fixture isolation is not prepared for: $fixture_root" >&2
    return 1
  fi

  (
    cd "$fixture_root"
    env -i \
      HOME="$FIXTURE_NPM_HOME" \
      PATH="$PATH" \
      TMPDIR="$FIXTURE_NPM_STATE" \
      USER="${USER:-fixture}" \
      LOGNAME="${LOGNAME:-fixture}" \
      SHELL="${SHELL:-/bin/sh}" \
      TERM="${TERM:-dumb}" \
      CI="${CI:-}" \
      NPM_CONFIG_USERCONFIG="$FIXTURE_NPM_USERCONFIG" \
      npm_config_userconfig="$FIXTURE_NPM_USERCONFIG" \
      NPM_CONFIG_GLOBALCONFIG="$FIXTURE_NPM_GLOBALCONFIG" \
      npm_config_globalconfig="$FIXTURE_NPM_GLOBALCONFIG" \
      NPM_CONFIG_CACHE="$FIXTURE_NPM_CACHE" \
      npm_config_cache="$FIXTURE_NPM_CACHE" \
      NPM_CONFIG_MIN_RELEASE_AGE=0 \
      npm_config_min_release_age=0 \
      "$@"
  )
}

fixture_npm_isolation_cleanup() {
  local fixture_root="$1"
  fixture_root="$(cd "$fixture_root" && pwd)"

  if [[ -z "${FIXTURE_NPM_ROOT:-}" || "$fixture_root" != "$FIXTURE_NPM_ROOT" ]]; then
    echo "npm fixture isolation is not prepared for: $fixture_root" >&2
    return 1
  fi
  if ! grep -q '^# Managed by pi-extensions-template fixture isolation; never generated\.$' "$fixture_root/.npmrc"; then
    echo "Refusing to remove unrecognized fixture npm config: $fixture_root/.npmrc" >&2
    return 1
  fi

  rm -f "$fixture_root/.npmrc"
  unset FIXTURE_NPM_ROOT FIXTURE_NPM_STATE FIXTURE_NPM_HOME FIXTURE_NPM_CACHE
  unset FIXTURE_NPM_USERCONFIG FIXTURE_NPM_GLOBALCONFIG
}
