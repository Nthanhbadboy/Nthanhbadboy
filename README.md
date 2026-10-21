# One-Line Physics Draw

A single-file HTML5 doodle notebook physics game. Draw one line, press **PLAY**, and use Matter.js gravity to guide the ball into the cup.

## Run locally

Open `index.html` in a modern browser, or serve the repository with any static server:

```bash
python3 -m http.server 4173
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

Import `android-app` into Android Studio and use **Build > Generate Signed Bundle / APK** for a signed release. The source is dependency-free on purpose: `SdkBridge.java` contains the provider-neutral JSON contract and a build-safe adapter that rejects IAP while monetization is disabled. There are no third-party payment SDKs or payment resources in the free build. Replace the disabled adapter only with the official Huawei IAP implementation, approved provider SDKs, real product IDs, and server-side receipt verification before enabling paid features. The selected flavor is exposed through `BuildConfig.STORE_PROVIDER`; the page selects Huawei test ad units, Google Android test units for Samsung/AdMob, or Amazon placeholders through `AD_UNITS_BY_PROVIDER`. Monetization is currently disabled in the release-safe build.

See [`SIGNING.md`](SIGNING.md) for permanent release-keystore setup and GitHub Actions secrets.

### Privacy policy

The store-safe release privacy policy is available as a public GitHub page at [`docs/privacy-policy.md`](docs/privacy-policy.md):

- Policy: `https://github.com/Nthanhbadboy/Nthanhbadboy/blob/arena/667974da-nthanhbadboy/docs/privacy-policy.md`
- Privacy rights: use the same public policy URL and the **Privacy rights** section.

GitHub Pages deployment is optional; if Pages is enabled later, the HTML copy can be served at `https://nthanhbadboy.github.io/Nthanhbadboy/privacy-policy.html`.

### GitHub build

`.github/workflows/android-build.yml` always builds the three signed debug APKs for testing. If all four signing secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) exist, it also signs and uploads the three release APKs; otherwise it skips release rather than uploading an unsigned APK. A parallel Windows job uploads `physics-draw-windows.zip`, a portable HTML package with `Run-Physics-Draw.bat`; it is not a native `.exe` and requires the CDN network assets.
