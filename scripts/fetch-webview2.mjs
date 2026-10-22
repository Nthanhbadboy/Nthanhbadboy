#!/usr/bin/env node
/**
 * Fetch the two pieces of the Microsoft WebView2 SDK that the windowed host needs:
 *
 *   - WebView2.h / WebView2EnvironmentOptions.h   (C++ interfaces)
 *   - x64/WebView2Loader.dll                      (shipped next to PhysicsDraw.exe)
 *
 * Nothing is vendored in git: the SDK header alone is ~3 MB of generated COM code, so it
 * is downloaded at build time into the gitignored windows/build/webview2/ directory.
 *
 * Sources, in order:
 *   1. the official NuGet package `microsoft.web.webview2`  (what CI runners use)
 *   2. the npm package `webview-node@<pinned>`              (offline/mirror fallback,
 *                                                            tarball hash verified)
 * Both carry Microsoft's redistributable SDK files; the fallback exists so a build never
 * dies because one registry is unreachable. Every artifact is checked for the exact API
 * surface webview2-host.cpp uses, so a too-old SDK fails loudly instead of at link time.
 */

import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';

import { sha256, zipEntries, zipRead } from './lib/zip.mjs';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(SCRIPT_DIR, '..');

const NUGET_ID = 'microsoft.web.webview2';
const NUGET_INDEX = `https://api.nuget.org/v3-flatcontainer/${NUGET_ID}/index.json`;
/** Used when present in the NuGet index; otherwise the newest stable version wins. */
const PREFERRED_NUGET_VERSION = '1.0.2903.40';

const NPM_REGISTRY = 'https://registry.npmjs.org';
const NPM_PACKAGE = 'webview-node';
const NPM_VERSION = '0.1.41';
/** sha512 of the registry tarball, as published in the packument (subresource-integrity form). */
const NPM_INTEGRITY =
  'sha512-CuJwYkvN1ss0jWzXBARCxiPrAXPDaNl7X3hVvhsuBJowGWP6WjGqFT3jNjjCMYOBvF+uTxpm/eEuRf1Eu1HabQ==';
/** sha256 of the individual SDK files inside that tarball (second layer of pinning). */
const NPM_FILE_SHA256 = {
  'package/bin/source/include/WebView2.h':
    'dff1e3181ec7ec203a34ef6efa966590e0ef0ba1a5c3fe3b69da6508c2f8a02e',
  'package/bin/source/lib/x64/WebView2Loader.dll':
    'a9a09232c25805323d4cfb3fc8f545a190a9c8a99c93262ea99d0b88df99ec90',
};

/**
 * API surface webview2-host.cpp depends on. A WebView2.h that lacks any of these is too
 * old to compile the host (this is exactly how the first vendored copy failed).
 */
export const REQUIRED_HEADER_SYMBOLS = [
  'CreateCoreWebView2EnvironmentWithOptions',
  'interface ICoreWebView2Environment',
  'interface ICoreWebView2Controller',
  'interface ICoreWebView2Settings',
  'interface ICoreWebView2_3',
  'interface ICoreWebView2Controller2',
  'interface ICoreWebView2NavigationCompletedEventHandler',
  'interface ICoreWebView2CreateCoreWebView2ControllerCompletedHandler',
  'interface ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler',
  'SetVirtualHostNameToFolderMapping',
  'COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW',
  'put_DefaultBackgroundColor',
];

/** Interfaces whose GUIDs are emitted into the generated webview2-iids.h header. */
export const REQUIRED_IIDS = [
  'ICoreWebView2',
  'ICoreWebView2_3',
  'ICoreWebView2Controller',
  'ICoreWebView2Controller2',
  'ICoreWebView2Settings',
  'ICoreWebView2NavigationCompletedEventHandler',
  'ICoreWebView2CreateCoreWebView2ControllerCompletedHandler',
  'ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler',
];

const log = (quiet, ...args) => {
  if (!quiet) console.log(...args);
};

