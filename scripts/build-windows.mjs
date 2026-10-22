#!/usr/bin/env node
/**
 * Builds the Windows package for One-Line Physics Draw.
 *
 *   node scripts/build-windows.mjs [--out <dir>] [--skip-exe] [--no-selftest] [--keep-temp]
 *
 * Pipeline:
 *   1. scripts/build-offline-html.mjs  -> windows/build/index.html (single self-contained page)
 *   2. generated_assets.h              -> the page + favicon as C byte arrays
 *   3. zig cc                          -> Physics-Draw.exe (x86_64 Windows, static, no runtime)
 *   4. self-test                       -> the same source compiled for this host is started and
 *                                         probed over HTTP, so the serving logic is verified on
 *                                         every build even though Linux cannot run the .exe
 *   5. package                         -> folder + Physics-Draw-Windows.zip + SHA256SUMS.txt
 *
 * Only Zig is required (any of: `zig` on PATH, the `ziglang` PyPI package, or $ZIG).
 * Everything else is Node standard library, so this runs unchanged on the GitHub runner.
 */

import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync
} from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateRawSync, inflateRawSync } from 'node:zlib';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const app = JSON.parse(readFileSync(path.join(repoRoot, 'windows', 'app.json'), 'utf8'));

function fail(message) {
  console.error(`build-windows: ${message}`);
  process.exit(1);
}

/* ------------------------------------------------------------------ cli --- */

const options = {
  out: path.join(repoRoot, 'windows-release'),
  skipExe: false,
  selfTest: true,
  keepTemp: false
};
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i += 1) {
  const arg = argv[i];
  if (arg === '--out' || arg === '--out=') {
    options.out = path.resolve(process.cwd(), argv[i + 1] || '');
    i += 1;
  } else if (arg.startsWith('--out=')) {
    options.out = path.resolve(process.cwd(), arg.slice('--out='.length));
  } else if (arg === '--skip-exe') {
    options.skipExe = true;
  } else if (arg === '--no-selftest') {
    options.selfTest = false;
  } else if (arg === '--keep-temp') {
    options.keepTemp = true;
  } else if (arg === '--help' || arg === '-h') {
    console.log('Usage: node scripts/build-windows.mjs [--out <dir>] [--skip-exe] [--no-selftest] [--keep-temp]');
    process.exit(0);
  } else {
    fail(`unknown argument: ${arg}`);
  }
}

function findZig() {
  /* $ZIG may hold a full command line, e.g. "/path/to/python -m ziglang". */
  const configured = (process.env.ZIG || 'zig').trim().split(/\s+/);
  const [direct, ...directArgs] = configured;
  const probe = spawnSync(direct, [...directArgs, 'version'], { encoding: 'utf8' });
  if (probe.status === 0 && probe.stdout) {
    return { command: direct, args: directArgs, version: probe.stdout.trim() };
  }
  for (const python of ['python3', 'python']) {
    const viaPython = spawnSync(python, ['-m', 'ziglang', 'version'], { encoding: 'utf8' });
    if (viaPython.status === 0 && viaPython.stdout) {
      return { command: python, args: ['-m', 'ziglang'], version: viaPython.stdout.trim() };
    }
  }
  fail('Zig was not found. Install it with `pip install ziglang` or put `zig` on PATH (or set $ZIG).');
}

const buildDir = path.join(repoRoot, 'windows', 'build');
const packageDir = path.join(options.out, app.packageName);
const step = (message) => console.log(`build-windows: ${message}`);

/* Fail on a missing toolchain before touching any previous build output. */
const zig = options.skipExe ? null : findZig();

/* ------------------------------------------------- 1. offline html build --- */

rmSync(buildDir, { recursive: true, force: true });
mkdirSync(buildDir, { recursive: true });
rmSync(options.out, { recursive: true, force: true });
mkdirSync(packageDir, { recursive: true });

const offlineHtmlPath = path.join(buildDir, 'index.html');
const offlineBuild = spawnSync(
  process.execPath,
  [path.join(repoRoot, 'scripts', 'build-offline-html.mjs'), '--out', offlineHtmlPath, '--quiet'],
  { cwd: repoRoot, encoding: 'utf8' }
);
if (offlineBuild.status !== 0) {
  process.stderr.write(offlineBuild.stderr || '');
  fail('the offline HTML build failed');
}
const offlineHtml = readFileSync(offlineHtmlPath);
step(`offline page: ${offlineHtml.length.toLocaleString('en-US')} bytes (no CDN dependencies)`);

