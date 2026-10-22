# One-Line Physics Draw

A single-file HTML5 doodle notebook physics game. Draw one line, press **PLAY**, and use Matter.js gravity to guide the ball into the cup.

## Run locally

Open `index.html` in a modern browser, or serve the repository with any static server:

```bash
python3 -m http.server 4173
```

For a copy that needs no internet at all (every library and font inlined), build the offline
page used by the Windows packages:

```bash
node scripts/build-offline-html.mjs --out build/offline/index.html
```

The game includes:

- Store-safe free mode: Ads and IAP UI are disabled until real provider SDKs and verified products are configured.
- 100 deterministic, extensible level definitions in `index.html`.
- Matter.js line bodies, gravity, cup sensor collision detection, hazards, win/fail states, and a line-length budget.
- Responsive notebook UI with level picker, result modal, and provider-neutral ad hooks kept disabled in the free build.
- English, Vietnamese, Simplified Chinese, Spanish, and Russian translations.
- Local progress persistence for unlocked levels, stars, hints, language, and sound.
- Huawei WebView hooks for the official Ads integration. Native hosts can provide `SDKBridge`, `HMSCoreWebViewBridge`, or `HuaweiAds`, or invoke the global callbacks exposed by `HMSGameCallbacks`.

The free release ships no store product IDs, transaction UI, or browser transaction fallback. The Huawei flavor links the official HMS Core IAP SDK and initializes its client only; it does not query products, open checkout, or grant entitlements. Enable paid features only after adding the AppGallery catalogue, AG Connect configuration, and server-side receipt verification. No third-party payment SDK is used.

## Android Studio wrapper

`android-app/` is a ready-to-import Android Studio project that hosts the same game asset in a WebView:

```text
android-app/app/src/main/assets/index.html
```

The Gradle `syncWebAsset` task copies the canonical root `index.html` into that asset directory before every build. The app targets API 35, supports Android 5.0/API 21+, enables JavaScript, DOM storage, Canvas, and HTTPS asset dependencies, and requests `INTERNET` plus `ACCESS_NETWORK_STATE`.

Three store variants are included. In Android Studio, choose the matching variant under **Build Variants** (`huaweiRelease`, `amazonRelease`, or `samsungRelease`). If a local Gradle installation is available, the equivalent tasks are:

```bash
gradle -p android-app assembleHuaweiDebug
gradle -p android-app assembleAmazonDebug
gradle -p android-app assembleSamsungDebug
```

Import `android-app` into Android Studio and use **Build > Generate Signed Bundle / APK** with the real production keystore for a signed release. The source is dependency-free apart from the official Huawei flavor link: `SdkBridge.java` contains the provider-neutral JSON contract and a build-safe adapter that rejects IAP while monetization is disabled. The Huawei release links and initializes the official HMS Core IAP client only; it does not query products, open checkout, create orders, or grant entitlements. Add real AppGallery products, AG Connect configuration, and server-side receipt verification before enabling paid features. The selected flavor is exposed through `BuildConfig.STORE_PROVIDER`; the page selects Huawei test ad units, Google Android test units for Samsung/AdMob, or Amazon placeholders through `AD_UNITS_BY_PROVIDER`. Monetization is currently disabled in the release-safe build.

See [`SIGNING.md`](SIGNING.md) for permanent release-keystore setup and GitHub Actions secrets.

### Privacy policy

The store-safe release privacy policy is available as a public GitHub page at [`docs/privacy-policy.md`](docs/privacy-policy.md):

- Policy: `https://github.com/Nthanhbadboy/Nthanhbadboy/blob/arena/667974da-nthanhbadboy/docs/privacy-policy.md`
- Privacy rights: use the same public policy URL and the **Privacy rights** section.

GitHub Pages deployment is optional; if Pages is enabled later, the HTML copy can be served at `https://nthanhbadboy.github.io/Nthanhbadboy/privacy-policy.html`.

### GitHub build

`.github/workflows/android-build.yml` builds and verifies the three signed release APKs only when all four production signing secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) are present and the keystore validates. It never generates a temporary key and never uploads an unsigned APK; without the real keystore, the Android job stops before assembly. The verification step audits the final merged permissions and all text-bearing APK entries for Google Play Billing and known third-party payment signatures, and confirms that only the Huawei APK contains the official HMS Core IAP package.