function sha512Base64(buf) {
  return `sha512-${createHash('sha512').update(buf).digest('base64')}`;
}

async function download(url, { timeoutMs = 120_000 } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal, redirect: 'follow' });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return Buffer.from(await res.arrayBuffer());
  } finally {
    clearTimeout(timer);
  }
}

/* ------------------------------------------------------------- artifact checks */

function checkHeader(text, label) {
  const missing = REQUIRED_HEADER_SYMBOLS.filter((symbol) => !text.includes(symbol));
  if (missing.length > 0) {
    throw new Error(`${label}: WebView2.h is missing ${missing.join(', ')} (SDK too old)`);
  }
  const newest = [...text.matchAll(/interface ICoreWebView2_(\d+)\b/g)]
    .map((m) => Number(m[1]))
    .sort((a, b) => b - a)[0];
  return { bytes: Buffer.byteLength(text), newestCoreWebView2: newest ?? 0 };
}

/** Parse the PE export directory and confirm the loader exports the entrypoint we dlopen. */
function checkLoaderDll(buf) {
  if (buf.readUInt16LE(0) !== 0x5a4d) throw new Error('WebView2Loader.dll is not a PE image');
  const peOffset = buf.readUInt32LE(0x3c);
  if (buf.toString('ascii', peOffset, peOffset + 4) !== 'PE\0\0') {
    throw new Error('WebView2Loader.dll has no PE signature');
  }
  const machine = buf.readUInt16LE(peOffset + 4);
  if (machine !== 0x8664) {
    throw new Error(`WebView2Loader.dll machine is 0x${machine.toString(16)}, expected 0x8664 (x64)`);
  }
  const optionalHeader = peOffset + 24;
  const magic = buf.readUInt16LE(optionalHeader);
  if (magic !== 0x20b) throw new Error('WebView2Loader.dll is not PE32+');
  const directoryOffset = optionalHeader + 112; // PE32+ data directories start here
  const exportRva = buf.readUInt32LE(directoryOffset);
  const exportSize = buf.readUInt32LE(directoryOffset + 4);
  if (exportRva === 0) throw new Error('WebView2Loader.dll has no export directory');

  const sections = [];
  const sectionCount = buf.readUInt16LE(peOffset + 6);
  const sectionTable = optionalHeader + buf.readUInt16LE(peOffset + 20);
  for (let i = 0; i < sectionCount; i += 1) {
    const at = sectionTable + i * 40;
    sections.push({
      virtualSize: buf.readUInt32LE(at + 8),
      virtualAddress: buf.readUInt32LE(at + 12),
      rawSize: buf.readUInt32LE(at + 16),
      rawPointer: buf.readUInt32LE(at + 20),
    });
  }
  const rvaToOffset = (rva) => {
    const section = sections.find(
      (s) => rva >= s.virtualAddress && rva < s.virtualAddress + Math.max(s.virtualSize, s.rawSize),
    );
    if (!section) throw new Error(`no section contains RVA 0x${rva.toString(16)}`);
    return section.rawPointer + (rva - section.virtualAddress);
  };

  const dirOffset = rvaToOffset(exportRva);
  if (dirOffset + 40 > buf.length || dirOffset + exportSize > buf.length + 1) {
    throw new Error('export directory out of range');
  }
  const nameCount = buf.readUInt32LE(dirOffset + 24);
  const namesRva = buf.readUInt32LE(dirOffset + 32);
  const namesOffset = rvaToOffset(namesRva);
  const names = [];
  for (let i = 0; i < nameCount; i += 1) {
    const nameRva = buf.readUInt32LE(namesOffset + i * 4);
    const at = rvaToOffset(nameRva);
    let end = at;
    while (end < buf.length && buf[end] !== 0) end += 1;
    names.push(buf.toString('ascii', at, end));
  }
  for (const required of [
    'CreateCoreWebView2EnvironmentWithOptions',
    'CreateCoreWebView2Environment',
  ]) {
    if (!names.includes(required)) {
      throw new Error(`WebView2Loader.dll does not export ${required}`);
    }
  }
  return { bytes: buf.length, sha256: sha256(buf), exports: names.length };
}

