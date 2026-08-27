import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { normalizeNpmPackJson, parseNpmPackJson } from "./npm-pack-json.mjs";

const SCRIPTS_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPTS_DIR, "..");
const CLI = path.join(SCRIPTS_DIR, "npm-pack-json.mjs");
const STANDALONE_CLI = path.join(ROOT, "copier-template/scripts/npm-pack-json.mjs");
const ENTRY = {
  id: "@tryinget/example@1.2.3",
  name: "@tryinget/example",
  version: "1.2.3",
  filename: "tryinget-example-1.2.3.tgz",
  files: [{ path: "package.json", size: 42, mode: 420 }],
};

function runCli(script, input) {
  return spawnSync(process.execPath, [script], { input, encoding: "utf8" });
}

test("accepts npm 11 arrays and npm 12 package-keyed objects", () => {
  assert.deepEqual(parseNpmPackJson(JSON.stringify([ENTRY])), ENTRY);
  assert.deepEqual(parseNpmPackJson(JSON.stringify({ [ENTRY.name]: ENTRY })), ENTRY);
  assert.deepEqual(JSON.parse(normalizeNpmPackJson(JSON.stringify({ [ENTRY.name]: ENTRY }))), [
    ENTRY,
  ]);
});

test("fails closed on malformed, ambiguous, mismatched, and unsafe pack metadata", () => {
  for (const invalid of [
    "not-json",
    "null",
    JSON.stringify([]),
    JSON.stringify([ENTRY, ENTRY]),
    JSON.stringify(ENTRY),
    JSON.stringify({}),
    JSON.stringify({ one: ENTRY, two: ENTRY }),
    JSON.stringify({ "@tryinget/wrong": ENTRY }),
    JSON.stringify({ [ENTRY.name]: null }),
    JSON.stringify([{ ...ENTRY, id: "wrong" }]),
    JSON.stringify([{ ...ENTRY, filename: "../escape.tgz" }]),
    JSON.stringify([{ ...ENTRY, files: [null] }]),
    JSON.stringify([{ ...ENTRY, files: [{ path: "same" }, { path: "./same" }] }]),
    `{"${ENTRY.name}":${JSON.stringify(ENTRY)},"${ENTRY.name}":${JSON.stringify(ENTRY)}}`,
  ]) {
    assert.throws(() => parseNpmPackJson(invalid));
  }
});

test("CLI emits one canonical array and standalone output keeps the exact parser", () => {
  assert.equal(
    fs.readFileSync(STANDALONE_CLI, "utf8"),
    fs.readFileSync(CLI, "utf8"),
    "standalone generated parser drifted from the template owner",
  );
  for (const script of [CLI, STANDALONE_CLI]) {
    const accepted = runCli(script, JSON.stringify({ [ENTRY.name]: ENTRY }));
    assert.equal(accepted.status, 0, accepted.stderr);
    assert.deepEqual(JSON.parse(accepted.stdout), [ENTRY]);

    const rejected = runCli(script, JSON.stringify({ "@tryinget/wrong": ENTRY }));
    assert.notEqual(rejected.status, 0);
    assert.match(rejected.stderr, /package key must match/);
  }
});

test("all release-check surfaces normalize before canonical-array parsing", () => {
  const surfaces = [
    "scripts/release-check-template.sh",
    "copier-template/scripts/release-check.sh",
    "copier-template-monorepo-package/scripts/release-check.sh",
  ];
  for (const relativePath of surfaces) {
    const source = fs.readFileSync(path.join(ROOT, relativePath), "utf8");
    const normalizerIndex = source.indexOf("npm-pack-json.mjs");
    const parserIndex = source.indexOf('PACK_JSON="$PACK_JSON" node');
    assert.ok(normalizerIndex >= 0, `${relativePath} does not invoke npm-pack-json.mjs`);
    assert.ok(parserIndex >= 0, `${relativePath} has no canonical-array parser`);
    assert.ok(normalizerIndex < parserIndex, `${relativePath} normalizes after parsing`);
    assert.doesNotMatch(source, /cp "\$HOME\/\.pi\/agent\/auth\.json"/);
    assert.doesNotMatch(source, /mktemp -d \/tmp\//);
    assert.match(source, /export TMPDIR/, `${relativePath} does not export managed scratch`);
  }
});
