# Vendored offline assets

These files let the offline builds (Windows launcher, portable Windows zip) run with **no
internet connection**. `index.html` at the repository root stays the canonical web/Android
asset and still loads the same libraries from their CDNs.

`scripts/build-offline-html.mjs` inlines everything below into one self-contained HTML file,
and it refuses to run when `index.html` references a CDN version that does not match
`versions.json`.

| Path | Upstream | Version | License |
| --- | --- | --- | --- |
| `matter-js/matter.min.js` | `matter-js` on npm | 0.19.0 | MIT (`matter-js/LICENSE`) |
| `fontawesome/all.min.css` | `@fortawesome/fontawesome-free` on npm | 6.5.2 | Icons CC BY 4.0, fonts SIL OFL 1.1, code MIT (`fontawesome/LICENSE.txt`) |
| `fontawesome/fa-solid-900.woff2` | `@fortawesome/fontawesome-free` on npm | 6.5.2 | SIL OFL 1.1 |
| `fonts/patrick-hand-*-400-normal.woff2` | `@fontsource/patrick-hand` on npm | 5.3.0 | SIL OFL 1.1 (`fonts/OFL-patrick-hand.txt`) |
| `fonts/short-stack-latin-400-normal.woff2` | `@fontsource/short-stack` on npm | 5.3.0 | SIL OFL 1.1 (`fonts/OFL-short-stack.txt`) |
| `fonts/manifest.json` | subset `unicode-range` values from the `@fontsource` packages | 5.3.0 | MIT (`fonts/LICENSE-fontsource.txt`) |

Only the Font Awesome **solid** webfont is vendored: the game never uses `fa-regular`,
`fa-brands`, or the v4 compatibility faces, so the offline builder drops those `@font-face`
rules instead of shipping dead font requests.

## Refreshing

Download the tarballs listed in `versions.json` from the npm registry, copy the same files
back into place, update `versions.json` and the SHA-256 list below, then run:

```bash
node scripts/build-offline-html.mjs --out /tmp/offline.html
node scripts/build-windows.mjs --skip-exe
```

## SHA-256

```text
bdf68e297d6c4ec85b8dd693b8781d99db0090449c9a3ba69948eede08c9275a  matter-js/matter.min.js
5ceaaba22d75b58e04150311f596306562a3e595e27ed4b1dfa451b82dda9e50  fontawesome/all.min.css
ae17c16afbea216707b2203ea1cf9bdb45b9bfe47d0f4ae3258ddbc6294dd02f  fontawesome/fa-solid-900.woff2
ac5bc9033b2572bf84d39f7150c1634e37ed16e8dbee632d6d0bceac0bbf0199  fonts/patrick-hand-latin-400-normal.woff2
7813e19e2d80efee8ace1de69517c99a0eb3059917336c4c8fccddbd8c838a9e  fonts/patrick-hand-vietnamese-400-normal.woff2
eeed62bca9927bcbd97fa2432f2344013b1bed43f0529d926f00aa63c5d050a36  fonts/short-stack-latin-400-normal.woff2
```
