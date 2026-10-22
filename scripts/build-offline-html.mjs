#!/usr/bin/env node
/**
 * Builds the fully self-contained offline HTML that every Windows package ships.
 *
 * The canonical asset stays `index.html` at the repository root (that is what the browser,
 * GitHub Pages, and the Android WebView use, and it loads Matter.js / Font Awesome / Google
 * Fonts from CDNs). This script replaces exactly those five CDN tags with inlined copies of
 * the files vendored under `vendor/`, so the result runs from `file://`, from the launcher's
 * loopback server, or from an air-gapped machine with no network at all.
 *
 * Usage:
 *   node scripts/build-offline-html.mjs [--out <file>] [--quiet]
 *
 * The build is strict on purpose: if the CDN block or the version pins in `index.html` ever
 * drift away from `vendor/versions.json`, the script fails instead of silently shipping a
 * package that needs the internet.
 */

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function fail(message) {
  console.error(`build-offline-html: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const options = { out: path.join(repoRoot, 'build', 'offline', 'index.html'), quiet: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--out') {
      const value = argv[i + 1];
      if (!value) fail('--out needs a file path');
      options.out = path.resolve(process.cwd(), value);
      i += 1;
    } else if (arg.startsWith('--out=')) {
      options.out = path.resolve(process.cwd(), arg.slice('--out='.length));
    } else if (arg === '--quiet' || arg === '-q') {
      options.quiet = true;
    } else {
      fail(`unknown argument: ${arg}`);
    }
  }
  return options;
}

const options = parseArgs(process.argv.slice(2));

const readVendor = (...segments) => readFileSync(path.join(repoRoot, 'vendor', ...segments));
const versions = JSON.parse(readVendor('versions.json').toString('utf8'));
const fontManifest = JSON.parse(readVendor('fonts', 'manifest.json').toString('utf8'));

const dataUri = (mime, buffer) => `data:${mime};base64,${buffer.toString('base64')}`;
const woff2Uri = (file) => dataUri('font/woff2', readVendor('fonts', file));

/* ---------------------------------------------------------------- fonts --- */

function buildFontCss() {
  const blocks = [];
  for (const family of fontManifest.families) {
    for (const subset of family.subsets) {
      const buffer = readVendor('fonts', subset.file);
      if (!buffer.length) fail(`vendored font is empty: ${subset.file}`);
      blocks.push(
        `/* ${family.family} ${subset.weight} ${path.basename(subset.file, '.woff2')} (vendored, SIL OFL 1.1) */\n`
        + '@font-face{\n'
        + `  font-family:"${family.family}";\n`
        + `  font-style:${family.style};\n`
        + `  font-weight:${family.weight};\n`
        + `  font-display:${family.display};\n`
        + `  src:url(${woff2Uri(subset.file)}) format("woff2");\n`
        + `  unicode-range:${subset.unicodeRange};\n`
        + '}'
      );
    }
  }
  if (!blocks.length) fail('vendor/fonts/manifest.json lists no subsets');
  return blocks.join('\n');
}

/* ------------------------------------------------------------ font awesome --- */

function buildFontAwesomeCss() {
  let css = readVendor('fontawesome', 'all.min.css').toString('utf8');
  const solidFont = dataUri('font/woff2', readVendor('fontawesome', 'fa-solid-900.woff2'));

  const declared = css.match(/@font-face\{[^}]*\}/g) || [];
  if (!declared.length) fail('Font Awesome CSS no longer contains any @font-face rule');

  let kept = 0;
  css = css.replace(/@font-face\{([^}]*)\}/g, (block, body) => {
    // The game only uses `fa-solid` icons, so the single Font Awesome 6 Free / 900 face is
    // the only one worth embedding. Dropping the rest avoids dead brand/regular/v4 requests.
    const isSolidFree = body.includes('"Font Awesome 6 Free"') && body.includes('font-weight:900');
    if (!isSolidFree) return '';
    kept += 1;
    if (!/src:[^;]*$/.test(body)) fail('Font Awesome solid @font-face has an unexpected src layout');
    return `@font-face{${body.replace(/src:[^;]*$/, `src:url(${solidFont}) format("woff2")`)}}`;
  });
  if (kept !== 1) fail(`expected exactly one Font Awesome 6 Free solid @font-face, found ${kept}`);
  if (css.includes('../webfonts/')) fail('Font Awesome CSS still references an external webfont path');
  return css.trim();
}

/* ---------------------------------------------------------------- matter --- */

function buildMatterJs() {
  const source = readVendor('matter-js', 'matter.min.js').toString('utf8');
  if (!source.includes('Matter')) fail('vendored matter.min.js does not look like Matter.js');
  if (/<\/script/i.test(source)) fail('vendored matter.min.js contains </script and cannot be inlined');
  return source.trim();
}

/* --------------------------------------------------------------- rewrite --- */

const html = readFileSync(path.join(repoRoot, 'index.html'), 'utf8');

const CDN_BLOCK = new RegExp(
  [
    '[ \\t]*<link rel="preconnect" href="https://fonts\\.googleapis\\.com">\\r?\\n',
    '[ \\t]*<link rel="preconnect" href="https://fonts\\.gstatic\\.com" crossorigin>\\r?\\n',
    '[ \\t]*<link href="https://fonts\\.googleapis\\.com/css2\\?family=Patrick\\+Hand&family=Short\\+Stack&display=swap" rel="stylesheet">\\r?\\n',
    `[ \\t]*<link rel="stylesheet" href="https://cdnjs\\.cloudflare\\.com/ajax/libs/font-awesome/([^/"]+)/css/all\\.min\\.css">\\r?\\n`,
    `[ \\t]*<script src="https://cdnjs\\.cloudflare\\.com/ajax/libs/matter-js/([^/"]+)/matter\\.min\\.js"></script>`
  ].join('')
);

