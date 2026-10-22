#!/usr/bin/env node
/**
 * Build the Microsoft Store package: a windowed WebView2 executable plus a clean,
 * unsigned .msix ready to upload to Partner Center.
 *
 *   node scripts/build-store.mjs [--out windows-release] [--publisher "CN=..."] [--quiet]
 *
 * What it does, in order:
 *   1. builds the offline single-file page (scripts/build-offline-html.mjs)
 *   2. fetches the WebView2 SDK header + x64 loader DLL (scripts/fetch-webview2.mjs)
 *   3. generates the resource script (icon, manifest, version info) and the IID header
 *   4. cross-compiles windows/webview2-host.cpp into PhysicsDraw.exe (GUI subsystem)
 *   5. audits the PE: architecture, subsystem, imports, no CDN references
 *   6. lays out the payload (exe, loader DLL, www/index.html, Assets/)
 *   7. writes AppxManifest.xml, [Content_Types].xml and AppxBlockMap.xml
 *   8. packs the .msix and re-verifies it end to end
 *
 * The package is intentionally UNSIGNED: packages submitted through Partner Center are
 * re-signed by Microsoft after certification, so a signature here would only have to be
 * stripped again. For sideloading on your own PC you need a signing certificate whose
 * publisher matches AppxManifest.xml (see windows/README.md).
 */

import { spawnSync } from 'node:child_process';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { ensureWebView2 } from './fetch-webview2.mjs';
import {
  buildZip,
  crc32,
  deflateInBlocks,
  localHeaderSize,
  sha256,
  zipEntries,
  zipRead,
} from './lib/zip.mjs';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SCRIPT_DIR, '..');

/* --------------------------------------------------------------------- arguments */

function parseArgs(argv) {
  const options = {
    out: join(REPO_ROOT, 'windows-release'),
    publisher: process.env.MSIX_PUBLISHER ?? null,
    publisherDisplayName: process.env.MSIX_PUBLISHER_DISPLAY_NAME ?? null,
    identityName: process.env.MSIX_IDENTITY_NAME ?? null,
    version: process.env.MSIX_VERSION ?? null,
    quiet: false,
    keepTemp: false,
    forceWebview2: false,
  };
  const valued = ['out', 'publisher', 'publisher-display-name', 'identity-name', 'version'];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const eq = arg.indexOf('=');
    const name = eq >= 0 ? arg.slice(0, eq) : arg;
    const inline = eq >= 0 ? arg.slice(eq + 1) : null;
    const key = name.replace(/^--/, '').replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    if (arg === '--quiet' || arg === '-q') {
      options.quiet = true;
    } else if (arg === '--keep-temp') {
      options.keepTemp = true;
    } else if (arg === '--force-webview2') {
      options.forceWebview2 = true;
    } else if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (valued.includes(name.replace(/^--/, ''))) {
      const value = inline ?? argv[++i];
      if (!value) fail(`--${name.replace(/^--/, '')} needs a value`);
      if (key === 'out') options.out = resolve(process.cwd(), value);
      else options[key] = value;
    } else {
      fail(`unknown argument: ${arg}`);
    }
  }
  return options;
}

function fail(message) {
  throw new Error(message);
}

/* ------------------------------------------------------------------------ helpers */

const say = (options, ...args) => {
  if (!options.quiet) console.log(...args);
};

function findZig() {
  const fromEnv = process.env.ZIG;
  if (fromEnv && fromEnv.trim()) {
    const parts = fromEnv.trim().split(/\s+/);
    return { command: parts[0], prefix: parts.slice(1) };
  }
  const which = spawnSync(process.platform === 'win32' ? 'where' : 'which', ['zig'], {
    encoding: 'utf8',
  });
  if (which.status === 0 && which.stdout.trim()) {
    return { command: which.stdout.trim().split(/\r?\n/)[0], prefix: [] };
  }
  const pythonModule = spawnSync('python3', ['-m', 'ziglang', 'version'], { encoding: 'utf8' });
  if (pythonModule.status === 0) return { command: 'python3', prefix: ['-m', 'ziglang'] };
  fail(
    'zig was not found. Install it (pip install ziglang==0.17.0) or point ZIG at it, ' +
      'for example ZIG="/path/to/venv/bin/python -m ziglang".',
  );
}

