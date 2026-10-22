# Windows package

A native Windows build of One-Line Physics Draw: one `.exe`, one double-click, no internet.

```text
windows/
├── launcher.c            the Win32 launcher (Winsock loopback server + ShellExecuteW)
├── webview2-host.cpp     the windowed WebView2 app that goes into the MSIX
├── webview2/EventToken.h the one COM type the mingw-w64 headers do not ship
├── app.json              name, version, port, zip layout, MSIX identity, PE sanity bounds
├── app.ico               icon embedded in PhysicsDraw.exe (16…256 px)
├── app.manifest          DPI awareness / asInvoker manifest embedded in PhysicsDraw.exe
├── msix-assets/          Store tiles + splash: base size (validated) and .scale-200 (hi-dpi)
├── package-README.txt    the bilingual quick start that ships inside the zip
├── build/                generated: offline index.html, generated_assets.h, WebView2 SDK, staged binaries
└── ...

scripts/
├── build-offline-html.mjs  index.html + vendor/ -> one self-contained HTML file
├── build-windows.mjs       offline HTML -> Physics-Draw.exe -> verified zip
├── build-store.mjs         offline HTML -> PhysicsDraw.exe -> verified .msix
├── fetch-webview2.mjs      downloads the WebView2 SDK header + x64 loader at build time
├── lib/zip.mjs             ZIP reader/writer and the MSIX block-map deflate helper
└── verify-offline-page.mjs boots the offline page in jsdom and asserts the game runs

vendor/                   pinned Matter.js, Font Awesome solid, Short Stack, Patrick Hand + licenses
windows-release/          generated: the zip, the .msix, the unpacked payloads, the build reports
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
## Store package (MSIX)

`Physics-Draw.exe` opens the game in your browser. The Store package is the same game in the other
shape: **`PhysicsDraw.exe`, a window of its own** built on WebView2 — the Edge engine that ships
with Windows 11 and with Edge on Windows 10 — packed into an unsigned `.msix` that is ready to
upload to Partner Center.

`windows/webview2-host.cpp` is that host. It creates the window, waits for the WebView, maps the
`www` folder next to the executable onto a private origin with `SetVirtualHostNameToFolderMapping`
and loads `https://physicsdraw.local/index.html`, so saved progress behaves exactly like the web
build — with no loopback port, no browser tab and no console window behind the game. It asks for
per-monitor-v2 DPI awareness (at run time and through `windows/app.manifest`), turns off browser
zoom and the status bar, keeps its profile in the package's own local state when packaged and in
`%LOCALAPPDATA%\OneLinePhysicsDraw` when run loose, and explains what to install when the WebView2
runtime or loader DLL is missing instead of failing silently. `--devtools` opens DevTools.

### Build

```bash
python3 -m pip install ziglang==0.17.0
npm ci
ZIG="python3 -m ziglang" node scripts/build-store.mjs
```

```text
windows-release/One-Line-Physics-Draw.msix          <- upload this to Partner Center
windows-release/One-Line-Physics-Draw.msix.sha256
windows-release/msix-report.json                    every check, size and hash of the run
windows-release/store/                              the same payload, unpacked for inspection
├── PhysicsDraw.exe
├── WebView2Loader.dll
├── www/index.html
├── Assets/{Square44x44Logo,Square150x150Logo,Wide310x150Logo,StoreLogo,SplashScreen}.png
└── Assets/<the same five>.scale-200.png
```

Flags: `--out <dir>`, `--publisher "CN=..."`, `--identity-name <name>`, `--version <a.b.c.0>`,
`--force-webview2`, `--keep-temp`, `--quiet`. The three identity values can also come from
`MSIX_PUBLISHER`, `MSIX_IDENTITY_NAME` and `MSIX_VERSION`, which is what CI uses.

### The WebView2 SDK is fetched, never vendored

`WebView2.h` is roughly 3 MB of generated COM declarations, so it does not belong in git.
`scripts/fetch-webview2.mjs` downloads it into the git-ignored `windows/build/webview2/`:

1. from the official NuGet package `microsoft.web.webview2` — what CI runners use; then, if that
   registry is unreachable,
2. from the pinned npm mirror `webview-node@0.1.41`, whose tarball SHA-512 and per-file SHA-256
   are hard-coded in the script.

Whichever source answers, the header is checked for the exact API surface the host uses
(`ICoreWebView2_3`, `ICoreWebView2Controller2`, `SetVirtualHostNameToFolderMapping`, …) and the
loader DLL is parsed as a PE to prove it is x64 and really exports
`CreateCoreWebView2EnvironmentWithOptions`. An SDK that is too old therefore fails the build with a
readable message instead of failing at link time. mingw-w64 ships no `__CRT_UUID_DECL` entries for
these interfaces, so the script also derives `webview2-iids.h` from the GUIDs inside that same
header: no IID is ever copied by hand.

### What is in the package

`AppxManifest.xml` declares a full-trust desktop app: `EntryPoint="Windows.FullTrustApplication"`,
the `runFullTrust` restricted capability, `TargetDeviceFamily Windows.Desktop` from 10.0.17763.0,
and the tiles in `windows/msix-assets/`. Identity, publisher, display name, description and
versions all come from the `msix` block of `windows/app.json`; the publisher display name must
equal the Partner Center account name character for character, or validation rejects the package.

