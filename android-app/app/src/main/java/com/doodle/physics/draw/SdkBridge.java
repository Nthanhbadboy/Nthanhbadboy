package com.doodle.physics.draw;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import org.json.JSONObject;

/**
 * Small JSON bridge shared by the store variants.
 *
 * The free release exposes only the provider-neutral ad callback contract.
 * It has no store transaction or entitlement entry point. Store monetization
 * can be added later with the official SDK for the selected storefront, real
 * products, and server-side verification.
 */
public final class SdkBridge {
    private static final String TAG = "PhysicsDrawSdk";

    private final WebView webView;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final StoreAdapter storeAdapter;

    public SdkBridge(Activity ignoredActivity, WebView webView, String provider) {
        this.webView = webView;
        this.storeAdapter = new DisabledStoreAdapter(provider == null ? "unknown" : provider);
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
                    storeAdapter.showInterstitial(adUnitId, this::dispatchInterstitialClosed);
                } else if ("show_rewarded".equals(action)) {
                    storeAdapter.showRewarded(adUnitId, () -> dispatchRewardedComplete(true));
                }
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
        void destroy();
    }

    /**
     * Dependency-free adapter used while all monetization is disabled.
     */
    private static final class DisabledStoreAdapter implements StoreAdapter {
        private final String provider;
        private final Handler handler = new Handler(Looper.getMainLooper());

        DisabledStoreAdapter(String provider) {
            this.provider = provider;
        }

        @Override
        public String providerName() {
            return provider;
        }

        @Override
        public void showBanner(String adUnitId) {
            Log.d(TAG, "Banner request ignored while monetization is disabled: " + adUnitId);
        }

        @Override
        public void showInterstitial(String adUnitId, Runnable onClosed) {
            Log.d(TAG, "Interstitial request ignored while monetization is disabled: " + adUnitId);
            handler.postDelayed(onClosed, 350L);
        }

        @Override
        public void showRewarded(String adUnitId, Runnable onRewarded) {
            Log.d(TAG, "Rewarded request ignored while monetization is disabled: " + adUnitId);
            handler.postDelayed(onRewarded, 350L);
        }

        @Override
        public void destroy() {
            handler.removeCallbacksAndMessages(null);
        }
    }
}