function run(command, args, label) {
  const result = spawnSync(command, args, {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error) fail(`${label}: ${result.error.message}`);
  if (result.status !== 0) {
    const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
    fail(`${label} failed with exit code ${result.status}\n${output.slice(0, 4000)}`);
  }
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

const escapeXml = (value) =>
  String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const CRLF = '\r\n';
const toCrlf = (text) => text.replace(/\r?\n/g, CRLF);

/* --------------------------------------------------------------------- PE parsing */

function parsePe(buf, label) {
  if (buf.length < 0x40 || buf.readUInt16LE(0) !== 0x5a4d) fail(`${label}: not a PE image`);
  const pe = buf.readUInt32LE(0x3c);
  if (buf.toString('ascii', pe, pe + 4) !== 'PE\0\0') fail(`${label}: missing PE signature`);
  const machine = buf.readUInt16LE(pe + 4);
  const optional = pe + 24;
  if (buf.readUInt16LE(optional) !== 0x20b) fail(`${label}: not PE32+ (64-bit)`);
  const subsystem = buf.readUInt16LE(optional + 68);
  const directories = optional + 112;

  const sections = [];
  const sectionCount = buf.readUInt16LE(pe + 6);
  const sectionTable = optional + buf.readUInt16LE(pe + 20);
  for (let i = 0; i < sectionCount; i += 1) {
    const at = sectionTable + i * 40;
    sections.push({
      name: buf.toString('ascii', at, at + 8).replace(/\0.*$/, ''),
      virtualSize: buf.readUInt32LE(at + 8),
      virtualAddress: buf.readUInt32LE(at + 12),
      rawSize: buf.readUInt32LE(at + 16),
      rawPointer: buf.readUInt32LE(at + 20),
    });
  }
  const toOffset = (rva) => {
    const section = sections.find(
      (s) => rva >= s.virtualAddress && rva < s.virtualAddress + Math.max(s.virtualSize, s.rawSize),
    );
    if (!section) fail(`${label}: RVA 0x${rva.toString(16)} is not inside any section`);
    return section.rawPointer + (rva - section.virtualAddress);
  };
  const cstring = (rva) => {
    const at = toOffset(rva);
    let end = at;
    while (end < buf.length && buf[end] !== 0) end += 1;
    return buf.toString('ascii', at, end);
  };

  const importRva = buf.readUInt32LE(directories + 8);
  const imports = [];
  if (importRva !== 0) {
    let at = toOffset(importRva);
    for (;;) {
      const descriptor = buf.subarray(at, at + 20);
      if (descriptor.length < 20 || descriptor.every((b) => b === 0)) break;
      const nameRva = descriptor.readUInt32LE(12);
      if (nameRva === 0) break;
      imports.push(cstring(nameRva));
      at += 20;
    }
  }
  return { machine, subsystem, sections, imports, toOffset, cstring, buf };
}

/* ------------------------------------------------------------------- MSIX content */

function buildManifest(config) {
  const m = config.msix;
  const lines = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<Package',
    '    xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"',
    '    xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"',
    '    xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"',
    '    IgnorableNamespaces="uap rescap">',
    `    <Identity Name="${escapeXml(m.identityName)}" Publisher="${escapeXml(m.publisher)}"`,
    `              Version="${escapeXml(m.packageVersion)}" ProcessorArchitecture="x64" />`,
    '    <Properties>',
    `        <DisplayName>${escapeXml(m.displayName)}</DisplayName>`,
    `        <PublisherDisplayName>${escapeXml(m.publisherDisplayName)}</PublisherDisplayName>`,
    `        <Description>${escapeXml(m.description)}</Description>`,
    '        <Logo>Assets\\StoreLogo.png</Logo>',
    '    </Properties>',
    '    <Dependencies>',
    `        <TargetDeviceFamily Name="Windows.Desktop" MinVersion="${escapeXml(m.minVersion)}"`,
    `                              MaxVersionTested="${escapeXml(m.maxVersionTested)}" />`,
    '    </Dependencies>',
    '    <Resources>',
    ...m.languages.map((language) => `        <Resource Language="${escapeXml(language)}" />`),
    '    </Resources>',
    '    <Applications>',
    `        <Application Id="${escapeXml(m.applicationId)}" Executable="${escapeXml(m.binaryName)}"`,
    '                       EntryPoint="Windows.FullTrustApplication">',
    '            <uap:VisualElements',
    `                DisplayName="${escapeXml(m.displayName)}"`,
    `                Description="${escapeXml(m.shortDescription)}"`,
    `                BackgroundColor="${escapeXml(m.backgroundColor)}"`,
    '                Square150x150Logo="Assets\\Square150x150Logo.png"',
    '                Square44x44Logo="Assets\\Square44x44Logo.png">',
    '                <uap:DefaultTile Wide310x150Logo="Assets\\Wide310x150Logo.png" />',
    '                <uap:SplashScreen Image="Assets\\SplashScreen.png"',
    `                                  BackgroundColor="${escapeXml(m.backgroundColor)}" />`,
    '            </uap:VisualElements>',
    '        </Application>',
    '    </Applications>',
    '    <Capabilities>',
    '        <rescap:Capability Name="runFullTrust" />',
    '    </Capabilities>',
    '</Package>',
    '',
  ];
  // Partner Center and the deployment engine both expect the manifest the way makeappx
  // writes it: UTF-8 BOM, CRLF line endings.
  return `\uFEFF${toCrlf(lines.join('\n'))}`;
}

function buildContentTypes(payload) {
  const extensions = new Set(
    payload.map((file) => basename(file.name).split('.').pop().toLowerCase()),
  );
  const known = {
    exe: 'application/octet-stream',
    dll: 'application/octet-stream',
    png: 'image/png',
    html: 'text/html',
    txt: 'text/plain',
    json: 'application/json',
    js: 'application/javascript',
    css: 'text/css',
  };
  const defaults = [...extensions]
    .sort()
    .filter((ext) => ext !== 'xml')
    .map(
      (ext) =>
        `    <Default Extension="${ext}" ContentType="${known[ext] ?? 'application/octet-stream'}" />`,
    );
  // A bare "xml" default describes AppxManifest.xml; the block map needs its own type.
  const lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    ...defaults,
    '    <Default Extension="xml" ContentType="application/vnd.ms-appx.manifest+xml" />',
    '    <Override PartName="/AppxBlockMap.xml" ContentType="application/vnd.ms-appx.blockmap+xml" />',
    '</Types>',
    '',
  ];
  return toCrlf(lines.join('\n'));
}

