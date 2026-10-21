# One-Line Physics Draw

A single-file HTML5 doodle notebook physics game. Draw one line, press **PLAY**, and use Matter.js gravity to guide the ball into the cup.

## Run locally

Open `index.html` in a modern browser, or serve the repository with any static server:

```bash
python3 -m http.server 4173
```

The game includes:

- 100 deterministic, extensible level definitions in `index.html`.
- Matter.js line bodies, gravity, cup sensor collision detection, hazards, win/fail states, and a line-length budget.
- Responsive notebook UI with level picker, shop, result, and browser ad-simulation modals.
- English, Vietnamese, Simplified Chinese, Spanish, and Russian translations.
- Local progress persistence for unlocked levels, stars, hints, language, sound, and ad removal.
- Huawei Ads and IAP WebView hooks with browser-safe mocks. Native hosts can provide `SDKBridge`, `HMSCoreWebViewBridge`, `HuaweiAds`, or `HuaweiIAP`, or invoke the global callbacks exposed by `HMSGameCallbacks`.

The test ad unit IDs and IAP SKU IDs are grouped near the top of the application script in `HMS_CONFIG` and `IAP_SKUS`.

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

Import `android-app` into Android Studio and use **Build > Generate Signed Bundle / APK** for a signed release. The source is dependency-free on purpose: `SdkBridge.java` contains the provider-neutral JSON contract and a build-safe `DemoStoreAdapter`. Replace that adapter with the official Huawei Ads/IAP, Amazon Ads/APS, or approved Samsung/AdMob implementation before publishing; do not ship the demo callback adapter as a monetized production integration. The selected flavor is exposed through `BuildConfig.STORE_PROVIDER`; the page selects Huawei test units, Google Android test units for Samsung/AdMob, or Amazon placeholders through `AD_UNITS_BY_PROVIDER`. Replace the Amazon placeholders and connect the official native SDK before publishing.

### GitHub build

`.github/workflows/android-build.yml` always builds the three signed debug APKs for testing. If all four signing secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) exist, it also signs and uploads the three release APKs; otherwise it skips release rather than uploading an unsigned APK. A parallel Windows job uploads `physics-draw-windows.zip`, a portable HTML package with `Run-Physics-Draw.bat`; it is not a native `.exe` and requires the CDN network assets.
