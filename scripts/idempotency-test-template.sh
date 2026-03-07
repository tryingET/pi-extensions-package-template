#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_SRC="${1:-$ROOT_DIR}"
REPO_NAME="${IDEMPOTENCY_REPO_NAME:-template-idempotency}"
COMMAND_NAME="${IDEMPOTENCY_COMMAND_NAME:-template-idempotency}"
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
  echo "copier is required for idempotency testing" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required for idempotency testing" >&2
  exit 1
fi

if [[ "$RAW_SCAFFOLD_MODE" != "standalone-repo" && "$RAW_SCAFFOLD_MODE" != "monorepo-package" && "$RAW_SCAFFOLD_MODE" != "simple-package" ]]; then
  echo "Invalid SCAFFOLD_MODE: $RAW_SCAFFOLD_MODE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
DEST_DIR="$TMP_DIR/$REPO_NAME"

cleanup() {
  if [[ "${KEEP_IDEMPOTENCY_DIR:-0}" == "1" ]]; then
    echo "Keeping idempotency directory: $TMP_DIR"
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

  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install --package-lock-only --ignore-scripts
    npm ci
  fi

  if [[ ! -d .git ]]; then
    git init -q
  fi

  git config user.name "${IDEMPOTENCY_GIT_NAME:-template-ci}"
  git config user.email "${IDEMPOTENCY_GIT_EMAIL:-template-ci@example.invalid}"
  git add -A
  git commit -q -m "baseline snapshot"
)

update_args=(update --trust --defaults)
recopy_args=(recopy --trust --defaults)

if [[ -n "$TEMPLATE_REF" ]]; then
  update_args+=(--vcs-ref "$TEMPLATE_REF")
  recopy_args+=(--vcs-ref "$TEMPLATE_REF")
fi

extract_update_error_reason() {
  local log_file="$1"
  local reason=""

  reason="$(grep -m1 -E 'error: pathspec .* did not match any file\(s\) known to git' "$log_file" || true)"
  if [[ -z "$reason" ]]; then
    reason="$(grep -m1 -E 'Unexpected exit code: [0-9]+' "$log_file" || true)"
  fi
  if [[ -z "$reason" ]]; then
    reason="$(grep -m1 -E '(^| )error: ' "$log_file" || true)"
  fi
  if [[ -z "$reason" ]]; then
    reason="$(grep -m1 -E '(Exception|Traceback|failed)' "$log_file" || true)"
  fi
  if [[ -z "$reason" ]]; then
    reason="$(tail -n 1 "$log_file" | tr -d '\r' || true)"
  fi

  reason="$(echo "$reason" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  if [[ -z "$reason" ]]; then
    reason="unknown copier update error"
  fi

  printf '%s' "$reason"
}

update_log="$TMP_DIR/idempotency-update.log"
operation="update"
if ! (
  cd "$DEST_DIR"
  copier "${update_args[@]}" >"$update_log" 2>&1
); then
  operation="recopy"
  reason="$(extract_update_error_reason "$update_log")"
  echo "copier update failed (${reason}); falling back to copier recopy" >&2
  if [[ "${IDEMPOTENCY_VERBOSE:-0}" == "1" ]]; then
    echo "idempotency debug: showing last 40 update log lines" >&2
    tail -n 40 "$update_log" >&2 || true
  fi
  (
    cd "$DEST_DIR"
    copier "${recopy_args[@]}"
  )
fi

template_source_dirty=0
if git -C "$TEMPLATE_SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -n "$(git -C "$TEMPLATE_SRC" status --porcelain)" ]]; then
    template_source_dirty=1
  fi
fi

status_output="$(
  cd "$DEST_DIR"
  git status --porcelain
)"

if [[ -n "$status_output" ]]; then
  if [[ "$template_source_dirty" -eq 1 ]]; then
    changed_files="$(
      cd "$DEST_DIR"
      git diff --name-only
    )"

    if [[ "$changed_files" == ".copier-answers.yml" ]]; then
      before_no_commit="$(
        cd "$DEST_DIR"
        git show HEAD:.copier-answers.yml | sed '/^_commit:/d'
      )"
      after_no_commit="$(
        cd "$DEST_DIR"
        sed '/^_commit:/d' .copier-answers.yml
      )"

      if [[ "$before_no_commit" == "$after_no_commit" ]]; then
        echo "Idempotency note: source template is dirty; allowing _commit churn in .copier-answers.yml" >&2
        echo "Idempotency test passed using $operation (dirty-source allowance): $DEST_DIR"
        exit 0
      fi
    fi
  fi

  echo "Idempotency test failed after $operation: repository changed" >&2
  echo "$status_output" >&2

  (
    cd "$DEST_DIR"
    git status --short > "$TMP_DIR/idempotency-status.txt" || true
    git --no-pager diff > "$TMP_DIR/idempotency.diff" || true
    git --no-pager diff --cached > "$TMP_DIR/idempotency-staged.diff" || true
  )

  exit 1
fi

echo "Idempotency test passed using $operation: $DEST_DIR"
