#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
workspace_root_default="$(CDPATH= cd -- "$repo_root/../../.." && pwd)"
: "${ROCS_WORKSPACE_ROOT:=$workspace_root_default}"
: "${ROCS_WORKSPACE_REF_MODE:=loose}"
workspace_rocs_repo="${ROCS_CORE_PROJECT:-$ROCS_WORKSPACE_ROOT/core/rocs-cli}"

say() {
  printf '%s\n' "$*"
}

err() {
  printf '%s\n' "$*" >&2
}

die() {
  err "error: $*"
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

usage() {
  cat <<'EOF'
usage: scripts/rocs.sh [--doctor|--which|--help] [rocs args...]

Portable ROCS launcher with deterministic resolution order:
  1) ROCS_BIN override
  2) workspace core (ROCS_WORKSPACE_ROOT/core/rocs-cli or ROCS_CORE_PROJECT)
  3) rocs on PATH

Examples:
  ./scripts/rocs.sh version
  ./scripts/rocs.sh validate --repo .
  ./scripts/rocs.sh --doctor
  ./scripts/rocs.sh --which
EOF
}

select_runner() {
  if [ -n "${ROCS_BIN:-}" ]; then
    if [ -x "$ROCS_BIN" ] || command -v "$ROCS_BIN" >/dev/null 2>&1; then
      printf '%s\n' "rocs-bin"
      return
    fi
    printf '%s\n' "rocs-bin-missing"
    return
  fi

  if [ -x "$workspace_rocs_repo/.venv/bin/rocs" ]; then
    printf '%s\n' "workspace-core-venv"
    return
  fi

  if [ -f "$workspace_rocs_repo/pyproject.toml" ]; then
    if has_cmd uvx; then
      printf '%s\n' "workspace-core-uvx"
      return
    fi
    if has_cmd uv; then
      printf '%s\n' "workspace-core-uv"
      return
    fi
  fi

  if has_cmd rocs; then
    printf '%s\n' "path-rocs"
    return
  fi

  printf '%s\n' "missing"
}

runner_desc() {
  case "$1" in
    rocs-bin)
      printf 'ROCS_BIN=%s\n' "${ROCS_BIN}"
      ;;
    rocs-bin-missing)
      printf 'ROCS_BIN is set but not executable/resolvable (%s)\n' "${ROCS_BIN}"
      ;;
    workspace-core-venv)
      printf 'workspace core via %s\n' "$workspace_rocs_repo/.venv/bin/rocs"
      ;;
    workspace-core-uvx)
      printf 'workspace core via uvx --from %s\n' "$workspace_rocs_repo"
      ;;
    workspace-core-uv)
      printf 'workspace core via uv tool run --from %s\n' "$workspace_rocs_repo"
      ;;
    path-rocs)
      printf 'rocs on PATH (%s)\n' "$(command -v rocs)"
      ;;
    missing)
      printf 'unresolved (no viable rocs runner)\n'
      ;;
    *)
      printf 'unknown runner token: %s\n' "$1"
      ;;
  esac
}

doctor() {
  runner="$(select_runner)"

  say "rocs launcher doctor"
  say "- repo_root: $repo_root"
  say "- ROCS_WORKSPACE_ROOT: $ROCS_WORKSPACE_ROOT"
  say "- ROCS_WORKSPACE_REF_MODE: $ROCS_WORKSPACE_REF_MODE"
  say "- workspace_rocs_repo: $workspace_rocs_repo"
  say "- workspace core available: $([ -f "$workspace_rocs_repo/pyproject.toml" ] && printf yes || printf no)"
  say "- workspace core .venv rocs: $([ -x "$workspace_rocs_repo/.venv/bin/rocs" ] && printf yes || printf no)"
  say "- has uv: $(has_cmd uv && printf yes || printf no)"
  say "- has uvx: $(has_cmd uvx && printf yes || printf no)"
  say "- has rocs on PATH: $(has_cmd rocs && printf yes || printf no)"
  say "- selected runner: $(runner_desc "$runner")"

  if [ "$runner" = "missing" ] || [ "$runner" = "rocs-bin-missing" ]; then
    return 1
  fi
  return 0
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--doctor" ]; then
  doctor
  exit $?
fi

runner="$(select_runner)"

if [ "${1:-}" = "--which" ]; then
  runner_desc "$runner"
  if [ "$runner" = "missing" ] || [ "$runner" = "rocs-bin-missing" ]; then
    exit 1
  fi
  exit 0
fi

case "$runner" in
  rocs-bin)
    ROCS_WORKSPACE_ROOT="$ROCS_WORKSPACE_ROOT" ROCS_WORKSPACE_REF_MODE="$ROCS_WORKSPACE_REF_MODE" exec "$ROCS_BIN" "$@"
    ;;
  rocs-bin-missing)
    die "ROCS_BIN is set but not executable/resolvable: $ROCS_BIN"
    ;;
  workspace-core-venv)
    ROCS_WORKSPACE_ROOT="$ROCS_WORKSPACE_ROOT" ROCS_WORKSPACE_REF_MODE="$ROCS_WORKSPACE_REF_MODE" exec "$workspace_rocs_repo/.venv/bin/rocs" "$@"
    ;;
  workspace-core-uvx)
    ROCS_WORKSPACE_ROOT="$ROCS_WORKSPACE_ROOT" ROCS_WORKSPACE_REF_MODE="$ROCS_WORKSPACE_REF_MODE" exec uvx -n --from "$workspace_rocs_repo" rocs "$@"
    ;;
  workspace-core-uv)
    ROCS_WORKSPACE_ROOT="$ROCS_WORKSPACE_ROOT" ROCS_WORKSPACE_REF_MODE="$ROCS_WORKSPACE_REF_MODE" exec uv tool run --from "$workspace_rocs_repo" rocs "$@"
    ;;
  path-rocs)
    ROCS_WORKSPACE_ROOT="$ROCS_WORKSPACE_ROOT" ROCS_WORKSPACE_REF_MODE="$ROCS_WORKSPACE_REF_MODE" exec rocs "$@"
    ;;
  *)
    die "unable to locate rocs runner; set ROCS_BIN, set ROCS_WORKSPACE_ROOT, or install rocs on PATH"
    ;;
esac
