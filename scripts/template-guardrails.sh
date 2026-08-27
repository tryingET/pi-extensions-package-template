#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

errors=0

fail() {
  echo "$1" >&2
  ((errors+=1))
}

if [[ ! -f .copier-answers.yml ]]; then
  fail "Missing root .copier-answers.yml. This repo keeps L2 lineage metadata for tpl-project-repo."
else
  if ! grep -qE '^_src_path: .*tpl-project-repo$' .copier-answers.yml; then
    fail "Root .copier-answers.yml must keep _src_path lineage to tpl-project-repo."
  fi
fi

if [[ ! -f copier.yml ]]; then
  fail "Missing copier.yml template config."
fi

if [[ ! -d copier-template ]]; then
  fail "Missing copier-template directory."
fi

required_root_files=(
  "package.json"
  "LICENSE"
  "CHANGELOG.md"
  ".release-please-config.json"
  ".release-please-manifest.json"
  ".github/workflows/template-guardrails.yml"
  ".github/workflows/release-check.yml"
  ".github/workflows/release-please.yml"
  ".github/workflows/publish.yml"
  "bin/new-pi-extension-repo.mjs"
  "bin/npm-bootstrap-publish.mjs"
  "scripts/release-check-template.sh"
  "scripts/npm-pack-json.mjs"
  "scripts/npm-pack-json.test.mjs"
  "copier-template/scripts/npm-pack-json.mjs"
  "copier-template/scripts/release-check.sh"
  "copier-template/.gitignore.jinja"
  "copier-template-monorepo-package/scripts/release-check.sh"
  "copier-template-monorepo-package/.gitignore.jinja"
  "copier-template/README.md.jinja"
  "copier-template-monorepo-package/README.md.jinja"
  "contract/generated-repo.contract.json"
  "contract/generated-monorepo-package.contract.json"
)

for required_file in "${required_root_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    fail "Missing required root file: $required_file"
  fi
done

required_executables=(
  "bin/new-pi-extension-repo.mjs"
  "bin/npm-bootstrap-publish.mjs"
  "scripts/release-check-template.sh"
  "scripts/npm-pack-json.mjs"
  "copier-template/scripts/npm-pack-json.mjs"
)

for executable in "${required_executables[@]}"; do
  if [[ ! -x "$executable" ]]; then
    fail "Expected executable bit on: $executable"
  fi
done

if [[ -f scripts/npm-pack-json.mjs && -f copier-template/scripts/npm-pack-json.mjs ]] &&
  ! cmp -s scripts/npm-pack-json.mjs copier-template/scripts/npm-pack-json.mjs; then
  fail "Standalone generated npm pack normalizer must match the template-owned parser exactly."
fi

release_check_surfaces=(
  "scripts/release-check-template.sh"
  "copier-template/scripts/release-check.sh"
  "copier-template-monorepo-package/scripts/release-check.sh"
)
for release_check in "${release_check_surfaces[@]}"; do
  if [[ ! -f "$release_check" ]]; then
    continue
  fi
  if ! grep -q 'npm-pack-json\.mjs' "$release_check"; then
    fail "$release_check must normalize npm pack JSON before parsing."
  fi
  if grep -q 'cp "\$HOME/.pi/agent/auth.json"' "$release_check"; then
    fail "$release_check must not copy operator credentials into release scratch."
  fi
  if grep -qE 'mktemp -d /tmp/' "$release_check"; then
    fail "$release_check must honor managed TMPDIR instead of hard-coded /tmp."
  fi
  if ! grep -q 'export TMPDIR' "$release_check"; then
    fail "$release_check must export managed TMPDIR to child processes."
  fi
  for credential_boundary in 'isolated_npm()' 'env -i' 'NPM_CONFIG_USERCONFIG=' 'NPM_CONFIG_GLOBALCONFIG='; do
    if ! grep -qF "$credential_boundary" "$release_check"; then
      fail "$release_check is missing credential boundary: $credential_boundary"
    fi
  done
done

if grep -R -n --include='*.jinja' '@mariozechner/' copier-template copier-template-monorepo-package >/dev/null; then
  fail "Generated template sources must use @earendil-works Pi package ownership, not @mariozechner."
fi

for generated_root in copier-template copier-template-monorepo-package; do
  if ! grep -q '@earendil-works/pi-coding-agent' "$generated_root/package.json.jinja"; then
    fail "$generated_root/package.json.jinja must declare the Earendil Works coding-agent peer."
  fi
  if ! grep -q '@earendil-works/pi-ai' "$generated_root/package.json.jinja"; then
    fail "$generated_root/package.json.jinja must declare the Earendil Works Pi AI peer."
  fi
done

if [[ ! -f .gitignore ]] || ! grep -q '^\*\.tgz$' .gitignore; then
  fail ".gitignore must include '*.tgz'"
fi

if ! grep -q '^\.owner/$' .gitignore; then
  fail ".gitignore must exclude pinned CI owner checkouts under .owner/"
fi

if ! grep -q "npm run release:check:quick" ".github/workflows/release-check.yml"; then
  fail "release-check workflow must run npm run release:check:quick"
fi

for npm_version in 11.13.0 12.0.2; do
  if ! grep -q "\"$npm_version\"" ".github/workflows/release-check.yml"; then
    fail "release-check workflow must exercise npm $npm_version"
  fi
done

pinned_pi_extensions_ref="e855d07799f7984770d8a7ce25fc8ebabe1b7e64"
for workflow in .github/workflows/template-guardrails.yml .github/workflows/publish.yml; do
  if ! grep -q "$pinned_pi_extensions_ref" "$workflow"; then
    fail "$workflow must pin the pi-extensions validation owner to $pinned_pi_extensions_ref"
  fi