/**
 * AppxBlockMap.xml, byte-for-byte the shape Microsoft's packer emits:
 * windows separators in Name, LfhSize = 30 + name length, base64 SHA-256 of each 64 KiB
 * uncompressed block, and the compressed size per block for compressed parts.
 */
function buildBlockMap(entries) {
  const parts = [
    '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
    '<BlockMap xmlns="http://schemas.microsoft.com/appx/2010/blockmap" ' +
      'HashMethod="http://www.w3.org/2001/04/xmlenc#sha256">',
  ];
  for (const entry of entries) {
    const blocks = entry.blocks ?? entry.precomputed?.blocks;
    if (!blocks) fail(`buildBlockMap: ${entry.name} was never deflated`);
    const windowsName = entry.name.replace(/\//g, '\\');
    parts.push(
      `    <File Name="${escapeXml(windowsName)}" Size="${entry.data.length}" LfhSize="${entry.lfhSize}">`,
    );
    for (const block of blocks) {
      const size = entry.method === 8 ? ` Size="${block.size}"` : '';
      parts.push(`        <Block Hash="${block.hash}"${size} />`);
    }
    parts.push('    </File>');
  }
  parts.push('</BlockMap>', '');
  return toCrlf(parts.join('\n'));
}

/* ----------------------------------------------------------------------- resource */

function buildResourceScript({ config, iconPath, manifestPath }) {
  const version = config.msix.packageVersion.split('.').map((n) => Number(n));
  const versionText = version.join(', ');
  const quoted = (value) => `"${value}"`;
  const lines = [
    `101 ICON ${quoted(iconPath)}`,
    `1 24 ${quoted(manifestPath)}`,
    '1 VERSIONINFO',
    `FILEVERSION ${versionText}`,
    `PRODUCTVERSION ${versionText}`,
    'FILEFLAGSMASK 0x3fL',
    'FILEFLAGS 0x0L',
    'FILEOS 0x40004L',
    'FILETYPE 0x1L',
    'FILESUBTYPE 0x0L',
    'BEGIN',
    '  BLOCK "StringFileInfo"',
    '  BEGIN',
    '    BLOCK "040904b0"',
    '    BEGIN',
    `      VALUE "CompanyName", ${quoted(config.msix.publisherDisplayName)}`,
    `      VALUE "FileDescription", ${quoted(config.msix.displayName)}`,
    `      VALUE "FileVersion", ${quoted(config.msix.packageVersion)}`,
    `      VALUE "InternalName", ${quoted(config.msix.binaryName.replace(/\.exe$/i, ''))}`,
    `      VALUE "OriginalFilename", ${quoted(config.msix.binaryName)}`,
    `      VALUE "ProductName", ${quoted(config.msix.displayName)}`,
    `      VALUE "ProductVersion", ${quoted(config.msix.packageVersion)}`,
    '    END',
    '  END',
    '  BLOCK "VarFileInfo"',
    '  BEGIN',
    '    VALUE "Translation", 0x409, 1200',
    '  END',
    'END',
    '',
  ];
  return lines.join('\n');
}

/* -------------------------------------------------------------------------- build */

function buildOfflinePage(options, workDir) {
  const target = join(workDir, 'www', 'index.html');
  mkdirSync(dirname(target), { recursive: true });
  run(
    process.execPath,
    [join(REPO_ROOT, 'scripts', 'build-offline-html.mjs'), '--out', target, '--quiet'],
    'build-offline-html',
  );
  const html = readFileSync(target);
  if (!html.subarray(0, 200).toString('utf8').toLowerCase().includes('<!doctype html')) {
    fail('offline page does not start with a doctype');
  }
  for (const remote of ['cdnjs.cloudflare.com', 'fonts.googleapis.com', 'cdn.jsdelivr.net', 'unpkg.com']) {
    if (html.includes(remote)) fail(`offline page still references ${remote}`);
  }
  return { path: target, bytes: html.length };
}

function compileHost({ config, workDir, webview2 }) {
  const zig = findZig();
  const rcPath = join(workDir, 'store.rc');
  // The rc compiler resolves relative paths against the process cwd, and absolute POSIX
  // paths confuse it when the target is Windows, so keep everything repo-relative.
  writeFileSync(
    rcPath,
    buildResourceScript({
      config,
      iconPath: config.msix.iconFile,
      manifestPath: config.msix.manifestFile,
    }),
  );
  const exePath = join(workDir, config.msix.binaryName);
  const args = [
    ...zig.prefix,
    'c++',
    '-O2',
    '-std=c++17',
    '-Wall',
    '-Wextra',
    '-Wno-unknown-pragmas', // the SDK header is full of MSVC-only #pragma warning lines
    '-target',
    config.windowsTarget,
    '-municode', // wWinMain, wide argv
    '-Wl,--subsystem,windows', // GUI: no console window behind the app
    `-I${join(webview2.dir, 'include')}`,
    '-Iwindows/webview2',
    `-DAPP_VERSION="${config.version}"`,
    `-DAPP_NAME="${config.msix.displayName}"`,
    `-o${exePath}`,
    config.msix.sourceFile,
    rcPath,
    ...config.msix.windowsLibraries.map((lib) => `-l${lib}`),
  ];
  run(zig.command, args, 'zig c++ (webview2 host)');
  if (!existsSync(exePath)) fail(`compiler produced no ${exePath}`);
  // zig keeps debug info beside the binary; the package must not carry it.
  const leftovers = readdirSync(workDir).filter((name) => name.endsWith('.pdb') || name.endsWith('.lib'));
  for (const name of leftovers) rmSync(join(workDir, name), { force: true });
  return exePath;
}

function auditExecutable(path, config) {
  const buf = readFileSync(path);
  const pe = parsePe(buf, config.msix.binaryName);
  const checks = [];
  const check = (name, ok, detail) => {
    checks.push({ name, ok: Boolean(ok), detail });
    if (!ok) fail(`${config.msix.binaryName}: ${name} (${detail})`);
  };
  check('PE32+ x86-64', pe.machine === 0x8664, `machine 0x${pe.machine.toString(16)}`);
  check('GUI subsystem', pe.subsystem === 2, `subsystem ${pe.subsystem}`);
  check(
    'size within limits',
    buf.length >= config.minimumExecutableBytes && buf.length <= config.maximumExecutableBytes,
    `${buf.length} bytes`,
  );
  const allowed = new Set(config.msix.allowedImports.map((name) => name.toLowerCase()));
  const unexpected = pe.imports.filter(
    (dll) => !allowed.has(dll.toLowerCase()) && !/^api-ms-win-/i.test(dll),
  );
  check('only expected DLL imports', unexpected.length === 0, unexpected.join(', ') || 'none');
  const text = buf.toString('latin1');
  const wide = buf.toString('utf16le');
  for (const remote of ['cdnjs.cloudflare.com', 'fonts.googleapis.com', 'cdn.jsdelivr.net', 'unpkg.com', 'http://localhost']) {
    check(`no ${remote}`, !text.includes(remote) && !wide.includes(remote), 'found in binary');
  }
  check(
    `serves ${config.msix.virtualHost}`,
    wide.includes(config.msix.virtualHost) || text.includes(config.msix.virtualHost),
    'virtual host name missing',
  );
  check(
    'loads WebView2Loader.dll',
    wide.includes('WebView2Loader.dll') || text.includes('WebView2Loader.dll'),
    'loader name missing',
  );
  return {
    bytes: buf.length,
    sha256: sha256(buf),
    machine: `0x${pe.machine.toString(16)}`,
    subsystem: pe.subsystem,
    imports: pe.imports,
    checks,
  };
}

function collectPayload({ config, workDir, exePath, webview2 }) {
  const payload = [];
  const add = (name, source) => {
    if (!existsSync(source)) fail(`missing payload file for ${name}: ${source}`);
    payload.push({ name, data: readFileSync(source), source });
  };
  add(config.msix.binaryName, exePath);
  add('WebView2Loader.dll', join(webview2.dir, 'x64', 'WebView2Loader.dll'));
  add('www/index.html', join(workDir, 'www', 'index.html'));

  const assetsDir = resolve(REPO_ROOT, config.msix.assetsDir);
  if (!existsSync(assetsDir)) fail(`assets directory not found: ${assetsDir}`);
  for (const name of readdirSync(assetsDir).sort()) {
    const full = join(assetsDir, name);
    if (!statSync(full).isFile()) continue;
    if (!/\.png$/i.test(name)) fail(`unexpected file in ${config.msix.assetsDir}: ${name}`);
    add(`Assets/${name}`, full);
  }
  // Partner Center resolves manifest logo references literally: a hand-packed MSIX has no
  // resources.pri, so `Assets\Square44x44Logo.png` must exist as a file, not merely as the
  // scale-200 sibling. The base-size files are what validation reads; the scale-200 ones are
  // what high-DPI Start menu tiles can use.
  for (const required of [
    'Square44x44Logo.png',
    'Square150x150Logo.png',
    'Wide310x150Logo.png',
    'StoreLogo.png',
    'SplashScreen.png',
    'Square44x44Logo.scale-200.png',
    'Square150x150Logo.scale-200.png',
    'Wide310x150Logo.scale-200.png',
    'StoreLogo.scale-200.png',
    'SplashScreen.scale-200.png',
  ]) {
    if (!payload.some((file) => file.name === `Assets/${required}`)) {
      fail(`${config.msix.assetsDir} is missing ${required}`);
    }
  }
  return payload;
}

/** Verify the PNG dimensions the Store validates against the declared scale. */
function auditAssets(payload) {
  // Unqualified names mean scale-100 to the validator, so their pixels must be the base size;
  // the `.scale-200` files must be exactly twice it.
  const expected = {
    'Assets/Square44x44Logo.png': [44, 44],
    'Assets/Square150x150Logo.png': [150, 150],
    'Assets/Wide310x150Logo.png': [310, 150],
    'Assets/StoreLogo.png': [50, 50],
    'Assets/SplashScreen.png': [620, 300],
    'Assets/Square44x44Logo.scale-200.png': [88, 88],
    'Assets/Square150x150Logo.scale-200.png': [300, 300],
    'Assets/Wide310x150Logo.scale-200.png': [620, 300],
    'Assets/StoreLogo.scale-200.png': [100, 100],
    'Assets/SplashScreen.scale-200.png': [1240, 600],
  };
  const results = [];
  for (const [name, [width, height]] of Object.entries(expected)) {
    const file = payload.find((entry) => entry.name === name);
    if (!file) fail(`${name} missing from payload`);
    const signature = file.data.subarray(0, 8).toString('hex');
    if (signature !== '89504e470d0a1a0a') fail(`${name} is not a PNG`);
    const actual = [file.data.readUInt32BE(16), file.data.readUInt32BE(20)];
    if (actual[0] !== width || actual[1] !== height) {
      fail(`${name} is ${actual.join('x')}, the Store expects ${width}x${height} at scale-200`);
    }
    results.push({ name, width: actual[0], height: actual[1], bytes: file.data.length });
  }
  return results;
}

/* ---------------------------------------------------------------- MSIX validation */

function verifyPackage({ msixPath, config, payload, manifestXml, exeAudit }) {
  const archive = readFileSync(msixPath);
  const entries = zipEntries(archive);
  const names = [...entries.keys()];
  const problems = [];
  const expect = (condition, message) => {
    if (!condition) problems.push(message);
  };

  const expectedOrder = [
    ...payload.map((file) => file.name),
    'AppxManifest.xml',
    'AppxBlockMap.xml',
    '[Content_Types].xml',
  ];
  expect(
    JSON.stringify(names) === JSON.stringify(expectedOrder),
    `entry order is ${names.join(', ')}`,
  );

  const blockMapXml = zipRead(archive, entries.get('AppxBlockMap.xml')).toString('utf8');
  const contentTypesXml = zipRead(archive, entries.get('[Content_Types].xml')).toString('utf8');
  const storedManifest = zipRead(archive, entries.get('AppxManifest.xml')).toString('utf8');
  expect(storedManifest === manifestXml, 'AppxManifest.xml inside the package differs');

  const recorded = new Map();
  for (const match of blockMapXml.matchAll(/<File Name="([^"]+)" Size="(\d+)" LfhSize="(\d+)">([\s\S]*?)<\/File>/g)) {
    const [, name, size, lfh, body] = match;
    const blocks = [...body.matchAll(/<Block Hash="([^"]+)"(?: Size="(\d+)")? \/>/g)].map((b) => ({
      hash: b[1],
      size: b[2] === undefined ? null : Number(b[2]),
    }));
    recorded.set(name.replace(/\\/g, '/'), { size: Number(size), lfh: Number(lfh), blocks });
  }

  const shouldBeMapped = new Set([...payload.map((file) => file.name), 'AppxManifest.xml']);
  expect(
    JSON.stringify([...recorded.keys()].sort()) === JSON.stringify([...shouldBeMapped].sort()),
    'block map file list does not match the payload plus AppxManifest.xml',
  );
  expect(!recorded.has('AppxBlockMap.xml'), 'AppxBlockMap.xml must not list itself');
  expect(!recorded.has('[Content_Types].xml'), '[Content_Types].xml must not be in the block map');

  for (const [name, info] of recorded) {
    const entry = entries.get(name);
    expect(entry !== undefined, `block map lists ${name}, which is not in the archive`);
    if (!entry) continue;
    const data = zipRead(archive, entry);
    expect(data.length === info.size, `${name}: block map Size ${info.size} != ${data.length}`);
    expect(entry.crc === crc32(data), `${name}: CRC mismatch`);
    expect(
      localHeaderSize(archive, entry) === info.lfh,
      `${name}: LfhSize ${info.lfh} != actual ${localHeaderSize(archive, entry)}`,
    );
    const fresh = deflateInBlocks(data);
    expect(
      fresh.blocks.length === info.blocks.length,
      `${name}: ${info.blocks.length} recorded blocks, ${fresh.blocks.length} recomputed`,
    );
    fresh.blocks.forEach((block, index) => {
      const recordedBlock = info.blocks[index];
      if (!recordedBlock) return;
      expect(
        recordedBlock.hash === block.hash,
        `${name}: block ${index} hash differs from the recomputed SHA-256`,
      );
      if (recordedBlock.size !== null) {
        expect(
          recordedBlock.size === block.size,
          `${name}: block ${index} Size ${recordedBlock.size} != recomputed ${block.size}`,
        );
      }
    });
  }

  // Content types must cover every part.
  const defaults = new Set(
    [...contentTypesXml.matchAll(/<Default Extension="([^"]+)"/g)].map((m) => m[1].toLowerCase()),
  );
  const overrides = new Set(
    [...contentTypesXml.matchAll(/<Override PartName="([^"]+)"/g)].map((m) => m[1]),
  );
  for (const name of names) {
    if (name === '[Content_Types].xml') continue;
    const extension = basename(name).split('.').pop().toLowerCase();
    expect(
      overrides.has(`/${name}`) || defaults.has(extension),
      `no content type for ${name} (extension "${extension}")`,
    );
  }

  // Manifest sanity, independent of what we generated.
  const identity = /<Identity\s+([^>]+)\/>/.exec(storedManifest);
  expect(identity !== null, 'manifest has no <Identity>');
  if (identity) {
    const attributes = Object.fromEntries(
      [...identity[1].matchAll(/(\w+)="([^"]*)"/g)].map((m) => [m[1], m[2]]),
    );
    expect(
      /^[A-Za-z0-9_.-]{3,50}$/.test(attributes.Name ?? ''),
      `Identity Name "${attributes.Name}" is not a valid package name`,
    );
    expect(
      /^CN=.+/.test(attributes.Publisher ?? ''),
      `Identity Publisher "${attributes.Publisher}" must start with CN=`,
    );
    const version = (attributes.Version ?? '').split('.');
    expect(
      version.length === 4 && version.every((part) => /^\d+$/.test(part)) && Number(version[3]) === 0,
      `Identity Version "${attributes.Version}" must be a.b.c.0`,
    );
    expect(attributes.ProcessorArchitecture === 'x64', 'ProcessorArchitecture must be x64');
    expect(attributes.Name === config.msix.identityName, 'Identity Name differs from app.json');
  }
  expect(
    storedManifest.includes('EntryPoint="Windows.FullTrustApplication"'),
    'Win32 apps need EntryPoint="Windows.FullTrustApplication"',
  );
  expect(
    storedManifest.includes('<rescap:Capability Name="runFullTrust" />'),
    'the runFullTrust capability is required for a desktop app',
  );
  expect(
    storedManifest.includes(`Executable="${config.msix.binaryName}"`),
    'manifest Executable does not match the packaged binary',
  );
  for (const reference of storedManifest.matchAll(/(?:Logo|Square150x150Logo|Square44x44Logo|Wide310x150Logo|Image)="([^"]+)"/g)) {
    const part = reference[1].replace(/\\/g, '/');
    const stem = part.replace(/\.png$/i, '');
    const present = names.some(
      (name) => name === part || name.startsWith(`${stem}.scale-`) || name.startsWith(`${stem}.targetsize-`),
    );
    expect(present, `manifest references ${reference[1]}, which is not in the package`);
  }

  const exeInside = zipRead(archive, entries.get(config.msix.binaryName));
  expect(sha256(exeInside) === exeAudit.sha256, 'packaged exe differs from the compiled exe');

  const pageInside = zipRead(archive, entries.get('www/index.html')).toString('utf8');
  expect(pageInside.includes('<!DOCTYPE html>'), 'packaged page lost its doctype');
  for (const remote of ['cdnjs.cloudflare.com', 'fonts.googleapis.com', 'cdn.jsdelivr.net']) {
    expect(!pageInside.includes(remote), `packaged page references ${remote}`);
  }
  expect(!names.some((name) => name.endsWith('.pdb')), 'package contains debug symbols');

  return { entries: names, problems };
}

