# Windows package

A native Windows build of One-Line Physics Draw: one `.exe`, one double-click, no internet.

```text
windows/
├── launcher.c            the Win32 launcher (Winsock loopback server + ShellExecuteW)
├── app.json              name, version, port, zip layout, PE sanity bounds
├── package-README.txt    the bilingual quick start that ships inside the zip
├── build/                generated: offline index.html, generated_assets.h, staged binaries
└── ...

scripts/
├── build-offline-html.mjs  index.html + vendor/ -> one self-contained HTML file
├── build-windows.mjs       offline HTML -> Physics-Draw.exe -> verified zip
└── verify-offline-page.mjs boots the offline page in jsdom and asserts the game runs

vendor/                   pinned Matter.js, Font Awesome solid, Short Stack, Patrick Hand + licenses
windows-release/          generated: the zip, the unpacked folder, build-report.json
```

## Build

```bash
python3 -m pip install ziglang==0.17.0     # or: brew install zig / winget install zig
npm ci                                     # jsdom, for verify-offline-page.mjs
ZIG="python3 -m ziglang" node scripts/build-windows.mjs
```

`ZIG` may be a plain binary (`zig`) or a whole command line (`python3 -m ziglang`); without it
the script probes `zig` on `PATH` and then `python3 -m ziglang` / `python -m ziglang`. A clean
build takes a few seconds and writes:

```text
windows-release/Physics-Draw-Windows.zip
windows-release/Physics-Draw-Windows/{Physics-Draw.exe,index.html,README.txt,SHA256SUMS.txt}
windows-release/build-report.json
```

Flags: `--out <dir>`, `--skip-exe` (offline page only), `--no-selftest`, `--keep-temp`.
The toolchain is checked before anything is deleted, so a failed build never removes the
previous package.

## How it works

1. `build-offline-html.mjs` reads the canonical root `index.html`, replaces exactly the five CDN
   tags (two preconnects, Google Fonts, Font Awesome, Matter.js) with inlined copies from
   `vendor/`, adds a data-URI favicon, and refuses to continue if the block or the pinned
   versions changed — an offline package must never silently depend on the network again.
2. `build-windows.mjs` turns that HTML and `assets/favicon-64.png` into `generated_assets.h`
   (plain C byte arrays, no code generation tricks) and compiles `launcher.c` with
   `zig cc -O2 -target x86_64-windows-gnu`, which needs no MSVC or MinGW installation and
   produces a static 64-bit PE that only imports `WS2_32`, `SHELL32` and `KERNEL32`.
3. At run time the launcher binds `127.0.0.1` (trying port 4173 first, then the next few, then
   any free port), answers `GET /` from memory, and asks Windows to open the URL in the default
   browser. If another copy is already listening it detects it through the health endpoint and
   just opens the browser instead of fighting for the port.

Serving over loopback rather than opening `index.html` directly is deliberate: Chromium browsers
give `file://` documents an opaque origin and deny them `localStorage`, so saved progress would
vanish. A stable loopback origin keeps unlocks, stars, hints and language, like the web build.

## Verification

Every build runs these checks and stops on the first failure:

| Stage | What it proves |
| --- | --- |
| Launcher self-test | The same C source compiled for the build host really serves the page: 12 HTTP checks against a live process (body equals the offline page, `HEAD` has no body, favicon matches, 404/405 behave, `--extract` and `--version` work) |
| Executable audit | MZ/PE signatures, `0x8664` machine, console subsystem, `WS2_32`/`SHELL32`/`KERNEL32` imports, size bounds, embedded health token, and no `cdnjs.cloudflare.com` / `fonts.googleapis.com` / `fonts.gstatic.com` / `unpkg.com` / `jsdelivr.net` string inside the binary |
| Zip audit | The archive is reopened, each entry inflated, CRC-32 checked and compared byte for byte with its source |
| DOM boot | `scripts/verify-offline-page.mjs` runs the page in jsdom with a mocked canvas: Matter.js available, no remote tag, 100 levels listed, Vietnamese UI applied, physics steps without errors |

CI repeats all of it in `.github/workflows/windows-build.yml` on `ubuntu-latest` and uploads the
artifact `physics-draw-windows`; `v*` tags also get the zip attached to the GitHub release.

## Bumping things

- **Game changes**: edit root `index.html` only, then rebuild. The offline page is derived, never
  edited by hand.
- **Library versions**: update the CDN pin in `index.html` *and* `vendor/versions.json` together
  with the new files in `vendor/` (see [`vendor/README.md`](../vendor/README.md)), otherwise the
  build fails on the mismatch — that is intentional.
- **App name / version / port**: `windows/app.json` feeds the executable metadata, the health
  endpoint, the package folder name and the zip name.

## Troubleshooting

- **SmartScreen / antivirus blocks the file**: it is unsigned. Choose *More info → Run anyway*, or
  use `index.html` from the same folder in any browser (progress will not persist in Chromium).
- **A different port each run** would move the browser origin and hide saved progress; free port
  4173 or pass `--port 4173` explicitly.
- **`Zig was not found`**: `python3 -m pip install ziglang==0.17.0`, then
  `ZIG="python3 -m ziglang" node scripts/build-windows.mjs`.
- **No browser opened** (servers, sandboxed accounts): the console prints the address; open it
  manually, or run with `--print-url`.