/* ----------------------------------------------------------- IID header output */

const GUID_RE = /MIDL_INTERFACE\("([0-9a-fA-F-]{36})"\)\s*([A-Za-z_][A-Za-z0-9_]*)/g;

/**
 * mingw-w64 (and therefore `zig c++ -target x86_64-windows-gnu`) has no __CRT_UUID_DECL
 * entries for the WebView2 interfaces, so __uuidof()/IID_PPV_ARGS cannot resolve them.
 * Rather than hand-copying GUIDs, derive them from the SDK header we just fetched.
 */
export function generateIidHeader(headerText, required = REQUIRED_IIDS) {
  const uuids = new Map();
  for (const match of headerText.matchAll(GUID_RE)) {
    uuids.set(match[2], match[1]);
  }
  const missing = required.filter((name) => !uuids.has(name));
  if (missing.length > 0) {
    throw new Error(`WebView2.h does not declare a MIDL_INTERFACE GUID for: ${missing.join(', ')}`);
  }
  const lines = [
    '/* Generated by scripts/fetch-webview2.mjs from the official WebView2 SDK header. */',
    '/* Do not edit by hand and do not commit: it is rebuilt on every Windows build. */',
    '#ifndef PHYSICS_DRAW_WEBVIEW2_IIDS_H',
    '#define PHYSICS_DRAW_WEBVIEW2_IIDS_H',
    '',
    '#include <guiddef.h>',
    '',
    '#ifdef __MINGW32__',
    '',
    '/* IUnknown is declared by the SDK headers but its IID lives in libuuid; spell it out',
    '   so the host links against nothing but the Win32 import libraries it already uses. */',
    'inline const GUID WEBVIEW2_IID_IUnknown =',
    '    { 0x00000000, 0x0000, 0x0000, { 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };',
    '',
  ];
  for (const name of required) {
    // A GUID string is d1-d2-d3-g4-g5; Data4 is the last two groups joined (8 bytes).
    const [d1, d2, d3, g4, g5] = uuids.get(name).split('-');
    if (!g4 || !g5 || g4.length !== 4 || g5.length !== 12) {
      throw new Error(`${name}: malformed GUID ${uuids.get(name)}`);
    }
    const bytes = `${g4}${g5}`.match(/../g).map((b) => `0x${b.toLowerCase()}`).join(', ');
    lines.push(
      `inline const GUID WEBVIEW2_IID_${name} =`,
      `    { 0x${d1.toLowerCase()}, 0x${d2.toLowerCase()}, 0x${d3.toLowerCase()}, { ${bytes} } };`,
      '',
    );
  }
  lines.push(
    '#else /* MSVC: the Windows SDK provides these through uuid.lib. */',
    '',
    ...required.flatMap((name) => [`#define WEBVIEW2_IID_${name} __uuidof(${name})`]),
    '#define WEBVIEW2_IID_IUnknown __uuidof(IUnknown)',
    '',
    '#endif',
    '#endif',
    '',
  );
  return lines.join('\n');
}

/* ------------------------------------------------------------------- sources */

async function fromNuGet(quiet) {
  const index = JSON.parse((await download(NUGET_INDEX)).toString('utf8'));
  const versions = (index.versions ?? []).filter((v) => !v.includes('-'));
  if (versions.length === 0) throw new Error('NuGet index lists no stable versions');
  const version = versions.includes(PREFERRED_NUGET_VERSION)
    ? PREFERRED_NUGET_VERSION
    : versions[versions.length - 1];
  log(quiet, `  nuget: ${NUGET_ID} ${version}`);
  const url = `https://api.nuget.org/v3-flatcontainer/${NUGET_ID}/${version}/${NUGET_ID}.${version}.nupkg`;
  const nupkg = await download(url);
  const entries = zipEntries(nupkg);
  const pick = (suffix) => {
    const match = [...entries.keys()].find((name) => name.toLowerCase().endsWith(suffix));
    if (!match) throw new Error(`${NUGET_ID} ${version}: no entry ending in ${suffix}`);
    return { name: match, data: zipRead(nupkg, entries.get(match)) };
  };
  const header = pick('build/native/include/webview2.h');
  const options = pick('build/native/include/webview2environmentoptions.h');
  const loader = pick('build/native/x64/webview2loader.dll');
  return {
    source: 'nuget',
    package: NUGET_ID,
    version,
    packageSha256: sha256(nupkg),
    files: {
      'WebView2.h': header.data,
      'WebView2EnvironmentOptions.h': options.data,
      'WebView2Loader.dll': loader.data,
    },
  };
}

