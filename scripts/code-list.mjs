#!/usr/bin/env node

/**
summary: "List programming files with top-level metadata comments."
read_when:
  - You need quick summary/read_when hints before opening implementation files.
*/

import { execSync } from 'node:child_process';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const EXCLUDED_DIRS = new Set([
  '.git',
  'node_modules',
  'archive',
  'research',
  '.venv',
  'venv',
  '__pycache__',
  'dist',
  'build',
]);

const DEFAULT_EXTENSIONS = new Set([
  '.js',
  '.mjs',
  '.cjs',
  '.ts',
  '.tsx',
  '.jsx',
  '.py',
  '.sh',
  '.bash',
  '.zsh',
  '.go',
  '.rs',
  '.java',
  '.kt',
  '.swift',
  '.rb',
  '.php',
  '.lua',
  '.c',
  '.h',
  '.cpp',
  '.hpp',
  '.cc',
  '.cs',
]);

function getArgValues(flag) {
  const values = [];
  const prefix = `${flag}=`;
  for (let i = 2; i < process.argv.length; i += 1) {
    const arg = process.argv[i];
    if (arg === flag) {
      const value = process.argv[i + 1];
      if (value && !value.startsWith('-')) {
        values.push(value);
        i += 1;
      }
      continue;
    }
    if (arg.startsWith(prefix)) {
      const value = arg.slice(prefix.length).trim();
      if (value.length > 0) values.push(value);
    }
  }
  return values;
}

function hasFlag(flag) {
  const prefix = `${flag}=`;
  return process.argv.includes(flag) || process.argv.some((arg) => arg.startsWith(prefix));
}

function getRepoRoot(cwd) {
  try {
    const out = execSync('git rev-parse --show-toplevel', {
      cwd,
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    });
    const root = out.trim();
    if (root.length > 0) return root;
  } catch {
    // ignore
  }
  return cwd;
}

function compactStrings(values) {
  const result = [];
  for (const value of values) {
    if (value === null || value === undefined) continue;
    const normalized = String(value).trim();
    if (normalized.length > 0) result.push(normalized);
  }
  return result;
}

function safeStat(targetPath) {
  try {
    return statSync(targetPath);
  } catch {
    return null;
  }
}

function isDirectory(targetPath) {
  const stat = safeStat(targetPath);
  return Boolean(stat?.isDirectory());
}

function hasGitMarker(dir) {
  const marker = safeStat(path.join(dir, '.git'));
  if (!marker) return false;
  return marker.isDirectory() || marker.isFile();
}

function dedupeSorted(paths) {
  return [...new Set(paths.map((value) => path.resolve(value)))].sort((a, b) => a.localeCompare(b));
}

function resolveScanInput(input, { cwd, repoRoot }) {
  if (path.isAbsolute(input)) return path.resolve(input);

  const fromCwd = path.resolve(cwd, input);
  if (isDirectory(fromCwd)) return fromCwd;

  const fromRepoRoot = path.resolve(repoRoot, input);
  if (isDirectory(fromRepoRoot)) return fromRepoRoot;

  return fromCwd;
}

function listSubdirectories(dir) {
  if (!isDirectory(dir)) return [];

  let entries = [];
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }

  return entries
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.') && !EXCLUDED_DIRS.has(entry.name))
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

function discoverCodeDirs(baseDir) {
  const dirs = new Set();
  const addIfDir = (targetPath) => {
    if (isDirectory(targetPath)) dirs.add(path.resolve(targetPath));
  };

  addIfDir(baseDir);

  for (const top of ['src', 'extensions', 'scripts', 'tests']) {
    addIfDir(path.join(baseDir, top));
  }

  for (const parentName of ['templates', 'copier', 'packages']) {
    const parentDir = path.join(baseDir, parentName);
    const firstLevel = listSubdirectories(parentDir);
    for (const child of firstLevel) {
      const childDir = path.join(parentDir, child);
      addIfDir(childDir);

      const secondLevel = listSubdirectories(childDir);
      for (const nested of secondLevel) {
        addIfDir(path.join(childDir, nested));
      }
    }
  }

  return [...dirs].sort((a, b) => a.localeCompare(b));
}