if (options.skipExe) {
  copyFileSync(offlineHtmlPath, path.join(packageDir, 'index.html'));
  step(`--skip-exe: wrote ${path.relative(repoRoot, packageDir)}/index.html only`);
  process.exit(0);
}

/* -------------------------------------------------- 2. generated assets --- */

function toCArray(name, buffer) {
  const lines = [];
  if (buffer.length === 0) {
    return [`static const unsigned char ${name}[1] = {0};`, `static const unsigned long ${name}_LEN = 0UL;`].join('\n');
  }
  lines.push(`static const unsigned char ${name}[] = {`);
  for (let offset = 0; offset < buffer.length; offset += 16) {
    const slice = buffer.subarray(offset, Math.min(offset + 16, buffer.length));
    const body = Array.from(slice, (byte) => `0x${byte.toString(16).padStart(2, '0')}`).join(',');
    lines.push(offset + 16 < buffer.length ? `${body},` : `${body}`);
  }
  lines.push('};');
  lines.push(`static const unsigned long ${name}_LEN = ${buffer.length}UL;`);
  return lines.join('\n');
}

const faviconPath = path.join(repoRoot, 'assets', 'favicon-64.png');
if (!existsSync(faviconPath)) fail(`missing favicon: ${path.relative(repoRoot, faviconPath)}`);
const favicon = readFileSync(faviconPath);

const generatedHeader = [
  '/* Generated by scripts/build-windows.mjs - do not edit. */',
  '#ifndef PHYSICS_DRAW_GENERATED_ASSETS_H',
  '#define PHYSICS_DRAW_GENERATED_ASSETS_H',
  '',
  `#define APP_NAME "${app.name}"`,
  `#define APP_VERSION "${app.version}"`,
  `#define HEALTH_TOKEN "${app.healthToken}"`,
  '',
  toCArray('INDEX_HTML', offlineHtml),
  toCArray('FAVICON_PNG', favicon),
  '',
  '#endif'
].join('\n');

const headerPath = path.join(buildDir, 'generated_assets.h');
writeFileSync(headerPath, generatedHeader);
step(`generated assets header: ${(statSync(headerPath).size / 1024 / 1024).toFixed(2)} MiB`);

/* ------------------------------------------------------------- 3. zig --- */

step(`zig ${zig.version} (${zig.command}${zig.args.length ? ` ${zig.args.join(' ')}` : ''})`);

function compile(target, output, extraArgs = []) {
  const args = [
    ...zig.args,
    'cc',
    '-O2',
    '-std=c11',
    '-Wall',
    '-Wextra',
    '-Wno-unused-parameter',
    `-I${buildDir}`,
    `-o${output}`,
    path.join(repoRoot, 'windows', 'launcher.c'),
    ...(target === 'native' ? [] : [`-target`, target]),
    ...extraArgs
  ];
  step(`compiling ${target === 'native' ? 'host' : target} -> ${path.basename(output)}`);
  const result = spawnSync(zig.command, args, { cwd: repoRoot, stdio: 'inherit' });
  if (result.status !== 0) fail(`zig cc failed for ${target}`);
  if (!existsSync(output)) fail(`compiler did not produce ${output}`);
  return output;
}

/* Stage the compiler output in windows/build so nothing but the executable reaches the package
   folder - Zig also drops a .pdb next to every Windows binary it links. */
const stagedExecutable = path.join(buildDir, `${app.binaryName}.exe`);
const executablePath = path.join(packageDir, `${app.binaryName}.exe`);
const windowsLibraries = (app.windowsLibraries || []).map((library) => `-l${library}`);
compile(app.windowsTarget, stagedExecutable, windowsLibraries);
copyFileSync(stagedExecutable, executablePath);
const executable = readFileSync(executablePath);
step(`executable: ${(executable.length / 1024).toFixed(0)} KiB`);

/* ------------------------------------------------------- 4. verification --- */

const problems = [];
if (executable.subarray(0, 2).toString('latin1') !== 'MZ') problems.push('missing MZ header');
if (!executable.includes(Buffer.from('PE\0\0', 'latin1'))) problems.push('missing PE signature');

