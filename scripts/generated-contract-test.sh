#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_SRC="${1:-$ROOT_DIR}"
SCAFFOLD_MODE="${SCAFFOLD_MODE:-standalone-repo}"
DEFAULT_CONTRACT_SPEC="$ROOT_DIR/contract/generated-repo.contract.json"
if [[ "$SCAFFOLD_MODE" == "monorepo-package" ]]; then
  DEFAULT_CONTRACT_SPEC="$ROOT_DIR/contract/generated-monorepo-package.contract.json"
fi
CONTRACT_SPEC="${CONTRACT_SPEC:-$DEFAULT_CONTRACT_SPEC}"
REPO_NAME="${CONTRACT_REPO_NAME:-template-contract}"
COMMAND_NAME="${CONTRACT_COMMAND_NAME:-template-contract}"
WORKSPACE_RELATIVE_PATH="${WORKSPACE_RELATIVE_PATH:-packages/$REPO_NAME}"
RELEASE_COMPONENT_KEY="${RELEASE_COMPONENT_KEY:-$REPO_NAME}"
RELEASE_CONFIG_MODE="${RELEASE_CONFIG_MODE:-component}"
MONOREPO_REPO_NAME="${MONOREPO_REPO_NAME:-pi-extensions}"
TEMPLATE_REF="${PI_TEMPLATE_REF:-HEAD}"

if ! command -v copier >/dev/null 2>&1; then
  echo "copier is required for generated-contract testing" >&2
  exit 1
fi

if [[ ! -f "$CONTRACT_SPEC" ]]; then
  echo "Missing contract spec file: $CONTRACT_SPEC" >&2
  exit 1
fi

if [[ "$SCAFFOLD_MODE" != "standalone-repo" && "$SCAFFOLD_MODE" != "monorepo-package" ]]; then
  echo "Invalid SCAFFOLD_MODE: $SCAFFOLD_MODE" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python is required for generated-contract testing" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
DEST_DIR="$TMP_DIR/$REPO_NAME"

cleanup() {
  if [[ "${KEEP_CONTRACT_DIR:-0}" == "1" ]]; then
    echo "Keeping contract test directory: $TMP_DIR"
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

"$PYTHON_BIN" - "$CONTRACT_SPEC" "$DEST_DIR" "$COMMAND_NAME" <<'PY'
import fnmatch
import glob
import json
import re
import sys
from pathlib import Path

spec_path = Path(sys.argv[1])
dest_dir = Path(sys.argv[2])
command_name = sys.argv[3]

try:
  spec = json.loads(spec_path.read_text(encoding="utf-8"))
except Exception as error:
  print(f"Failed to load contract spec: {error}", file=sys.stderr)
  sys.exit(1)

errors = []


def fail(message: str) -> None:
  errors.append(message)


def render(value: str) -> str:
  return value.replace("{{command_name}}", command_name)


if spec.get("version") != 1:
  fail(f"Unsupported contract spec version: {spec.get('version')} (expected 1)")

for rel_path in spec.get("required_files", []):
  rendered = render(rel_path)
  if not (dest_dir / rendered).is_file():
    fail(f"Missing generated contract file: {rendered}")

for rel_path in spec.get("forbidden_paths", []):
  rendered = render(rel_path)
  if (dest_dir / rendered).exists():
    fail(f"Template-source path leaked into generated repo: {rendered}")

for pattern in spec.get("forbidden_globs", []):
  for match in glob.glob(str(dest_dir / pattern), recursive=True):
    matched_path = Path(match)
    if ".git" in matched_path.parts:
      continue
    fail(f"Forbidden path match: {matched_path.relative_to(dest_dir)}")

content_patterns = [
  re.compile(pattern)
  for pattern in spec.get("forbidden_content_patterns", [])
]
content_scan_exclude_paths = spec.get("content_scan_exclude_paths", [])


for file_path in dest_dir.rglob("*"):
  if not file_path.is_file() or ".git" in file_path.parts:
    continue

  rel_path = file_path.relative_to(dest_dir)
  rel_path_posix = rel_path.as_posix()
  if any(
    fnmatch.fnmatch(rel_path_posix, pattern)
    for pattern in content_scan_exclude_paths
  ):
    continue

  try:
    content = file_path.read_text(encoding="utf-8")
  except UnicodeDecodeError:
    continue
  except Exception as error:
    fail(
      "Unable to read file for placeholder scan: "
      f"{rel_path} ({error})"
    )
    continue

  for pattern in content_patterns:
    if pattern.search(content):
      fail(f"Forbidden placeholder pattern '{pattern.pattern}' in {rel_path}")

if errors:
  for error in errors:
    print(error, file=sys.stderr)
  print(
    f"Generated contract test failed with {len(errors)} issue(s).",
    file=sys.stderr,
  )
  sys.exit(1)

print(f"Generated contract test passed: {dest_dir}")
PY
