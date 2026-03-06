#!/usr/bin/env node

import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";

const DEFAULT_VERIFY_INITIAL_WAIT_SECONDS = 30;
const DEFAULT_VERIFY_ATTEMPTS = 6;
const DEFAULT_VERIFY_INTERVAL_SECONDS = 10;

function usage() {
  console.log(`npm-bootstrap-publish

Bootstrap first npm publish with ephemeral auth config.

Usage:
  npm-bootstrap-publish [--project <path>] [--registry <url>] [--access <public|restricted>]
                        [--op <op://vault/item/field>] [--token-env <ENV_VAR>]
                        [--allow-existing-version] [--skip-whoami] [--dry-run] [--yes]
                        [--verify-initial-wait <seconds>] [--verify-attempts <n>] [--verify-interval <seconds>]

Examples:
  npm-bootstrap-publish --op op://dev/npm-publish/token
  npm-bootstrap-publish --token-env NPM_TOKEN
  npm-bootstrap-publish --project ../my-package --dry-run
`);
}

function parsePositiveInt(raw, flagName) {
  const parsed = Number.parseInt(String(raw), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${flagName} must be a positive integer.`);
  }
  return parsed;
}

function parseArgs(argv) {
  const args = {
    project: ".",
    registry: "https://registry.npmjs.org/",
    tokenEnv: "NPM_TOKEN",
    allowExistingVersion: false,
    skipWhoami: false,
    dryRun: false,
    yes: false,
    access: undefined,
    op: undefined,
    verifyInitialWaitSeconds: DEFAULT_VERIFY_INITIAL_WAIT_SECONDS,
    verifyAttempts: DEFAULT_VERIFY_ATTEMPTS,
    verifyIntervalSeconds: DEFAULT_VERIFY_INTERVAL_SECONDS,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    const next = argv[i + 1];
    switch (token) {
      case "--project":
        if (!next) throw new Error("Missing value for --project");
        args.project = next;
        i += 1;
        break;
      case "--registry":
        if (!next) throw new Error("Missing value for --registry");
        args.registry = next;
        i += 1;
        break;
      case "--access":
        if (!next) throw new Error("Missing value for --access");
        args.access = next;
        i += 1;
        break;
      case "--op":
        if (!next) throw new Error("Missing value for --op");
        args.op = next;
        i += 1;
        break;
      case "--token-env":
        if (!next) throw new Error("Missing value for --token-env");
        args.tokenEnv = next;
        i += 1;
        break;
      case "--verify-initial-wait":
        if (!next) throw new Error("Missing value for --verify-initial-wait");
        args.verifyInitialWaitSeconds = parsePositiveInt(next, "--verify-initial-wait");
        i += 1;
        break;
      case "--verify-attempts":
        if (!next) throw new Error("Missing value for --verify-attempts");
        args.verifyAttempts = parsePositiveInt(next, "--verify-attempts");
        i += 1;
        break;
      case "--verify-interval":
        if (!next) throw new Error("Missing value for --verify-interval");
        args.verifyIntervalSeconds = parsePositiveInt(next, "--verify-interval");
        i += 1;
        break;
      case "--allow-existing-version":
        args.allowExistingVersion = true;
        break;
      case "--skip-whoami":
        args.skipWhoami = true;
        break;
      case "--dry-run":
        args.dryRun = true;
        break;
      case "--yes":
      case "-y":
        args.yes = true;
        break;
      case "--help":
      case "-h":
        args.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${token}`);
    }
  }

  return args;
}

function run(command, args, options = {}) {
  const { cwd, env, capture = false } = options;
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(command, args, {
      cwd,
      env: env ?? process.env,
      stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    });

    let stdout = "";
    let stderr = "";

    if (capture) {
      child.stdout.on("data", (chunk) => {
        stdout += chunk.toString();
      });
      child.stderr.on("data", (chunk) => {
        stderr += chunk.toString();
      });
    }

    child.on("error", rejectPromise);
    child.on("close", (code) => {
      resolvePromise({ code: code ?? 1, stdout, stderr });
    });
  });
}

function sleep(ms) {
  return new Promise((resolvePromise) => {
    setTimeout(resolvePromise, ms);
  });
}

async function waitWithCountdown(seconds, label) {
  if (seconds <= 0) return;

  for (let remaining = seconds; remaining > 0; remaining -= 1) {
    process.stdout.write(`\r${label} ${remaining}s...`);
    await sleep(1000);
  }
  process.stdout.write(`\r${label} done.      \n`);
}

function resolveAccess(inputAccess, publishConfigAccess) {
  const access = inputAccess ?? publishConfigAccess ?? "public";
  if (access !== "public" && access !== "restricted") {
    throw new Error(`Invalid --access value: ${access}`);
  }
  return access;
}

function npmAuthLine(registry, token) {
  const parsed = new URL(registry);
  const pathname = parsed.pathname.endsWith("/") ? parsed.pathname : `${parsed.pathname}/`;
  return `//${parsed.host}${pathname}:_authToken=${token}`;
}

function trimCommandOutput(result) {
  return `${result.stdout || ""}\n${result.stderr || ""}`.trim();
}

async function readPackage(projectDir) {
  const packagePath = resolve(projectDir, "package.json");
  const raw = await readFile(packagePath, "utf8");
  const pkg = JSON.parse(raw);
  if (!pkg.name || !pkg.version) {
    throw new Error("package.json must contain name and version");
  }
  return pkg;
}