/* Parse the PE header so the report proves this is a 64-bit Windows console executable. */
const peOffset = executable.readUInt32LE(0x3c);
const machine = executable.readUInt16LE(peOffset + 4);
const subsystem = executable.readUInt16LE(peOffset + 24 + 68);
if (executable.subarray(peOffset, peOffset + 4).toString('latin1') !== 'PE\0\0') problems.push('PE signature is not at the offset stored in the DOS header');
if (machine !== 0x8664) problems.push(`unexpected PE machine type 0x${machine.toString(16)} (want 0x8664 x86-64)`);
if (subsystem !== 3) problems.push(`unexpected PE subsystem ${subsystem} (want 3 = console)`);
if (executable.length < app.minimumExecutableBytes) problems.push('executable is suspiciously small');
if (executable.length > app.maximumExecutableBytes) problems.push('executable is suspiciously large');
if (!executable.includes(Buffer.from(app.healthToken, 'utf8'))) problems.push('health token not embedded');
for (const host of ['cdnjs.cloudflare.com', 'fonts.googleapis.com', 'fonts.gstatic.com', 'unpkg.com', 'jsdelivr.net']) {
  if (executable.includes(Buffer.from(host, 'utf8'))) problems.push(`executable still references ${host}`);
}
for (const dll of ['WS2_32.dll', 'SHELL32.dll', 'KERNEL32.dll']) {
  const wide = Buffer.from(dll, 'utf16le');
  if (!executable.includes(Buffer.from(dll, 'latin1')) && !executable.includes(wide)) {
    problems.push(`executable does not import ${dll}`);
  }
}
if (problems.length) fail(`executable verification failed:\n  - ${problems.join('\n  - ')}`);
step(`executable verification passed (PE x86-64 console app, ${executable.length.toLocaleString('en-US')} bytes, imports ws2_32/shell32, offline page embedded, no CDN hosts)`);

/* --------------------------------------------------------- 5. self-test --- */

function request(port, method, target) {
  return new Promise((resolve, reject) => {
    const call = http.request({ host: '127.0.0.1', port, method, path: target }, (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => resolve({
        status: response.statusCode,
        headers: response.headers,
        body: Buffer.concat(chunks)
      }));
    });
    call.on('error', reject);
    call.setTimeout(15000, () => call.destroy(new Error(`timeout for ${method} ${target}`)));
    call.end();
  });
}

