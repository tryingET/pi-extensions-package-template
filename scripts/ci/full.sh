#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"

"$script_dir/smoke.sh"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "error: not a git repo" >&2; exit 1; }
cd "$repo_root"


if [ -x "./scripts/rocs.sh" ] && [ -f "./ontology/manifest.yaml" ]; then
  ./scripts/rocs.sh version
  # Managed ROCS gate: cleanup -> validate -> build (validate before build; never wipe ontology/dist first).
  # The sealed launcher resolves <repo:...@ref> layers from the enclosing workspace by default.
  rocs_ref_mode_args=""
  case "${ROCS_CI_PROFILE:-}" in
  main-strict | branch-ci) rocs_ref_mode_args="--workspace-ref-mode strict" ;;
  esac
  ./scripts/rocs.sh cleanup --repo .
  # shellcheck disable=SC2086
  ./scripts/rocs.sh validate --repo . $rocs_ref_mode_args
  # shellcheck disable=SC2086
  ./scripts/rocs.sh build --repo . $rocs_ref_mode_args
fi