async function fromNpm(quiet) {
  const packument = JSON.parse(
    (await download(`${NPM_REGISTRY}/${NPM_PACKAGE}`)).toString('utf8'),
  );
  const meta = packument.versions?.[NPM_VERSION];
  if (!meta) throw new Error(`npm packument has no ${NPM_PACKAGE}@${NPM_VERSION}`);
  log(quiet, `  npm: ${NPM_PACKAGE}@${NPM_VERSION}`);
  const tarball = await download(meta.dist.tarball);
  const integrity = sha512Base64(tarball);
  if (integrity !== NPM_INTEGRITY) {
    throw new Error(`npm tarball integrity mismatch: got ${integrity}`);
  }
  if (meta.dist.integrity && meta.dist.integrity !== NPM_INTEGRITY) {
    throw new Error(`pinned integrity no longer matches the registry (${meta.dist.integrity})`);
  }
  // A .tgz is a gzip'd ustar archive; the three files we need are stored back to back, so
  // walk the 512-byte headers instead of shelling out to tar.
  const raw = gunzipSync(tarball);
  const files = new Map();
  let offset = 0;
  while (offset + 512 <= raw.length) {
    const header = raw.subarray(offset, offset + 512);
    const name = header.toString('utf8', 0, 100).replace(/\0.*$/, '');
    if (!name) break;
    const size = parseInt(header.toString('utf8', 124, 136).replace(/\0.*$/, '').trim() || '0', 8);
    const type = String.fromCharCode(header[156]);
    const ext = header.toString('utf8', 345, 500).replace(/\0.*$/, '');
    const fullName = ext ? `${ext.replace(/\0.*$/, '')}/${name}` : name;
    if (type === '0' || type === '\0') {
      files.set(fullName, Buffer.from(raw.subarray(offset + 512, offset + 512 + size)));
    }
    offset += 512 + Math.ceil(size / 512) * 512;
  }
  const pick = (name, expectedSha256) => {
    const data = files.get(name);
    if (!data) throw new Error(`${NPM_PACKAGE}@${NPM_VERSION}: tarball has no ${name}`);
    const digest = sha256(data);
    if (expectedSha256 && digest !== expectedSha256) {
      throw new Error(`${name}: sha256 ${digest} != pinned ${expectedSha256}`);
    }
    return data;
  };
  return {
    source: 'npm',
    package: NPM_PACKAGE,
    version: NPM_VERSION,
    packageSha512: integrity,
    files: {
      'WebView2.h': pick(
        'package/bin/source/include/WebView2.h',
        NPM_FILE_SHA256['package/bin/source/include/WebView2.h'],
      ),
      'WebView2EnvironmentOptions.h': pick(
        'package/bin/source/include/WebView2EnvironmentOptions.h',
        null,
      ),
      'WebView2Loader.dll': pick(
        'package/bin/source/lib/x64/WebView2Loader.dll',
        NPM_FILE_SHA256['package/bin/source/lib/x64/WebView2Loader.dll'],
      ),
    },
  };
}

/* ----------------------------------------------------------------------- API */

/**
 * Make sure `dir` holds include/WebView2.h, include/WebView2EnvironmentOptions.h and
 * x64/WebView2Loader.dll. Returns a description of what was fetched and from where.
 */
