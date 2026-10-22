#!/usr/bin/env node
/**
 * Boots the offline Windows page inside jsdom and asserts that the game really starts.
 *
 *   node scripts/verify-offline-page.mjs [path/to/index.html]
 *
 * jsdom never fetches external resources here, so this doubles as proof that the page is
 * self-contained: if a CDN dependency ever crept back in, Matter.js would be undefined and
 * the run would fail. The canvas and WebAudio APIs are mocked, so the render loop and the
 * simulation run headless.
 *
 * Requires the dev dependency: npm ci
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

let JSDOM;
let VirtualConsole;
try {
  ({ JSDOM, VirtualConsole } = await import('jsdom'));
} catch {
  console.error('verify-offline-page: jsdom is not installed. Run `npm ci` first.');
  process.exit(1);
}

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const target = path.resolve(process.cwd(), process.argv[2] || path.join(repoRoot, 'windows', 'build', 'index.html'));

let html;
try {
  html = readFileSync(target, 'utf8');
} catch {
  console.error(`verify-offline-page: cannot read ${target}`);
  console.error('Build it first: node scripts/build-windows.mjs');
  process.exit(1);
}

const errors = [];
const virtualConsole = new VirtualConsole();
virtualConsole.on('jsdomError', (error) => errors.push(`jsdomError: ${error.message}`));
virtualConsole.on('error', (...args) => errors.push(`console.error: ${args.join(' ')}`));

function makeContext(canvas) {
  const properties = {
    fillStyle: '#000', strokeStyle: '#000', lineWidth: 1, font: '10px sans-serif',
    globalAlpha: 1, textAlign: 'start', textBaseline: 'alphabetic', lineCap: 'butt',
    lineJoin: 'miter', shadowBlur: 0, shadowColor: 'transparent', shadowOffsetX: 0,
    shadowOffsetY: 0, globalCompositeOperation: 'source-over', filter: 'none',
    imageSmoothingEnabled: true, miterLimit: 10, direction: 'ltr'
  };
  const gradient = { addColorStop() {} };
  const members = {
    canvas,
    measureText: () => ({ width: 12, actualBoundingBoxAscent: 8, actualBoundingBoxDescent: 2 }),
    createLinearGradient: () => gradient,
    createRadialGradient: () => gradient,
    createConicGradient: () => gradient,
    createPattern: () => ({ setTransform() {} }),
    getImageData: () => ({ data: new Uint8ClampedArray(4), width: 1, height: 1 }),
    getTransform: () => ({ a: 1, b: 0, c: 0, d: 1, e: 0, f: 0 }),
    getLineDash: () => [],
    isPointInPath: () => false,
    isPointInStroke: () => false
  };
  return new Proxy(properties, {
    get(store, property) {
      if (property in members) return members[property];
      if (property in store) return store[property];
      return () => undefined; // every other 2D context method becomes a no-op
    },
    set(store, property, value) {
      store[property] = value;
      return true;
    }
  });
}

const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  url: 'http://127.0.0.1:4173/',
  virtualConsole,
  beforeParse(window) {
    window.HTMLCanvasElement.prototype.getContext = function getContext() {
      if (!this.__mockContext) this.__mockContext = makeContext(this);
      return this.__mockContext;
    };
    window.addEventListener('error', (event) => errors.push(`window.onerror: ${event.message}`));
  }
});

const { window } = dom;
const text = (selector) => (window.document.querySelector(selector)?.textContent || '').trim();
const results = [];
const check = (label, ok, detail = '') => results.push({ label, ok: Boolean(ok), detail });
const pause = (ms) => new Promise((resolve) => { setTimeout(resolve, ms); });

await pause(400);

check('page booted with no uncaught errors', errors.length === 0, errors.slice(0, 4).join(' | '));
check('Matter.js is inlined and usable', typeof window.Matter === 'object' && typeof window.Matter.Engine?.create === 'function');
check('Font Awesome stylesheet is inlined', Boolean(window.document.querySelector('style[data-offline="fontawesome"]')));
check('vendored fonts are inlined', Boolean(window.document.querySelector('style[data-offline="fonts"]')));
check('no remote <script>/<link> tags survived', !/<(?:script|link)[^>]+(?:src|href)="https?:/i.test(html));
check('game script finished initialising', typeof window.HMSGameCallbacks === 'object');
check('level indicator rendered', text('#level-indicator').length > 0, text('#level-indicator'));
check('level name rendered', text('#level-name').length > 0, text('#level-name'));
check('ink budget rendered', text('#ink-label').length > 0, text('#ink-label'));
check('language selector has every translation', window.document.querySelectorAll('#lang-select option').length >= 5);
check('canvas obtained a drawing context', Boolean(window.document.querySelector('#game-canvas')?.__mockContext));

window.document.querySelector('#btn-levels').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await pause(50);
const levelTiles = window.document.querySelectorAll('#levels-grid > *');
check('level picker lists 100 levels', levelTiles.length === 100, `found ${levelTiles.length}`);

const language = window.document.querySelector('#lang-select');
language.value = 'vi';
language.dispatchEvent(new window.Event('change', { bubbles: true }));
await pause(50);
check('Vietnamese translation applied', text('#level-indicator').length > 0 && errors.length === 0, text('#level-indicator'));

window.document.querySelector('#btn-play').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await pause(300);
check('physics simulation stepped without errors', errors.length === 0, errors.slice(0, 4).join(' | '));

let failed = 0;
console.log(`verify-offline-page: ${path.relative(repoRoot, target)}`);
for (const result of results) {
  if (!result.ok) failed += 1;
  console.log(`  ${result.ok ? 'PASS' : 'FAIL'}  ${result.label}${result.ok ? '' : ` (${result.detail})`}`);
}

try {
  window.close();
} catch {
  /* jsdom may already be tearing down */
}

if (failed) {
  console.error(`verify-offline-page: FAILED (${failed} of ${results.length} checks)`);
  process.exit(1);
}
console.log(`verify-offline-page: PASSED (${results.length} checks)`);