done

if ! grep -q "npm run release:check" ".github/workflows/publish.yml"; then
  fail "publish workflow must run npm run release:check"
fi

if grep -q "cache: npm" ".github/workflows/publish.yml"; then
  fail "publish workflow must not require setup-node npm cache when lockfile may be absent"
fi

if ! grep -q "npm install --global npm@\^11.5.1" ".github/workflows/publish.yml"; then
  fail "publish workflow must upgrade npm to >=11.5.1 for trusted publishing compatibility"
fi

release_please_ref="16a9c90856f42705d54a6fda1823352bdc62cf38"
if ! grep -q "googleapis/release-please-action@${release_please_ref}" ".github/workflows/release-please.yml"; then
  fail "release-please workflow must pin googleapis/release-please-action to ${release_please_ref} (v4.4.0)"
fi

if command -v node >/dev/null 2>&1; then
  if ! node - <<'NODE'
const fs = require("node:fs");

let failed = false;
const fail = (msg) => {
  console.error(msg);
  failed = true;
};

try {
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));

  if (typeof pkg.name !== "string" || pkg.name !== pkg.name.toLowerCase()) {
    fail("package.json name must be lowercase");
  }

  if (pkg.publishConfig?.registry !== "https://registry.npmjs.org/") {
    fail("package.json publishConfig.registry must be 'https://registry.npmjs.org/'");
  }

  if (pkg.publishConfig?.access !== "public") {
    fail("package.json publishConfig.access must be 'public'");
  }

  const requiredScripts = {
    "quality:pre-commit": "node --test ./scripts/npm-pack-json.test.mjs && bash ./scripts/template-guardrails.sh",
    "quality:pre-push": "npm run check:full",
    check: "node --test ./scripts/npm-pack-json.test.mjs && bash ./scripts/template-guardrails.sh",
    "check:full": "node --test ./scripts/npm-pack-json.test.mjs && bash ./scripts/template-guardrails.sh && bash ./scripts/smoke-test-template.sh && bash ./scripts/generated-contract-test.sh && bash ./scripts/idempotency-test-template.sh && SCAFFOLD_MODE=simple-package bash ./scripts/smoke-test-template.sh && SCAFFOLD_MODE=simple-package bash ./scripts/generated-contract-test.sh && SCAFFOLD_MODE=simple-package bash ./scripts/idempotency-test-template.sh",
    "release:check": "bash ./scripts/release-check-template.sh",
    "release:check:quick": "SKIP_COPIER_SMOKE=1 bash ./scripts/release-check-template.sh",
  };
  for (const [key, expected] of Object.entries(requiredScripts)) {
    if (pkg.scripts?.[key] !== expected) {
      fail(`package.json scripts.${key} must be '${expected}'`);
    }
  }

  if (!pkg.bin || typeof pkg.bin !== "object") {
    fail("package.json must define bin mappings");
  } else {
    const binValues = Object.values(pkg.bin).map((v) => String(v));
    if (!binValues.includes("bin/new-pi-extension-repo.mjs")) {
      fail("package.json bin must include bin/new-pi-extension-repo.mjs");
    }
    if (!binValues.includes("bin/npm-bootstrap-publish.mjs")) {
      fail("package.json bin must include bin/npm-bootstrap-publish.mjs");
    }
  }

  if (!Array.isArray(pkg.files) || pkg.files.length < 1) {
    fail("package.json must define files[]");
  } else {
    const requiredFiles = [
      "bin/new-pi-extension-repo.mjs",
      "bin/npm-bootstrap-publish.mjs",
      "copier-template",
      "copier-template/.gitignore.jinja",
      "copier-template-monorepo-package",
      "copier-template-monorepo-package/.gitignore.jinja",
      "copier.yml",
      "new-pi-extension-repo.sh",
      "README.md",
      "LICENSE",
    ];
    for (const entry of requiredFiles) {
      if (!pkg.files.includes(entry)) {
        fail(`package.json files[] must include '${entry}'`);
      }
    }
  }

  const rpManifest = JSON.parse(fs.readFileSync(".release-please-manifest.json", "utf8"));
  if (rpManifest["."] !== pkg.version) {
    fail(".release-please-manifest.json '.' must match package.json version");
  }

  const rpConfig = JSON.parse(fs.readFileSync(".release-please-config.json", "utf8"));
  if (rpConfig["include-v-in-tag"] !== true) {
    fail(".release-please-config.json must set include-v-in-tag=true");
  }
  if (rpConfig["include-component-in-tag"] !== false) {
    fail(".release-please-config.json must set include-component-in-tag=false");
  }
  if (!rpConfig.packages || !rpConfig.packages["."]) {
    fail(".release-please-config.json must include packages['.']");
  }

  const scopedNameTemplate = '"name": "@{{ npm_org }}/{{ repo_name }}"';
  for (const templatePath of [
    "copier-template/package.json.jinja",
    "copier-template-monorepo-package/package.json.jinja",
  ]) {
    const template = fs.readFileSync(templatePath, "utf8");
    if (!template.includes(scopedNameTemplate)) {
      fail(`${templatePath} must keep package.json name templated as ${scopedNameTemplate}`);
    }
  }
} catch (error) {
  fail(`Failed to validate root package metadata/templates: ${error.message}`);
}

process.exit(failed ? 1 : 0);
NODE
  then
    ((errors+=1))
  fi
fi

if [[ "$errors" -gt 0 ]]; then
  echo "Template guardrails failed with $errors issue(s)." >&2
  exit 1
fi

echo "Template guardrails passed."
