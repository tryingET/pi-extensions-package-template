#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  update-generated-repos.sh --ref <vX.Y.Z|HEAD> [options]

Options:
  --ref <ref>           Required. Copier template ref (recommended: release tag)
  --root <dir>          Root directory containing generated repos
                        Default: ~/programming/pi-extensions
  --check-cmd <cmd>     Validation command run in each repo
                        Default: npm run check
  --pre-commit          Create snapshot commit before update (recommended)
  --post-commit         Create commit after successful update (recommended)
  --pre-msg <msg>       Pre-update commit message template
                        Default: "chore(template): snapshot before update from {ref}"
  --post-msg <msg>      Post-update commit message template
                        Default: "chore(template): sync from pi-extensions-template_copier {ref}"
  --author <name>       Git author name for commits (default: current repo config)
  --email <email>       Git author email for commits (default: current repo config)
  --dry-run             Show what would happen without making changes
  --parallel <N>        Process N repos concurrently (default: 1)
                        Requires GNU parallel or falls back to sequential
  -h, --help            Show help

Behavior:
  - Strict: aborts on first failure (all parallel workers stop).
  - Skips non-git dirs and repos without .copier-answers.yml.
  - With --pre-commit: commits any dirty state before update.
  - With --post-commit: commits changes after update and check.
  - Without --pre-commit: requires repo to be clean before update.
  - --dry-run: validates preconditions and shows planned actions only.
USAGE
}

ROOT="${HOME}/programming/pi-extensions"
REF=""
CHECK_CMD="npm run check"
PRE_COMMIT=false
POST_COMMIT=false
PRE_MSG="chore(template): snapshot before update from {ref}"
POST_MSG="chore(template): sync from pi-extensions-template_copier {ref}"
AUTHOR=""
EMAIL=""
DRY_RUN=false
PARALLEL=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)        ROOT="$2"; shift 2 ;;
    --ref)         REF="$2"; shift 2 ;;
    --check-cmd)   CHECK_CMD="$2"; shift 2 ;;
    --pre-commit)  PRE_COMMIT=true; shift ;;
    --post-commit) POST_COMMIT=true; shift ;;
    --pre-msg)     PRE_MSG="$2"; shift 2 ;;
    --post-msg)    POST_MSG="$2"; shift 2 ;;
    --author)      AUTHOR="$2"; shift 2 ;;
    --email)       EMAIL="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --parallel)    PARALLEL="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$REF" ]]; then
  echo "Error: --ref is required." >&2
  usage
  exit 1
fi

if ! command -v copier >/dev/null 2>&1; then
  echo "Error: copier is not installed." >&2
  exit 1
fi

if [[ ! -d "$ROOT" ]]; then
  echo "Error: root directory not found: $ROOT" >&2
  exit 1
fi

if [[ "$PARALLEL" -lt 1 ]]; then
  echo "Error: --parallel must be >= 1" >&2
  exit 1
fi

HAS_GNU_PARALLEL=false
if [[ "$PARALLEL" -gt 1 ]]; then
  if command -v parallel >/dev/null 2>&1; then
    if parallel --version 2>/dev/null | grep -q "GNU parallel"; then
      HAS_GNU_PARALLEL=true
    else
      echo "Warning: GNU parallel not found, falling back to sequential mode." >&2
      PARALLEL=1
    fi
  else
    echo "Warning: GNU parallel not found, falling back to sequential mode." >&2
    PARALLEL=1
  fi
fi

git_author_args=()
if [[ -n "$AUTHOR" && -n "$EMAIL" ]]; then
  git_author_args+=("--author" "$AUTHOR <$EMAIL>")
fi

expand_msg() {
  local tmpl="$1"
  echo "${tmpl//\{ref\}/$REF}"
}

declare -a RESULTS=()
declare -A REPO_PATHS=()

record() {
  RESULTS+=("$1|$2|$3|$4")
}

print_summary() {
  echo
  echo "=== Update Summary ==="
  printf "%-36s %-10s %-10s %s\n" "REPO" "STATUS" "METHOD" "DETAILS"
  printf "%-36s %-10s %-10s %s\n" "----" "------" "------" "-------"
  for row in "${RESULTS[@]}"; do
    IFS='|' read -r repo status method details <<<"$row"
    printf "%-36s %-10s %-10s %s\n" "$repo" "$status" "$method" "$details"
  done
}