export async function ensureWebView2({
  dir = join(REPO_ROOT, 'windows', 'build', 'webview2'),
  source = process.env.WEBVIEW2_SOURCE ?? 'auto',
  quiet = false,
  force = false,
} = {}) {
  const stampPath = join(dir, 'source.json');
  if (!force && existsSync(stampPath)) {
    try {
      const stamp = JSON.parse(readFileSync(stampPath, 'utf8'));
      const wanted = source === 'auto' ? null : source;
      if (
        (!wanted || stamp.source === wanted) &&
        existsSync(join(dir, 'include', 'WebView2.h')) &&
        existsSync(join(dir, 'x64', 'WebView2Loader.dll'))
      ) {
        log(quiet, `  webview2: reusing ${stamp.package}@${stamp.version} (${stamp.source})`);
        return stamp;
      }
    } catch {
      /* fall through and refetch */
    }
  }

  rmSync(dir, { recursive: true, force: true });
  mkdirSync(join(dir, 'include'), { recursive: true });
  mkdirSync(join(dir, 'x64'), { recursive: true });

  const attempts = [];
  const order =
    source === 'nuget' ? [['nuget', fromNuGet]]
    : source === 'npm' ? [['npm', fromNpm]]
    : [['nuget', fromNuGet], ['npm', fromNpm]];

  let fetched = null;
  for (const [name, attempt] of order) {
    try {
      fetched = await attempt(quiet);
      break;
    } catch (error) {
      attempts.push({ source: name, error: String(error.message ?? error) });
      log(quiet, `  webview2: ${name} unavailable (${error.message ?? error})`);
    }
  }
  if (!fetched) {
    throw new Error(
      `could not fetch the WebView2 SDK from any source:\n${attempts
        .map((a) => `  - ${a.source}: ${a.error}`)
        .join('\n')}`,
    );
  }

  const headerText = fetched.files['WebView2.h'].toString('utf8');
  const headerInfo = checkHeader(headerText, `${fetched.source} ${fetched.package}`);
  const loaderInfo = checkLoaderDll(fetched.files['WebView2Loader.dll']);

  writeFileSync(join(dir, 'include', 'WebView2.h'), fetched.files['WebView2.h']);
  writeFileSync(
    join(dir, 'include', 'WebView2EnvironmentOptions.h'),
    fetched.files['WebView2EnvironmentOptions.h'],
  );
  writeFileSync(join(dir, 'x64', 'WebView2Loader.dll'), fetched.files['WebView2Loader.dll']);
  writeFileSync(join(dir, 'include', 'webview2-iids.h'), generateIidHeader(headerText));

  const stamp = {
    source: fetched.source,
    package: fetched.package,
    version: fetched.version,
    packageSha256: fetched.packageSha256 ?? null,
    packageSha512: fetched.packageSha512 ?? null,
    header: { ...headerInfo, sha256: sha256(fetched.files['WebView2.h']) },
    loader: loaderInfo,
    fallbacksTried: attempts,
  };
  writeFileSync(stampPath, `${JSON.stringify(stamp, null, 2)}\n`);
  log(
    quiet,
    `  webview2: ${fetched.package}@${fetched.version} from ${fetched.source} ` +
      `(header ${headerInfo.bytes} B, loader ${loaderInfo.bytes} B)`,
  );
  return stamp;
}

const invokedDirectly = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invokedDirectly) {
  const args = process.argv.slice(2);
  const flag = (name) => {
    const at = args.indexOf(`--${name}`);
    return at >= 0 ? args[at + 1] : null;
  };
  ensureWebView2({
    dir: flag('dir') ? resolve(flag('dir')) : undefined,
    source: flag('source') ?? 'auto',
    force: args.includes('--force'),
    quiet: args.includes('--quiet'),
  })
    .then((stamp) => {
      console.log(JSON.stringify(stamp, null, 2));
    })
    .catch((error) => {
      console.error(`fetch-webview2: ${error.message ?? error}`);
      process.exitCode = 1;
    });
}