function findChildGitRepos(rootDir) {
  const repos = new Set();

  function walk(dir, isRoot = false) {
    if (!isRoot && hasGitMarker(dir)) {
      repos.add(path.resolve(dir));
      return;
    }

    let entries = [];
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.')) continue;
      if (EXCLUDED_DIRS.has(entry.name)) continue;
      walk(path.join(dir, entry.name), false);
    }
  }

  walk(rootDir, true);
  return [...repos].sort((a, b) => a.localeCompare(b));
}

function parseExtensions(values) {
  const normalized = new Set(DEFAULT_EXTENSIONS);
  for (const raw of values) {
    for (const part of raw.split(',')) {
      const trimmed = part.trim().toLowerCase();
      if (!trimmed) continue;
      const ext = trimmed.startsWith('.') ? trimmed : `.${trimmed}`;
      normalized.add(ext);
    }
  }
  return normalized;
}

function walkCodeFiles(dir, base, extensions) {
  let entries = [];
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }

  const files = [];
  for (const entry of entries) {
    if (entry.name.startsWith('.')) continue;
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      if (EXCLUDED_DIRS.has(entry.name)) continue;
      files.push(...walkCodeFiles(fullPath, base, extensions));
      continue;
    }

    if (!entry.isFile()) continue;
    const ext = path.extname(entry.name).toLowerCase();
    if (!extensions.has(ext)) continue;

    files.push(path.relative(base, fullPath));
  }

  return files;
}

