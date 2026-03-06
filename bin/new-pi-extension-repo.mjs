#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TEMPLATE_DIR = path.resolve(__dirname, "..");

const NAME_PATTERN = /^[a-zA-Z0-9._-]+$/;
const GITHUB_HANDLE_PATTERN = /^[A-Za-z0-9-]+$/;
const SCAFFOLD_MODES = new Set(["standalone-repo", "monorepo-package"]);
const RELEASE_CONFIG_MODES = new Set(["component", "none"]);
const WORKSPACE_PATH_PATTERN = /^[a-zA-Z0-9._/-]+$/;

function usage() {
  console.error(`Usage: new-pi-extension-repo <repo-name> [command-name] [options]

Options:
  --target-dir <path>              Destination directory (default: ./<repo-name>)
  --template-ref <ref>             Override copier --vcs-ref
  --github-maintainer <handle>     GitHub handle seeded in generated metadata
  --mode <standalone-repo|monorepo-package>
                                   Scaffold mode (default: monorepo-package)
  --workspace-path <path>          Workspace-relative package path metadata (monorepo mode)
  --release-component <key>        release-please component key metadata (monorepo mode)
  --release-config-mode <component|none>
                                   Release metadata mode (monorepo mode)
  --monorepo-repo <name>           Monorepo repository name for package repository.url
  -h, --help                       Show this help

Env:
  PI_TEMPLATE_REF=<ref>            Template ref fallback (defaults to HEAD for local git template checkouts)
  PI_GITHUB_MAINTAINER=<handle>    Optional GitHub handle fallback for generated metadata
  PI_SCAFFOLD_MODE=<mode>          Scaffold mode fallback
  PI_WORKSPACE_PATH=<path>         Workspace-relative package path fallback
  PI_RELEASE_COMPONENT=<key>       release component key fallback
  PI_RELEASE_CONFIG_MODE=<mode>    Release metadata mode fallback
  PI_MONOREPO_REPO_NAME=<name>     Monorepo repo name fallback

Notes:
  - Requires copier to be installed (pipx/uv/pip).
  - Uses this package as the template source.`);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function applyNpmIgnoreWorkaround(templateDir) {
  const gitignorePath = path.join(templateDir, "copier-template", ".gitignore");
  const npmignorePath = path.join(templateDir, "copier-template", ".npmignore");

  if (existsSync(gitignorePath) || !existsSync(npmignorePath)) {
    return () => {};
  }

  const npmignoreContent = readFileSync(npmignorePath);
  copyFileSync(npmignorePath, gitignorePath);
  rmSync(npmignorePath);

  return () => {
    if (existsSync(gitignorePath)) {
      rmSync(gitignorePath);
    }
    if (!existsSync(npmignorePath)) {
      writeFileSync(npmignorePath, npmignoreContent);
    }
  };
}

function templateSourceIsGitRepo(templateDir) {
  const check = spawnSync("git", ["-C", templateDir, "rev-parse", "--is-inside-work-tree"], {
    stdio: "ignore",
  });
  return check.status === 0;
}

function detectGithubMaintainer(explicitArg) {
  const explicit = typeof explicitArg === "string" ? explicitArg.trim() : "";
  if (explicit) return explicit;

  const envValue =
    process.env.PI_GITHUB_MAINTAINER ?? process.env.GITHUB_USER ?? process.env.GITHUB_ACTOR ?? "";
  const envHandle = typeof envValue === "string" ? envValue.trim() : "";
  if (envHandle) return envHandle;

  const gh = spawnSync("gh", ["api", "user", "-q", ".login"], {
    stdio: ["ignore", "pipe", "ignore"],
    encoding: "utf8",
  });
  if (gh.status === 0) {
    const login = String(gh.stdout ?? "").trim();
    if (login) return login;
  }

  return "tryingET";
}

const args = process.argv.slice(2);
let targetDirArg;
let templateRefArg;
let githubMaintainerArg;
let scaffoldModeArg;
let workspacePathArg;
let releaseComponentArg;
let releaseConfigModeArg;
let monorepoRepoNameArg;
const positional = [];

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];

  if (arg === "-h" || arg === "--help") {
    usage();
    process.exit(0);
  }

  if (arg === "--target-dir") {
    i += 1;
    if (i >= args.length) fail("Missing value for --target-dir");
    targetDirArg = args[i];
    continue;
  }

  if (arg === "--template-ref") {
    i += 1;
    if (i >= args.length) fail("Missing value for --template-ref");
    templateRefArg = args[i];
    continue;
  }

  if (arg === "--github-maintainer") {
    i += 1;
    if (i >= args.length) fail("Missing value for --github-maintainer");
    githubMaintainerArg = args[i];
    continue;
  }

  if (arg === "--mode") {
    i += 1;
    if (i >= args.length) fail("Missing value for --mode");
    scaffoldModeArg = args[i];
    continue;
  }

  if (arg === "--workspace-path") {
    i += 1;
    if (i >= args.length) fail("Missing value for --workspace-path");
    workspacePathArg = args[i];
    continue;
  }

  if (arg === "--release-component") {
    i += 1;
    if (i >= args.length) fail("Missing value for --release-component");
    releaseComponentArg = args[i];
    continue;
  }

  if (arg === "--release-config-mode") {
    i += 1;
    if (i >= args.length) fail("Missing value for --release-config-mode");
    releaseConfigModeArg = args[i];
    continue;
  }

  if (arg === "--monorepo-repo") {
    i += 1;
    if (i >= args.length) fail("Missing value for --monorepo-repo");
    monorepoRepoNameArg = args[i];
    continue;
  }

  if (arg.startsWith("-")) {
    fail(`Unknown option: ${arg}`);
  }

  positional.push(arg);
}