async function selfTest() {
  const testBinary = path.join(buildDir, 'physics-draw-selftest');
  compile(app.selfTestTarget, testBinary);

  const server = spawn(testBinary, ['--port', '0', '--no-browser'], {
    cwd: buildDir,
    stdio: ['ignore', 'pipe', 'pipe']
  });

  let announced = '';
  const ready = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`launcher never announced a URL:\n${announced}`)), 15000);
    server.stdout.on('data', (chunk) => {
      announced += chunk.toString('utf8');
      const match = announced.match(/http:\/\/127\.0\.0\.1:(\d+)\//);
      if (match) {
        clearTimeout(timer);
        resolve(Number(match[1]));
      }
    });
    server.on('error', reject);
    server.on('exit', (code) => reject(new Error(`launcher exited early with code ${code}\n${announced}`)));
  });

  let port;
  try {
    port = await ready;
    step(`self-test server listening on 127.0.0.1:${port}`);

    const checks = [];
    const index = await request(port, 'GET', '/');
    checks.push(['GET / status', index.status === 200, `got ${index.status}`]);
    checks.push(['GET / content-type', /text\/html; charset=utf-8/.test(String(index.headers['content-type'])), String(index.headers['content-type'])]);
    checks.push(['GET / body matches offline page', index.body.equals(offlineHtml), `${index.body.length} bytes served`]);
    checks.push(['GET / no CDN reference', !/cdnjs\.cloudflare\.com|fonts\.googleapis\.com/.test(index.body.toString('utf8')), 'offline page is self-contained']);

    const explicit = await request(port, 'GET', '/index.html');
    checks.push(['GET /index.html', explicit.status === 200 && explicit.body.equals(offlineHtml), `got ${explicit.status}`]);

    const head = await request(port, 'HEAD', '/');
    checks.push(['HEAD / has content-length only', head.status === 200 && head.body.length === 0 && Number(head.headers['content-length']) === offlineHtml.length, `got ${head.status}, ${head.body.length} bytes`]);

    const icon = await request(port, 'GET', '/favicon.ico');
    checks.push(['GET /favicon.ico', icon.status === 200 && icon.body.equals(favicon), `got ${icon.status}`]);

    const healthPath = '/__physics-draw/health';
    if (!readFileSync(path.join(repoRoot, 'windows', 'launcher.c'), 'utf8').includes(`"${healthPath}"`)) {
      checks.push(['health path matches launcher.c', false, healthPath]);
    }
    const health = await request(port, 'GET', healthPath);
    let healthOk = false;
    try {
      healthOk = health.status === 200 && JSON.parse(health.body.toString('utf8')).app === app.healthToken;
    } catch {
      healthOk = false;
    }
    checks.push(['GET health endpoint', healthOk, health.body.toString('utf8').slice(0, 120)]);

    const missing = await request(port, 'GET', '/nope.html');
    checks.push(['GET unknown path is 404', missing.status === 404, `got ${missing.status}`]);

    const posted = await request(port, 'POST', '/');
    checks.push(['POST is rejected with 405', posted.status === 405, `got ${posted.status}`]);

    const extracted = path.join(buildDir, 'extracted.html');
    const extract = spawnSync(testBinary, ['--extract', extracted], { cwd: buildDir, encoding: 'utf8' });
    checks.push(['--extract writes the offline page', extract.status === 0 && existsSync(extracted) && readFileSync(extracted).equals(offlineHtml), extract.stderr || extract.stdout]);

    const version = spawnSync(testBinary, ['--version'], { cwd: buildDir, encoding: 'utf8' });
    checks.push(['--version reports the package version', version.status === 0 && version.stdout.includes(app.version), version.stdout.trim()]);

    let failed = 0;
    for (const [label, ok, detail] of checks) {
      if (!ok) failed += 1;
      console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${ok ? '' : ` (${detail})`}`);
    }
    if (failed) fail(`${failed} self-test check(s) failed`);
    step(`self-test passed (${checks.length} checks against the live launcher)`);
  } finally {
    server.kill('SIGTERM');
  }
}

if (options.selfTest) {
  await selfTest();
} else {
  step('--no-selftest: skipped the launcher self-test');
}

/* ----------------------------------------------------------- 6. package --- */

copyFileSync(offlineHtmlPath, path.join(packageDir, 'index.html'));
copyFileSync(path.join(repoRoot, 'windows', 'package-README.txt'), path.join(packageDir, 'README.txt'));

const sha256 = (file) => createHash('sha256').update(readFileSync(file)).digest('hex');
const entries = [`${app.binaryName}.exe`, 'index.html', 'README.txt'].sort();
/* SHA256SUMS.txt hashes the three files above and then travels inside the archive too. */
const packageEntries = [...entries, 'SHA256SUMS.txt'].sort();
writeFileSync(
  path.join(packageDir, 'SHA256SUMS.txt'),
  `${entries.map((name) => `${sha256(path.join(packageDir, name))}  ${name}`).join('\n')}\n`
);

/* Minimal ZIP writer (deflate + CRC32) so packaging needs no extra dependency. */
const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let index = 0; index < 256; index += 1) {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) {
      value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
    }
    table[index] = value;
  }
  return table;
})();

function crc32(buffer) {
  let crc = -1;
  for (let index = 0; index < buffer.length; index += 1) {
    crc = CRC_TABLE[(crc ^ buffer[index]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ -1) >>> 0;
}

function writeZip(zipPath, files) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  const now = new Date();
  const dosTime = ((now.getHours() << 11) | (now.getMinutes() << 5) | (now.getSeconds() >> 1)) & 0xffff;
  const dosDate = ((((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate()) & 0xffff);

  for (const file of files) {
    const name = Buffer.from(file.name, 'utf8');
    const data = readFileSync(file.path);
    const crc = crc32(data);
    const compressed = deflateRawSync(data, { level: 9 });
    const useDeflate = compressed.length < data.length;
    const payload = useDeflate ? compressed : data;
    const method = useDeflate ? 8 : 0;

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0, 6);
    local.writeUInt16LE(method, 8);
    local.writeUInt16LE(dosTime, 10);
    local.writeUInt16LE(dosDate, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(payload.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, name, payload);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0, 8);
    central.writeUInt16LE(method, 10);
    central.writeUInt16LE(dosTime, 12);
    central.writeUInt16LE(dosDate, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(payload.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt16LE(0, 30);
    central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34);
    central.writeUInt16LE(0, 36);
    central.writeUInt32LE(0, 38);
    central.writeUInt32LE(offset, 42);
    centrals.push(central, name);

    offset += local.length + name.length + payload.length;
  }

  const localPart = Buffer.concat(locals);
  const centralPart = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(centralPart.length, 12);
  end.writeUInt32LE(localPart.length, 16);
  end.writeUInt16LE(0, 20);
  writeFileSync(zipPath, Buffer.concat([localPart, centralPart, end]));
}

const zipPath = path.join(options.out, app.zipName);
const zipFiles = packageEntries.map((name) => ({
  name: `${app.packageName}/${name}`,
  path: path.join(packageDir, name)
}));
writeZip(zipPath, zipFiles);

/* Read the archive back and compare every entry byte-for-byte: a broken ZIP is worse than none. */
function verifyZip(zip, expected) {
  const end = zip.length - 22;
  if (end < 0 || zip.readUInt32LE(end) !== 0x06054b50) fail('zip is missing its end-of-central-directory record');
  const entryCount = zip.readUInt16LE(end + 10);
  const centralSize = zip.readUInt32LE(end + 12);
  const centralOffset = zip.readUInt32LE(end + 16);
  if (entryCount !== expected.length) fail(`zip holds ${entryCount} entries, expected ${expected.length}`);
  if (centralOffset + centralSize !== end) fail('zip central directory does not line up with its footer');

  let cursor = centralOffset;
  const seen = [];
  for (let index = 0; index < entryCount; index += 1) {
    if (zip.readUInt32LE(cursor) !== 0x02014b50) fail('zip central directory entry has a bad signature');
    const method = zip.readUInt16LE(cursor + 10);
    const crc = zip.readUInt32LE(cursor + 16);
    const compressedSize = zip.readUInt32LE(cursor + 20);
    const uncompressedSize = zip.readUInt32LE(cursor + 24);
    const nameLength = zip.readUInt16LE(cursor + 28);
    const extraLength = zip.readUInt16LE(cursor + 30);
    const commentLength = zip.readUInt16LE(cursor + 32);
    const localOffset = zip.readUInt32LE(cursor + 42);
    const name = zip.subarray(cursor + 46, cursor + 46 + nameLength).toString('utf8');
    seen.push(name);

    if (zip.readUInt32LE(localOffset) !== 0x04034b50) fail(`zip local header for ${name} is corrupt`);
    const localNameLength = zip.readUInt16LE(localOffset + 26);
    const localExtraLength = zip.readUInt16LE(localOffset + 28);
    const dataStart = localOffset + 30 + localNameLength + localExtraLength;
    const payload = zip.subarray(dataStart, dataStart + compressedSize);
    const data = method === 8 ? inflateRawSync(payload) : Buffer.from(payload);
    if (data.length !== uncompressedSize) fail(`zip entry ${name} unpacks to the wrong size`);
    if (crc32(data) !== crc) fail(`zip entry ${name} fails its CRC-32 check`);

    const source = expected.find((file) => file.name === name);
    if (!source) fail(`zip holds an unexpected entry: ${name}`);
    if (!data.equals(readFileSync(source.path))) fail(`zip entry ${name} differs from ${source.path}`);

    cursor += 46 + nameLength + extraLength + commentLength;
  }
  return seen;
}

const zipEntries = verifyZip(readFileSync(zipPath), zipFiles);
step(`zip verified: ${zipEntries.length} entries extracted and compared byte-for-byte`);

const zipBytes = statSync(zipPath).size;
const report = {
  generatedAt: new Date().toISOString(),
  version: app.version,
  binary: `${app.binaryName}.exe`,
  zig: zig.version,
  target: app.windowsTarget,
  executableBytes: executable.length,
  pe: { machine: `0x${machine.toString(16)}`, subsystem, subsystemName: subsystem === 3 ? 'console' : 'other' },
  offlineHtmlBytes: offlineHtml.length,
  zipBytes,
  sha256: {
    executable: sha256(executablePath),
    zip: sha256(zipPath)
  },
  files: packageEntries.map((name) => ({
    name: `${app.packageName}/${name}`,
    bytes: statSync(path.join(packageDir, name)).size
  }))
};
writeFileSync(path.join(options.out, 'build-report.json'), `${JSON.stringify(report, null, 2)}\n`);

if (!options.keepTemp) {
  for (const temporary of [
    stagedExecutable,
    `${stagedExecutable.replace(/\.exe$/, '')}.pdb`,
    path.join(buildDir, 'physics-draw-selftest'),
    path.join(buildDir, 'extracted.html'),
    headerPath
  ]) {
    rmSync(temporary, { force: true });
  }
}

const leftovers = readdirSync(packageDir).filter((name) => !packageEntries.includes(name));
if (leftovers.length) fail(`unexpected files in the package folder: ${leftovers.join(', ')}`);

step('');
step(`package: ${path.relative(repoRoot, packageDir)}/`);
for (const name of packageEntries) {
  step(`  ${name.padEnd(20)} ${statSync(path.join(packageDir, name)).size.toLocaleString('en-US')} bytes`);
}
step(`zip:     ${path.relative(repoRoot, zipPath)} (${(zipBytes / 1024).toFixed(0)} KiB)`);
step(`sha256:  ${report.sha256.zip}  ${app.zipName}`);
step(`report:  ${path.relative(repoRoot, path.join(options.out, 'build-report.json'))}`);
