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
- Huawei Ads and IAP WebView hooks with browser-safe mocks. Native hosts can provide `HMSCoreWebViewBridge`, `HuaweiAds`, or `HuaweiIAP`, or invoke the global callbacks exposed by `HMSGameCallbacks`.

The test ad unit IDs and IAP SKU IDs are grouped near the top of the application script in `HMS_CONFIG` and `IAP_SKUS`.