/* -------------------------------------------------------------------------- main */

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(
      [
        'Usage: node scripts/build-store.mjs [options]',
        '',
        '  --out <dir>            output directory (default: windows-release)',
        '  --publisher "CN=..."   override the package publisher from windows/app.json',
        '  --publisher-display-name <name>  must equal your Partner Center display name',
        '  --identity-name <name> override the package identity name',
        '  --version <a.b.c.0>    override the package version',
        '  --skip-exe             reuse an already compiled PhysicsDraw.exe in the work dir',
        '  --force-webview2       re-download the WebView2 SDK even if it is cached',
        '  --keep-temp            keep windows/build/store after the build',
        '  --quiet                only print the final summary',
        '',
        'Environment: ZIG, MSIX_PUBLISHER, MSIX_IDENTITY_NAME, MSIX_VERSION.',
      ].join('\n'),
    );
    return;
  }

  const startedAt = Date.now();
  const config = JSON.parse(readFileSync(join(REPO_ROOT, 'windows', 'app.json'), 'utf8'));
  if (!config.msix) fail('windows/app.json has no "msix" section');
  if (options.publisher) config.msix.publisher = options.publisher;
  if (options.publisherDisplayName) config.msix.publisherDisplayName = options.publisherDisplayName;
  if (options.identityName) config.msix.identityName = options.identityName;
  if (options.version) config.msix.packageVersion = options.version;

  const outDir = options.out;
  const workDir = join(REPO_ROOT, 'windows', 'build', 'store');
  rmSync(workDir, { recursive: true, force: true });
  mkdirSync(workDir, { recursive: true });
  mkdirSync(outDir, { recursive: true });
  const payloadDir = join(outDir, config.msix.payloadDir);
  rmSync(payloadDir, { recursive: true, force: true });

  say(options, `Building ${config.msix.packageFile} for ${config.msix.identityName}`);

  const placeholderPublisher = /REPLACE/i.test(config.msix.publisher);
  if (placeholderPublisher) {
    say(
      options,
      `  ! publisher is still "${config.msix.publisher}". Partner Center rejects a package whose\n` +
        '    Publisher does not match your account; pass --publisher "CN=<your Store publisher ID>"\n' +
        '    or set MSIX_PUBLISHER. The package is still valid for local signing tests.',
    );
  }

  say(options, '  [1/6] offline page');
  const page = buildOfflinePage(options, workDir);

  say(options, '  [2/6] WebView2 SDK');
  const webview2 = await ensureWebView2({
    dir: join(REPO_ROOT, 'windows', 'build', 'webview2'),
    quiet: options.quiet,
    force: options.forceWebview2,
  });
  webview2.dir = join(REPO_ROOT, 'windows', 'build', 'webview2');

  say(options, '  [3/6] PhysicsDraw.exe');
  const exePath = compileHost({ config, workDir, webview2 });
  if (!existsSync(exePath)) fail(`compiler produced no executable at ${exePath}`);
  const exeAudit = auditExecutable(exePath, config);

  say(options, '  [4/6] payload');
  const payload = collectPayload({ config, workDir, exePath, webview2 });
  const assets = auditAssets(payload);
  for (const file of payload) {
    const target = join(payloadDir, file.name);
    mkdirSync(dirname(target), { recursive: true });
    copyFileSync(file.source, target);
  }

  say(options, '  [5/6] manifest, content types, block map');
  const manifestXml = buildManifest(config);
  const contentTypesXml = buildContentTypes(payload);

  // The zip needs the block map, and the block map needs the zip's Local File Header
  // sizes, which are 30 + name length for every entry this writer produces.
  const entry = (name, data) => ({
    name,
    data,
    method: 8,
    lfhSize: 30 + Buffer.byteLength(name, 'utf8'),
    precomputed: deflateInBlocks(data),
  });
  const zipFiles = payload.map((file) => entry(file.name, file.data));
  const manifestEntry = entry('AppxManifest.xml', Buffer.from(manifestXml, 'utf8'));
  zipFiles.push(manifestEntry);
  const blockMapXml = buildBlockMap(zipFiles);
  zipFiles.push(
    {
      name: 'AppxBlockMap.xml',
      data: Buffer.from(blockMapXml, 'utf8'),
      method: 8,
    },
    {
      name: '[Content_Types].xml',
      data: Buffer.from(contentTypesXml, 'utf8'),
      method: 8,
    },
  );

  say(options, '  [6/6] packing');
  const archive = buildZip(zipFiles);
  const msixPath = join(outDir, config.msix.packageFile);
  writeFileSync(msixPath, archive);
  writeFileSync(join(workDir, 'AppxManifest.xml'), manifestXml);
  writeFileSync(join(workDir, 'AppxBlockMap.xml'), blockMapXml);
  writeFileSync(join(workDir, '[Content_Types].xml'), contentTypesXml);

  const verification = verifyPackage({
    msixPath,
    config,
    payload,
    manifestXml,
    exeAudit,
  });
  if (verification.problems.length > 0) {
    for (const problem of verification.problems) console.error(`  ! ${problem}`);
    fail(`${verification.problems.length} package verification problem(s)`);
  }

  const report = {
    generatedAt: new Date().toISOString(),
    package: {
      file: config.msix.packageFile,
      path: msixPath,
      bytes: archive.length,
      sha256: sha256(archive),
      signed: false,
      identityName: config.msix.identityName,
      publisher: config.msix.publisher,
      publisherIsPlaceholder: placeholderPublisher,
      version: config.msix.packageVersion,
      displayName: config.msix.displayName,
      minVersion: config.msix.minVersion,
      maxVersionTested: config.msix.maxVersionTested,
      entries: verification.entries,
    },
    executable: exeAudit,
    page,
    assets,
    webview2: {
      source: webview2.source,
      package: webview2.package,
      version: webview2.version,
      header: webview2.header,
      loader: webview2.loader,
      fallbacksTried: webview2.fallbacksTried ?? [],
    },
    payloadDir,
    verification: { problems: verification.problems, ok: true },
    durationMs: Date.now() - startedAt,
  };
  writeFileSync(join(outDir, 'msix-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync(
    join(outDir, `${config.msix.packageFile}.sha256`),
    `${report.package.sha256}  ${config.msix.packageFile}\n`,
  );

  if (!options.keepTemp) rmSync(workDir, { recursive: true, force: true });

  say(options, '');
  say(options, `  ${config.msix.packageFile}  ${archive.length.toLocaleString('en-US')} bytes`);
  say(options, `  sha256  ${report.package.sha256}`);
  say(options, `  payload ${payloadDir}`);
  say(options, `  entries ${verification.entries.length}, exe ${exeAudit.bytes.toLocaleString('en-US')} B, page ${page.bytes.toLocaleString('en-US')} B`);
  say(options, `  WebView2 SDK ${webview2.package}@${webview2.version} (${webview2.source})`);
  say(options, '  unsigned on purpose: Partner Center re-signs Store packages');
  console.log(JSON.stringify({ ok: true, msix: msixPath, sha256: report.package.sha256 }));
}

main().catch((error) => {
  console.error(`build-store: ${error.message ?? error}`);
  if (error.stack && process.env.BUILD_DEBUG) console.error(error.stack);
  process.exitCode = 1;
});