async function versionExists(name, version, registry) {
  const result = await run("npm", ["view", `${name}@${version}`, "version", "--registry", registry, "--json"], {
    capture: true,
  });

  if (result.code === 0) return { exists: true };

  const output = trimCommandOutput(result);
  if (/E404|\b404\b/.test(output)) return { exists: false };

  return { exists: false, warning: output };
}

async function readToken(opRef, tokenEnv) {
  const envToken = process.env[tokenEnv]?.trim();
  if (envToken) return envToken;

  if (!opRef) {
    throw new Error(`No token found. Provide --op <op://...> or set ${tokenEnv}.`);
  }

  const opResult = await run("op", ["read", "--no-newline", opRef], { capture: true });
  if (opResult.code !== 0) {
    throw new Error(`Failed to read token from 1Password: ${opResult.stderr.trim() || opResult.stdout.trim()}`);
  }

  const token = opResult.stdout.trim();
  if (!token) {
    throw new Error("Token from 1Password was empty.");
  }
  return token;
}

async function verifyPublishedVersion(options) {
  const {
    name,
    version,
    registry,
    initialWaitSeconds,
    attempts,
    intervalSeconds,
  } = options;

  console.log(
    `Published. Waiting ${initialWaitSeconds}s before verification (npm registry propagation window).`,
  );
  await waitWithCountdown(initialWaitSeconds, "Registry propagation:");

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const result = await run(
      "npm",
      ["view", `${name}@${version}`, "version", "--registry", registry, "--json"],
      { capture: true },
    );

    if (result.code === 0) {
      const reported = result.stdout.trim();
      return {
        ok: true,
        version: reported.replace(/^"|"$/g, "") || version,
      };
    }

    const output = trimCommandOutput(result);
    const looksTransient404 = /E404|\b404\b/.test(output);

    if (attempt < attempts) {
      if (looksTransient404) {
        console.log(`Verification attempt ${attempt}/${attempts}: not visible yet (404).`);
      } else {
        console.log(`Verification attempt ${attempt}/${attempts}: command failed.`);
        if (output) {
          console.log(`  ${output.split("\n")[0]}`);
        }
      }
      await waitWithCountdown(intervalSeconds, "Retry wait:");
      continue;
    }

    return {
      ok: false,
      error: output || "Unknown verification error",
    };
  }

  return {
    ok: false,
    error: "Verification attempts exhausted.",
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    usage();
    return;
  }

  const projectDir = resolve(args.project);
  const pkg = await readPackage(projectDir);
  const access = resolveAccess(args.access, pkg.publishConfig?.access);

  console.log(`Project: ${projectDir}`);
  console.log(`Package: ${pkg.name}@${pkg.version}`);
  console.log(`Registry: ${args.registry}`);
  console.log(`Access: ${access}`);

  const existing = await versionExists(pkg.name, pkg.version, args.registry);
  if (existing.warning) {
    console.warn(`npm view warning: ${existing.warning}`);
  }
  if (existing.exists && !args.allowExistingVersion) {
    throw new Error(
      `Version already exists: ${pkg.name}@${pkg.version}. Use --allow-existing-version to proceed anyway.`,
    );
  }

  if (args.dryRun) {
    console.log("Dry run mode: running npm publish --dry-run only.");
    const dryArgs = ["publish", "--dry-run", "--registry", args.registry, "--access", access];
    if (args.yes) dryArgs.push("--yes");
    const dryResult = await run("npm", dryArgs, { cwd: projectDir });
    if (dryResult.code !== 0) process.exit(dryResult.code);
    return;
  }

  const token = await readToken(args.op, args.tokenEnv);
  let tempDir = "";
  try {
    tempDir = await mkdtemp(join(tmpdir(), "npm-bootstrap-publish-"));
    const userConfigPath = join(tempDir, "npmrc");
    const npmrc = [
      `registry=${args.registry}`,
      "always-auth=true",
      npmAuthLine(args.registry, token),
      "",
    ].join("\n");
    await writeFile(userConfigPath, npmrc, { encoding: "utf8", mode: 0o600 });

    if (!args.skipWhoami) {
      const whoami = await run("npm", ["whoami", "--registry", args.registry, "--userconfig", userConfigPath], {
        cwd: projectDir,
      });
      if (whoami.code !== 0) process.exit(whoami.code);
    }

    const publishArgs = ["publish", "--registry", args.registry, "--userconfig", userConfigPath, "--access", access];
    if (args.yes) publishArgs.push("--yes");

    const publish = await run("npm", publishArgs, { cwd: projectDir });
    if (publish.code !== 0) process.exit(publish.code);

    const verification = await verifyPublishedVersion({
      name: pkg.name,
      version: pkg.version,
      registry: args.registry,
      initialWaitSeconds: args.verifyInitialWaitSeconds,
      attempts: args.verifyAttempts,
      intervalSeconds: args.verifyIntervalSeconds,
    });

    if (verification.ok) {
      console.log(`Published. npm reports version: ${verification.version}`);
    } else {
      console.warn("Published, but version verification did not succeed in the configured window.");
      console.warn(verification.error);
      console.warn(
        `Tip: rerun manually after a minute:\n  npm view ${pkg.name}@${pkg.version} version --registry ${args.registry}`,
      );
    }

    console.log("Next: configure npm Trusted Publisher for this package and revoke bootstrap token.");
  } finally {
    if (tempDir) {
      await rm(tempDir, { recursive: true, force: true });
    }
  }
}

main().catch((error) => {
  console.error(`npm-bootstrap-publish error: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