Windows packaging lives in its own workflow, `.github/workflows/windows-build.yml`; see [Windows build](#windows-build).

## Windows build

`windows/` produces a native Windows executable with the whole game compiled into it, so it runs
with no internet connection, no Python, no installer and no admin rights:

```text
windows-release/
├── Physics-Draw-Windows.zip        <- the thing to download
├── build-report.json
└── Physics-Draw-Windows/
    ├── Physics-Draw.exe            64-bit launcher, offline page embedded (771 KiB)
    ├── index.html                  the same offline page, for "open in any browser"
    ├── README.txt                  English + Tiếng Việt quick start
    └── SHA256SUMS.txt
```

Double-click `Physics-Draw.exe`. It serves the game on `http://127.0.0.1:4173/` and opens your
default browser; keep that small console window open while playing and close it to quit. If
SmartScreen warns about an unsigned app, pick **More info → Run anyway**.

Why a loopback server instead of just opening the HTML file? Chromium browsers (Edge, Chrome,
Brave) give `file://` documents an opaque origin and refuse `localStorage` for them, which would
silently discard unlocked levels, stars, hints and the language setting. Serving from a stable
loopback origin keeps saved progress working exactly like the web and Android builds, and the
launcher always tries port `4173` first so that origin never changes.

`windows/launcher.c` is a small Win32 program (Winsock plus `ShellExecuteW`) with no runtime
dependency beyond Windows itself. It binds **127.0.0.1 only** — never the LAN — serves
`/`, `/index.html`, `/favicon.ico` and a health endpoint, answers nothing else, rejects
non-`GET`/`HEAD` methods, times idle connections out, and hands the page over straight from
memory. Flags: `--port`, `--no-browser`, `--print-url`, `--extract <file>`, `--version`, `--help`.

### Offline assets

`vendor/` holds pinned copies of everything `index.html` normally loads from CDNs — Matter.js
0.19.0, Font Awesome Free 6.5.2 (solid face only, the only one the game uses), Short Stack and
Patrick Hand (latin plus the Vietnamese subset that renders the Tiếng Việt UI) — together with
their licenses and SHA-256 sums. `scripts/build-offline-html.mjs` inlines them into one
self-contained HTML file and **fails the build** if the CDN block or the pinned versions in
`index.html` drift away from `vendor/versions.json`, so an offline package can never quietly
regress into needing the network. The canonical root `index.html` is untouched and still the
asset the browser and the Android WebView use.

### Build it yourself

Only Zig is required; it cross-compiles the Windows `.exe` from Linux, macOS or Windows:

```bash
python3 -m pip install ziglang==0.17.0     # or: brew install zig / winget install zig
npm ci                                     # jsdom, used by the verification step
ZIG="python3 -m ziglang" node scripts/build-windows.mjs
node scripts/verify-offline-page.mjs windows/build/index.html
```

`scripts/build-windows.mjs` accepts `--out <dir>`, `--skip-exe` (offline page only),
`--no-selftest` and `--keep-temp`. Outputs land in `windows-release/`, intermediates in
`windows/build/`; both are git-ignored.

### What every build verifies

- **Launcher self-test (12 checks).** The same source is compiled for the build host, started on a
  free loopback port and probed over real HTTP: the body must equal the offline page byte for
  byte, `HEAD` must return headers only, `/favicon.ico` must match the PNG, unknown paths 404,
  `POST` 405, and `--extract` / `--version` must work. Linux cannot run a `.exe`, so this is what
  proves the serving logic on every build.
- **Executable checks.** MZ/PE signatures, `0x8664` x86-64 machine type, console subsystem,
  `WS2_32`/`SHELL32`/`KERNEL32` imports, size bounds, the embedded health token, and no CDN host
  name anywhere inside the binary.
- **Zip checks.** The archive is reopened, every entry inflated, CRC-32 verified and compared
  against its source file, so a corrupt package never ships.
- **Page checks (14 checks).** `scripts/verify-offline-page.mjs` boots the page in jsdom with a
  mocked canvas and asserts Matter.js is usable, no remote tag survived, the level picker lists
  all 100 levels, the Vietnamese UI applies, and the physics simulation steps without errors.

### Windows CI

`.github/workflows/windows-build.yml` runs that whole pipeline on `ubuntu-latest` (no Windows
runner and no secrets needed) and uploads the artifact **`physics-draw-windows`** — open the
workflow run and download it from *Artifacts*. Pushes to `v*` tags also attach
`Physics-Draw-Windows.zip` to the matching GitHub release with its SHA-256 sums.