Each tile ships twice in `windows/msix-assets/`: the unqualified base-size file, which is what
Partner Center's acceptance validation looks for when it reads the manifest, and the `.scale-200`
sibling at double the pixels, which high-DPI Start menu tiles can use.

`AppxBlockMap.xml` follows the shape Microsoft's own packer (`microsoft/msix-packaging`) emits:
windows separators in `Name`, one base64 SHA-256 per 64 KiB of *uncompressed* data, `Size` =
uncompressed bytes, `LfhSize` = 30 + name length, and a per-block compressed size produced by
deflating each block with its own `Z_FULL_FLUSH`. The package is **unsigned on purpose**: Partner
Center re-signs what it publishes, so a signature added here would only be stripped again.

### Getting it onto a PC

- **Microsoft Store.** Upload `One-Line-Physics-Draw.msix` in Partner Center. The `Publisher` in
  the manifest must match your account's publisher identity or the submission is rejected; set the
  repository variable `MSIX_PUBLISHER` (Settings → Secrets and variables → Actions → Variables) to
  that `CN=...` value and the next workflow run bakes it in. Reserve the same `Identity Name`
  (`Nthanhbadboy.OneLinePhysicsDraw`) for the app in Partner Center.
- **Sideload for testing.** Windows will not install an unsigned package, so sign it with a
  self-signed certificate whose subject matches the manifest publisher, trust that certificate,
  and install it with Developer Mode or "sideload apps" enabled:

  ```powershell
  New-SelfSignedCertificate -Type Custom -Subject "CN=REPLACE_WITH_STORE_PUBLISHER_ID" `
    -KeyUsage DigitalSignature -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
  $cert = Get-ChildItem "Cert:\CurrentUser\My" |
      Where-Object Subject -eq "CN=REPLACE_WITH_STORE_PUBLISHER_ID"
  Export-PfxCertificate -Cert $cert -FilePath pd-dev.pfx -Password (Read-Host -AsSecureString)
  Export-Certificate -Cert $cert -FilePath pd-dev.cer
  Import-Certificate pd-dev.cer -CertStoreLocation "Cert:\LocalMachine\TrustedPeople"   # admin
  & "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" `
      sign /fd SHA256 /f pd-dev.pfx One-Line-Physics-Draw.msix
  Add-AppxPackage .\One-Line-Physics-Draw.msix
  ```

- **WebView2 runtime.** Windows 11 has it built in. On a Windows 10 machine without it the app
  opens a dialog explaining what is missing and offers Microsoft's Evergreen installer page; the
  portable `Physics-Draw.exe` from the other build needs no runtime at all, only a browser.

## Verification

Every build runs these checks and stops on the first failure:

| Stage | What it proves |
| --- | --- |
| Launcher self-test | The same C source compiled for the build host really serves the page: 12 HTTP checks against a live process (body equals the offline page, `HEAD` has no body, favicon matches, 404/405 behave, `--extract` and `--version` work) |
| Executable audit | MZ/PE signatures, `0x8664` machine, console subsystem, `WS2_32`/`SHELL32`/`KERNEL32` imports, size bounds, embedded health token, and no `cdnjs.cloudflare.com` / `fonts.googleapis.com` / `fonts.gstatic.com` / `unpkg.com` / `jsdelivr.net` string inside the binary |
| Zip audit | The archive is reopened, each entry inflated, CRC-32 checked and compared byte for byte with its source |
| DOM boot | `scripts/verify-offline-page.mjs` runs the page in jsdom with a mocked canvas: Matter.js available, no remote tag, 100 levels listed, Vietnamese UI applied, physics steps without errors |

The MSIX build adds its own checks before it writes a package: the executable must be a PE32+
x86-64 **GUI** image importing nothing beyond `ole32`/`user32`/`shell32`/`kernel32` and the UCRT;
every logo must exist under the exact unqualified name the manifest references, at exactly its base
and scale-200 dimensions — Partner Center resolves those references literally, because a
hand-packed MSIX has no `resources.pri` to map logical names onto qualified files; and the finished
`.msix` is reopened and re-derived — block hashes, `LfhSize` values, content-type coverage,
manifest identity and logo references, plus a byte comparison between the packaged exe and the
compiled one. The packaged `www/index.html` is booted in jsdom like any other build.

CI repeats all of it in `.github/workflows/windows-build.yml` on `ubuntu-latest` and uploads two
artifacts: `physics-draw-windows` (the portable zip) and `physics-draw-msix` (the Store package).
The MSIX job re-verifies the finished package with an independent Python reader, so a bug in the
packer cannot hide behind the packer's own checks. `v*` tags get both files attached to the GitHub
release.

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
- **`could not fetch the WebView2 SDK`**: NuGet and the npm mirror were both unreachable. Retry, or
  set `WEBVIEW2_SOURCE=npm` (or `nuget`) to use the one you can reach.
- **`Add-AppxPackage` refuses the MSIX**: it is unsigned. Sign it with a certificate whose subject
  matches `AppxManifest.xml`, trust that certificate, and enable Developer Mode or sideloading.
- **Partner Center rejects the upload**: the `Publisher` is still the placeholder. Set the
  `MSIX_PUBLISHER` repository variable to your Store publisher identity and re-run the workflow.
- **The window opens but stays blank**: the WebView2 runtime is missing or too old — install the
  Evergreen runtime from Microsoft and start again.
