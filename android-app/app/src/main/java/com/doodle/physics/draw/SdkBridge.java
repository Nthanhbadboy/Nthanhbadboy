package com.doodle.physics.draw;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import org.json.JSONObject;

/**
 * Small JSON bridge shared by all store variants.
 *
 * The HTML game sends messages such as:
 * {"module":"ads","action":"show_rewarded","adUnitId":"..."}
 * {"module":"iap","action":"purchase","productId":"..."}
 *
 * The default adapter is intentionally dependency-free so the free release
 * builds without any payment SDK or payment resource. Replace the disabled
 * adapter only with the official SDK for the selected storefront, real product
 * configuration, and server-side receipt verification before enabling paid
 * features. The browser game has no purchase fallback.
 */
public final class SdkBridge {
    private static final String TAG = "PhysicsDrawSdk";

    private final Activity activity;
    private final WebView webView;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final StoreAdapter storeAdapter;

    public SdkBridge(Activity activity, WebView webView, String provider) {
        this.activity = activity;
        this.webView = webView;
        this.storeAdapter = new DemoStoreAdapter(provider == null ? "unknown" : provider);
    }

    @JavascriptInterface
    public void postMessage(final String json) {
        if (json == null || json.trim().isEmpty()) {
            return;
        }
        // WebView invokes @JavascriptInterface methods off the UI thread.
        mainHandler.post(() -> handleMessage(json));
    }

    @JavascriptInterface
    public String getProvider() {
        return storeAdapter.providerName();
    }

    private void handleMessage(String json) {
        try {
            JSONObject message = new JSONObject(json);
            String module = message.optString("module", "");
            String action = message.optString("action", "");

            if ("ads".equals(module)) {
                String adUnitId = message.optString("adUnitId", "");
                if ("show_banner".equals(action)) {
                    storeAdapter.showBanner(adUnitId);
                } else if ("show_interstitial".equals(action)) {
                    storeAdapter.showInterstitial(adUnitId, () -> dispatchInterstitialClosed());
                } else if ("show_rewarded".equals(action)) {
                    storeAdapter.showRewarded(adUnitId, () -> dispatchRewardedComplete(true));
                }
                return;
            }

            if ("iap".equals(module) && "purchase".equals(action)) {
                String productId = message.optString("productId", "");
                storeAdapter.purchase(productId,
                        () -> dispatchPurchaseResult(productId, true),
                        () -> dispatchPurchaseResult(productId, false));
                return;
            }

            Log.d(TAG, "Ignoring unknown WebView message: " + json);
        } catch (Exception exception) {
            Log.w(TAG, "Invalid WebView message", exception);
        }
    }

    private void dispatchInterstitialClosed() {
        evaluateJavascript("window.HMSGameCallbacks && window.HMSGameCallbacks.onInterstitialClosed && window.HMSGameCallbacks.onInterstitialClosed();");
    }

    private void dispatchRewardedComplete(boolean success) {
        evaluateJavascript("window.HMSGameCallbacks && window.HMSGameCallbacks.onRewardedComplete && window.HMSGameCallbacks.onRewardedComplete(" + success + ");");
    }

    private void dispatchPurchaseResult(String productId, boolean success) {
        String quotedProductId = JSONObject.quote(productId == null ? "" : productId);
        evaluateJavascript("window.HMSGameCallbacks && window.HMSGameCallbacks.onPurchaseResult && window.HMSGameCallbacks.onPurchaseResult(" + quotedProductId + "," + success + ");");
    }

    private void evaluateJavascript(final String script) {
        mainHandler.post(() -> {
            if (webView != null) {
                webView.evaluateJavascript(script, null);
            }
        });
    }

    public void destroy() {
        storeAdapter.destroy();
        mainHandler.removeCallbacksAndMessages(null);
    }

    private interface StoreAdapter {
        String providerName();
        void showBanner(String adUnitId);
        void showInterstitial(String adUnitId, Runnable onClosed);
        void showRewarded(String adUnitId, Runnable onRewarded);
        void purchase(String productId, Runnable onSuccess, Runnable onFailure);
        void destroy();
    }

    /**
     * Build-safe fallback. It keeps the wrapper testable until the selected
     * store's official SDK is installed and this adapter is replaced.
     */
    private static final class DemoStoreAdapter implements StoreAdapter {
        private final String provider;
        private final Handler handler = new Handler(Looper.getMainLooper());

        DemoStoreAdapter(String provider) {
            this.provider = provider;
        }

        @Override
        public String providerName() {
            return provider;
        }

        @Override
        public void showBanner(String adUnitId) {
            Log.d(TAG, "Banner requested by " + provider + ": " + adUnitId);
        }

        @Override
        public void showInterstitial(String adUnitId, Runnable onClosed) {
            Log.d(TAG, "Interstitial requested by " + provider + ": " + adUnitId);
            handler.postDelayed(onClosed, 350L);
        }

        @Override
        public void showRewarded(String adUnitId, Runnable onRewarded) {
            Log.d(TAG, "Rewarded ad requested by " + provider + ": " + adUnitId);
            handler.postDelayed(onRewarded, 350L);
        }

        @Override
        public void purchase(String productId, Runnable onSuccess, Runnable onFailure) {
            Log.w(TAG, "IAP is disabled until the official " + provider + " IAP adapter and receipt verification are configured: " + productId);
            handler.postDelayed(onFailure, 350L);
        }

        @Override
        public void destroy() {
            handler.removeCallbacksAndMessages(null);
        }
    }
}