const match = html.match(CDN_BLOCK);
if (!match) {
  fail('the CDN dependency block in index.html changed; update scripts/build-offline-html.mjs');
}
if (match[1] !== versions.fontAwesome) {
  fail(`index.html pins Font Awesome ${match[1]} but vendor/ ships ${versions.fontAwesome}`);
}
if (match[2] !== versions.matterJs) {
  fail(`index.html pins Matter.js ${match[2]} but vendor/ ships ${versions.matterJs}`);
}

const fontCss = buildFontCss();
const fontAwesomeCss = buildFontAwesomeCss();
const matterJs = buildMatterJs();
for (const [name, css] of [['font', fontCss], ['Font Awesome', fontAwesomeCss]]) {
  if (/<\/style/i.test(css)) fail(`vendored ${name} CSS contains </style and cannot be inlined`);
}

const offlineBlock = [
  '  <!-- Offline build: every third-party asset below is vendored under vendor/ and inlined, so',
  `       this page needs no internet connection. Matter.js ${versions.matterJs} (MIT),`,
  `       Font Awesome Free ${versions.fontAwesome} solid (CC BY 4.0 / SIL OFL 1.1 / MIT),`,
  '       Short Stack + Patrick Hand (SIL OFL 1.1).',
  '       Generated from index.html by scripts/build-offline-html.mjs - do not edit this file. -->',
  '  <style data-offline="fonts">',
  fontCss,
  '  </style>',
  '  <style data-offline="fontawesome">',
  fontAwesomeCss,
  '  </style>',
  `  <script data-offline="matter-js">${matterJs}</script>`
].join('\n');

let output = html.replace(CDN_BLOCK, () => offlineBlock);

// Tab/phone icon for the loopback server and for file:// launches.
const favicon = readFileSync(path.join(repoRoot, 'assets', 'favicon-64.png'));
if (!/<link[^>]+rel="icon"/i.test(output)) {
  const titleLine = output.match(/^[ \t]*<title>[^<]*<\/title>$/m);
  if (!titleLine) fail('could not find the <title> line to attach the offline favicon');
  const iconTag = `  <link rel="icon" type="image/png" href="${dataUri('image/png', favicon)}">`;
  output = output.replace(titleLine[0], `${titleLine[0]}\n${iconTag}`);
}

/* -------------------------------------------------------------- verify --- */

const externalTags = output.match(/<(?:link|script|img|iframe)[^>]+(?:href|src)="https?:[^"]+"/gi) || [];
const blocking = externalTags.filter((tag) => !/rel="(canonical|alternate|license)"/i.test(tag));
if (blocking.length) {
  fail(`offline build still loads remote assets:\n${blocking.join('\n')}`);
}
if (/@import\s+url\(\s*["']?https?:/i.test(output)) fail('offline build still contains a remote @import');
if (/<\/html>/i.test(output) === false) fail('offline build lost its closing </html> tag');

mkdirSync(path.dirname(options.out), { recursive: true });
writeFileSync(options.out, output);

const bytes = Buffer.byteLength(output);
if (!options.quiet) {
  const rows = [
    ['source index.html', `${Buffer.byteLength(html).toLocaleString('en-US')} B`],
    ['matter.min.js', `${Buffer.byteLength(matterJs).toLocaleString('en-US')} B`],
    ['fontawesome all.min.css', `${Buffer.byteLength(fontAwesomeCss).toLocaleString('en-US')} B`],
    ['vendored fonts + favicon', `${Buffer.byteLength(fontCss).toLocaleString('en-US')} B (base64)`],
    ['offline build', `${bytes.toLocaleString('en-US')} B (${(bytes / 1024).toFixed(0)} KiB)`]
  ];
  console.log(`build-offline-html: wrote ${path.relative(repoRoot, options.out)}`);
  for (const [label, value] of rows) console.log(`  ${label.padEnd(26)} ${value}`);
}
