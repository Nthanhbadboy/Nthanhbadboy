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
gradle -p android-app assembleHuaweiRelease
gradle -p android-app assembleAmazonRelease
gradle -p android-app assembleSamsungRelease
```

Import `android-app` into Android Studio and use **Build > Generate Signed Bundle / APK** for a signed release. The source is dependency-free on purpose: `SdkBridge.java` contains the provider-neutral JSON contract and a build-safe `DemoStoreAdapter`. Replace that adapter with the official Huawei Ads/IAP, Amazon Ads/APS, or approved Samsung/AdMob implementation before publishing; do not ship the demo callback adapter as a monetized production integration. The selected flavor is exposed through `BuildConfig.STORE_PROVIDER`; the page selects Huawei test units, Google Android test units for Samsung/AdMob, or Amazon placeholders through `AD_UNITS_BY_PROVIDER`. Replace the Amazon placeholders and connect the official native SDK before publishing.

### GitHub build

`.github/workflows/android-build.yml` builds all three unsigned release APKs plus signed debug APKs for device testing, then uploads them together as the `physics-draw-apks` artifact. The debug APKs are installable but are not suitable for store submission; configure a release keystore and signing secrets before distribution.