function stripOuterQuotes(value) {
  const trimmed = value.trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

function parseMetadataLines(lines) {
  let summaryLine = null;
  const readWhen = [];
  let collectingField = null;

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (line.startsWith('summary:')) {
      summaryLine = line;
      collectingField = null;
      continue;
    }

    if (line.startsWith('read_when:')) {
      collectingField = 'read_when';
      const inline = line.slice('read_when:'.length).trim();
      if (inline.startsWith('[') && inline.endsWith(']')) {
        try {
          const parsed = JSON.parse(inline.replace(/'/g, '"'));
          if (Array.isArray(parsed)) readWhen.push(...compactStrings(parsed));
        } catch {
          // ignore malformed inline arrays
        }
      }
      continue;
    }

    if (collectingField === 'read_when') {
      if (line.startsWith('- ')) {
        const hint = line.slice(2).trim();
        if (hint) readWhen.push(hint);
      } else if (line === '') {
        // ignore
      } else {
        collectingField = null;
      }
    }
  }

  if (!summaryLine) {
    return { summary: null, readWhen, error: 'summary key missing' };
  }

  const summaryValue = stripOuterQuotes(summaryLine.slice('summary:'.length));
  const normalized = summaryValue.replace(/\s+/g, ' ').trim();
  if (!normalized) {
    return { summary: null, readWhen, error: 'summary is empty' };
  }

  return { summary: normalized, readWhen };
}

function extractLeadingCommentLines(content) {
  const lines = content.replace(/^\uFEFF/, '').split(/\r?\n/);

  let index = 0;
  if (lines[index] && lines[index].startsWith('#!')) index += 1;
  while (index < lines.length && lines[index].trim() === '') index += 1;
  if (index >= lines.length) return null;

  const first = lines[index].trim();

  if (first.startsWith('/**') || first.startsWith('/*')) {
    const commentLines = [];
    let ended = false;

    for (let i = index; i < lines.length; i += 1) {
      commentLines.push(lines[i]);
      if (lines[i].includes('*/')) {
        ended = true;
        break;
      }
    }

    if (!ended) return null;

    const cleaned = commentLines.map((raw, idx) => {
      let line = raw;
      if (idx === 0) line = line.replace(/^\s*\/\*\*?/, '');
      if (idx === commentLines.length - 1) line = line.replace(/\*\/\s*$/, '');
      line = line.replace(/^\s*\*\s?/, '');
      return line;
    });

    return { style: 'block', lines: cleaned };
  }

  if (first.startsWith('//')) {
    const cleaned = [];
    for (let i = index; i < lines.length; i += 1) {
      const current = lines[i].trim();
      if (!current.startsWith('//')) break;
      cleaned.push(lines[i].replace(/^\s*\/\/+\s?/, ''));
    }
    return { style: 'line-slash', lines: cleaned };
  }

  if (first.startsWith('#')) {
    const cleaned = [];
    for (let i = index; i < lines.length; i += 1) {
      const current = lines[i].trim();
      if (!current.startsWith('#')) break;
      cleaned.push(lines[i].replace(/^\s*#\s?/, ''));
    }
    return { style: 'line-hash', lines: cleaned };
  }

  if (first.startsWith('--')) {
    const cleaned = [];
    for (let i = index; i < lines.length; i += 1) {
      const current = lines[i].trim();
      if (!current.startsWith('--')) break;
      cleaned.push(lines[i].replace(/^\s*--\s?/, ''));
    }
    return { style: 'line-lua', lines: cleaned };
  }

  return null;
}

function extractMetadata(fullPath) {
  let content = '';
  try {
    content = readFileSync(fullPath, 'utf8');
  } catch (error) {
    const code = error && typeof error === 'object' && 'code' in error ? String(error.code) : 'read failed';
    return { summary: null, readWhen: [], commentStyle: null, error: `unreadable file (${code})` };
  }

  const comment = extractLeadingCommentLines(content);
  if (!comment) {
    return { summary: null, readWhen: [], commentStyle: null, error: 'missing top-level comment' };
  }

  const parsed = parseMetadataLines(comment.lines);
  return { ...parsed, commentStyle: comment.style };
}

function collectItemsForCodeDir(codeDir, extensions, strict) {
  const codeFiles = walkCodeFiles(codeDir, codeDir, extensions).sort((a, b) => a.localeCompare(b));
  const items = [];

  for (const relativePath of codeFiles) {
    const fullPath = path.join(codeDir, relativePath);
    const meta = extractMetadata(fullPath);
    if (!strict && !meta.summary) continue;
    items.push({ codeDir, path: relativePath, ...meta });
  }

  return { codeDir, codeFiles, items };
}

function noCodeErrorMessage(paths) {
  if (paths.length === 1) return `code-list: no scan dir at ${paths[0]}`;
  return `code-list: no scan dirs found (tried ${paths.length} locations)`;
}

function usage() {
  console.log(`Usage: node scripts/code-list.mjs [options]\n
Options:
  --code <dir>        Scan directory (repeatable)
  --workspace         Also scan child git repos
  --discover          Include common code roots (src/extensions/scripts/tests/packages)
  --ext <list>        Add extensions (comma-separated or repeatable)
  --strict            Include files missing metadata with error reasons
  --json              Output JSON
  -h, --help          Show this help\n
Metadata format in top-level comment:
  summary: "one-line summary"
  read_when:
    - "when this file should be read"`);
}

function main() {
  if (hasFlag('-h') || hasFlag('--help')) {
    usage();
    return;
  }

  const cwd = process.cwd();
  const repoRoot = getRepoRoot(cwd);

  const json = hasFlag('--json');
  const strict = hasFlag('--strict');
  const useDiscover = hasFlag('--discover');
  const useWorkspace = hasFlag('--workspace');

  const extensions = parseExtensions(getArgValues('--ext'));
  const codeArgs = getArgValues('--code');
  const codeDirFromEnv = process.env.CODE_DIR?.trim();

  const scanDirs = new Set();
  const attemptedPaths = [];
  const missingPaths = [];

  if (codeArgs.length > 0) {
    for (const raw of codeArgs) {
      const resolved = resolveScanInput(raw, { cwd, repoRoot });
      attemptedPaths.push(resolved);
      if (isDirectory(resolved)) scanDirs.add(resolved);
      else missingPaths.push({ path: resolved, source: '--code', raw });
    }
  } else if (codeDirFromEnv) {
    const resolved = resolveScanInput(codeDirFromEnv, { cwd, repoRoot });
    attemptedPaths.push(resolved);
    if (isDirectory(resolved)) scanDirs.add(resolved);
    else missingPaths.push({ path: resolved, source: 'CODE_DIR', raw: codeDirFromEnv });
  } else {
    attemptedPaths.push(repoRoot);
    if (isDirectory(repoRoot)) scanDirs.add(repoRoot);
  }

  if (useDiscover) {
    const discovered = discoverCodeDirs(cwd);
    for (const dir of discovered) scanDirs.add(dir);
  }

  let workspaceRepos = [];
  if (useWorkspace) {
    workspaceRepos = findChildGitRepos(cwd);
    for (const repoDir of workspaceRepos) {
      scanDirs.add(path.resolve(repoDir));
      if (useDiscover) {
        const discovered = discoverCodeDirs(repoDir);
        for (const dir of discovered) scanDirs.add(dir);
      }
    }
  }

  const scanDirList = dedupeSorted([...scanDirs]);

  if (scanDirList.length === 0) {
    const attempted = dedupeSorted(attemptedPaths.length > 0 ? attemptedPaths : [repoRoot]);
    const msg = noCodeErrorMessage(attempted);

    if (json) {
      process.stdout.write(
        JSON.stringify(
          {
            ok: false,
            error: msg,
            cwd,
            repoRoot,
            attemptedScanDirs: attempted,
            missing: missingPaths,
            workspaceRepos,
          },
          null,
          2
        ) + '\n'
      );
      return;
    }

    console.log(msg);
    console.log('Tip: pass --code <path> (repeatable), use --discover, or use --workspace.');
    process.exitCode = 2;
    return;
  }

  const collections = scanDirList.map((scanDir) => collectItemsForCodeDir(scanDir, extensions, strict));
  const items = collections.flatMap((collection) => collection.items);

  if (json) {
    process.stdout.write(
      JSON.stringify(
        {
          ok: true,
          cwd,
          repoRoot,
          scanDir: scanDirList[0] ?? null,
          scanDirs: scanDirList,
          missing: missingPaths,
          workspaceRepos,
          strict,
          extensions: [...extensions].sort((a, b) => a.localeCompare(b)),
          items,
        },
        null,
        2
      ) + '\n'
    );
    return;
  }

  if (scanDirList.length === 1) {
    console.log('Listing programming files with metadata comments:');
  } else {
    console.log(`Listing programming files across ${scanDirList.length} scan folders:`);
  }

  if (missingPaths.length > 0) {
    for (const missing of missingPaths) {
      console.log(`Warning: missing scan dir (${missing.source}): ${missing.path}`);
    }
    console.log('');
  }

  for (const collection of collections) {
    if (scanDirList.length > 1) {
      console.log(`[${collection.codeDir}]`);
    }

    for (const item of collection.items) {
      if (item.summary) {
        console.log(`${item.path} - ${item.summary}`);
        if (item.readWhen.length > 0) {
          console.log(`  Read when: ${item.readWhen.join('; ')}`);
        }
      } else {
        const reason = item.error ? ` - [${item.error}]` : '';
        console.log(`${item.path}${reason}`);
      }
    }

    if (scanDirList.length > 1) console.log('');
  }

  if (items.length === 0 && !strict) {
    console.log('No metadata headers found. Add top-level comment metadata with summary/read_when.');
  }

  console.log(
    '\nTip: add summary/read_when to top-level comments in frequently-touched source files to reduce broad file reads.'
  );
}

main();