if (positional.length < 1 || positional.length > 2) {
  usage();
  process.exit(1);
}

const repoName = positional[0];
const commandName = positional[1] ?? repoName;
const explicitTemplateRef = templateRefArg ?? process.env.PI_TEMPLATE_REF ?? "";
const templateRef = explicitTemplateRef || (templateSourceIsGitRepo(TEMPLATE_DIR) ? "HEAD" : "");
const githubMaintainer = detectGithubMaintainer(githubMaintainerArg);
const scaffoldMode =
  (scaffoldModeArg ?? process.env.PI_SCAFFOLD_MODE ?? "monorepo-package").trim() ||
  "monorepo-package";
const workspacePath =
  (workspacePathArg ?? process.env.PI_WORKSPACE_PATH ?? `packages/${repoName}`).trim() ||
  `packages/${repoName}`;
const releaseComponent =
  (releaseComponentArg ?? process.env.PI_RELEASE_COMPONENT ?? repoName).trim() || repoName;
const releaseConfigMode =
  (releaseConfigModeArg ?? process.env.PI_RELEASE_CONFIG_MODE ?? "component").trim() ||
  "component";
const monorepoRepoName =
  (monorepoRepoNameArg ?? process.env.PI_MONOREPO_REPO_NAME ?? "pi-extensions").trim() ||
  "pi-extensions";

if (!NAME_PATTERN.test(repoName)) {
  fail("Error: repo-name must match [a-zA-Z0-9._-]+");
}

if (!NAME_PATTERN.test(commandName)) {
  fail("Error: command-name must match [a-zA-Z0-9._-]+");
}

if (!SCAFFOLD_MODES.has(scaffoldMode)) {
  fail("Error: --mode must be one of standalone-repo or monorepo-package");
}

if (!WORKSPACE_PATH_PATTERN.test(workspacePath)) {
  fail("Error: --workspace-path must match [a-zA-Z0-9._/-]+");
}

if (!NAME_PATTERN.test(releaseComponent)) {
  fail("Error: --release-component must match [a-zA-Z0-9._-]+");
}

if (!RELEASE_CONFIG_MODES.has(releaseConfigMode)) {
  fail("Error: --release-config-mode must be 'component' or 'none'");
}

if (!NAME_PATTERN.test(monorepoRepoName)) {
  fail("Error: --monorepo-repo must match [a-zA-Z0-9._-]+");
}

if (!GITHUB_HANDLE_PATTERN.test(githubMaintainer)) {
  fail("Error: --github-maintainer must match GitHub handle characters [A-Za-z0-9-]+");
}

const targetDir = path.resolve(targetDirArg ?? path.join(process.cwd(), repoName));

if (existsSync(targetDir)) {
  fail(`Error: target already exists: ${targetDir}`);
}

const copierCheck = spawnSync("copier", ["--version"], { stdio: "ignore" });
if (copierCheck.status !== 0) {
  fail(`Error: copier is not installed.
Install one of:
  pipx install copier
  uv tool install copier
  pip install copier`);
}

const copierArgs = [
  "copy",
  "--trust",
  "--defaults",
  "-d",
  `scaffold_mode=${scaffoldMode}`,
  "-d",
  `repo_name=${repoName}`,
  "-d",
  `command_name=${commandName}`,
  "-d",
  `github_maintainer=${githubMaintainer}`,
  "-d",
  `workspace_relative_path=${workspacePath}`,
  "-d",
  `release_component_key=${releaseComponent}`,
  "-d",
  `release_config_mode=${releaseConfigMode}`,
  "-d",
  `monorepo_repo_name=${monorepoRepoName}`,
];

if (templateRef) {
  copierArgs.push("--vcs-ref", templateRef);
}

copierArgs.push(TEMPLATE_DIR, targetDir);

const cleanupWorkaround = applyNpmIgnoreWorkaround(TEMPLATE_DIR);
let child;
try {
  child = spawnSync("copier", copierArgs, {
    stdio: "inherit",
    env: process.env,
    cwd: process.cwd(),
  });
} finally {
  cleanupWorkaround();
}

if (child.error) {
  fail(`Failed to run copier: ${child.error.message}`);
}

if (child.status !== 0) {
  process.exit(child.status ?? 1);
}

console.log(`Created: ${targetDir}`);