process_repo() {
  local repo="$1"
  local repo_path="${REPO_PATHS[$repo]}"

  if [[ ! -d "$repo_path/.git" ]]; then
    record "$repo" "SKIPPED" "-" "not a git repo"
    return 0
  fi

  if [[ ! -f "$repo_path/.copier-answers.yml" ]]; then
    record "$repo" "SKIPPED" "-" "no .copier-answers.yml"
    return 0
  fi

  echo "==> $repo"

  local dirty=0
  local dirty_files=""
  if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
    dirty=1
    dirty_files="$(git -C "$repo_path" status --porcelain | head -n 5 | tr '\n' ' ')"
    if [[ "$(git -C "$repo_path" status --porcelain | wc -l)" -gt 5 ]]; then
      dirty_files+="..."
    fi
  fi

  if [[ "$dirty" -eq 1 && "$PRE_COMMIT" != true ]]; then
    record "$repo" "FAILED" "precheck" "repo is dirty (commit/stash first, or use --pre-commit)"
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "   [dry-run] would process: $repo"
    if [[ "$dirty" -eq 1 && "$PRE_COMMIT" == true ]]; then
      local pre_msg
      pre_msg="$(expand_msg "$PRE_MSG")"
      echo "   [dry-run] pre-commit: $pre_msg"
      echo "   [dry-run]   dirty files: $dirty_files"
    fi
    echo "   [dry-run] copier update --trust --defaults --vcs-ref $REF (fallback: recopy)"
    echo "   [dry-run] check: $CHECK_CMD"
    if [[ "$POST_COMMIT" == true ]]; then
      local post_msg
      post_msg="$(expand_msg "$POST_MSG")"
      echo "   [dry-run] post-commit: $post_msg"
    fi
    record "$repo" "DRY-RUN" "-" "would update (dirty=$dirty)"
    return 0
  fi

  if [[ "$dirty" -eq 1 && "$PRE_COMMIT" == true ]]; then
    local pre_msg
    pre_msg="$(expand_msg "$PRE_MSG")"
    git -C "$repo_path" add -A
    git -C "$repo_path" commit "${git_author_args[@]}" -m "$pre_msg"
    echo "   pre-commit: $pre_msg"
  fi

  local tmp_log
  tmp_log="$(mktemp)"
  local method="update"

  if ! (cd "$repo_path" && copier update --trust --defaults --vcs-ref "$REF" >"$tmp_log" 2>&1); then
    method="recopy"
    echo "   update failed, trying recopy..."
    if ! (cd "$repo_path" && copier recopy --trust --defaults --overwrite --vcs-ref "$REF" >>"$tmp_log" 2>&1); then
      local tail_msg
      tail_msg="$(tail -n 10 "$tmp_log" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
      rm -f "$tmp_log"
      record "$repo" "FAILED" "$method" "copier failed: ${tail_msg}"
      return 1
    fi
  fi

  if ! (cd "$repo_path" && bash -lc "$CHECK_CMD" >>"$tmp_log" 2>&1); then
    local tail_msg
    tail_msg="$(tail -n 10 "$tmp_log" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
    rm -f "$tmp_log"
    record "$repo" "FAILED" "check" "validation failed: ${tail_msg}"
    return 1
  fi

  local change_count
  change_count="$(git -C "$repo_path" status --porcelain | wc -l | tr -d ' ')"

  if [[ "$POST_COMMIT" == true && "$change_count" -gt 0 ]]; then
    local post_msg
    post_msg="$(expand_msg "$POST_MSG")"
    git -C "$repo_path" add -A
    git -C "$repo_path" commit "${git_author_args[@]}" -m "$post_msg"
    echo "   post-commit: $post_msg"
    record "$repo" "OK" "$method" "committed ${change_count} file(s)"
  else
    record "$repo" "OK" "$method" "${change_count} changed file(s)"
  fi

  rm -f "$tmp_log"
  return 0
}

export -f expand_msg process_repo record
export REF CHECK_CMD PRE_COMMIT POST_COMMIT PRE_MSG POST_MSG DRY_RUN ROOT
export AUTHOR EMAIL
if [[ "${#git_author_args[@]}" -gt 0 ]]; then
  export GIT_AUTHOR_ARGS="${git_author_args[*]}"
else
  export GIT_AUTHOR_ARGS=""
fi

collect_repos() {
  local processed=0
  for repo_path in "$ROOT"/*; do
    [[ -d "$repo_path" ]] || continue
    local repo
    repo="$(basename "$repo_path")"

    if [[ ! -d "$repo_path/.git" ]]; then
      record "$repo" "SKIPPED" "-" "not a git repo"
      continue
    fi

    if [[ ! -f "$repo_path/.copier-answers.yml" ]]; then
      record "$repo" "SKIPPED" "-" "no .copier-answers.yml"
      continue
    fi

    REPO_PATHS["$repo"]="$repo_path"
    processed=$((processed + 1))
  done

  if [[ "$processed" -eq 0 ]]; then
    echo "No generated repos found under: $ROOT"
    exit 1
  fi
}

run_sequential() {
  for repo in "${!REPO_PATHS[@]}"; do
    if ! process_repo "$repo"; then
      print_summary
      exit 1
    fi
  done
}

run_parallel() {
  local tmp_status
  tmp_status="$(mktemp)"

  printf '%s\n' "${!REPO_PATHS[@]}" | \
    parallel -j "$PARALLEL" --halt soon,fail=1 \
      "process_repo {} || exit 255" \
      2>"$tmp_status"

  local parallel_exit=$?
  if [[ $parallel_exit -ne 0 ]]; then
    cat "$tmp_status" >&2
    rm -f "$tmp_status"
    print_summary
    exit 1
  fi
  rm -f "$tmp_status"
}

collect_repos

if [[ "$PARALLEL" -gt 1 && "$HAS_GNU_PARALLEL" == true ]]; then
  run_parallel
else
  run_sequential
fi

print_summary

if [[ "$DRY_RUN" == true ]]; then
  echo
  echo "Dry-run complete. No changes were made."
else
  echo
  echo "All processed repos updated successfully."
fi
