package com.doodle.physics.draw;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

/**
 * Thin Android host for the single-file HTML5 game.
 *
 * The WebView is deliberately kept free of vendor-specific imports. The
 * SdkBridge message contract is shared by the Huawei, Amazon, and Samsung
 * variants, so each store flavor can add its own SDK without changing the
 * game asset.
 */
public final class MainActivity extends Activity {
    private WebView gameWebView;
    private SdkBridge sdkBridge;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureSystemBars();

        FrameLayout root = new FrameLayout(this);
        gameWebView = new WebView(this);
        gameWebView.setBackgroundColor(Color.rgb(247, 240, 216));
        root.addView(gameWebView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));
        setContentView(root);

        WebSettings settings = gameWebView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setMediaPlaybackRequiresUserGesture(false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // The game uses HTTPS CDN resources from a local file asset.
            settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        }

        gameWebView.setWebViewClient(new WebViewClient());
        if (BuildConfig.DEBUG) {
            WebView.setWebContentsDebuggingEnabled(true);
        }

        // SDKBridge is the provider-neutral name used by the game. The other
        // aliases preserve compatibility with Huawei WebView integrations.
        sdkBridge = new SdkBridge(this, gameWebView, BuildConfig.STORE_PROVIDER);
        gameWebView.addJavascriptInterface(sdkBridge, "SDKBridge");
        gameWebView.addJavascriptInterface(sdkBridge, "HMSCoreWebViewBridge");
        gameWebView.addJavascriptInterface(sdkBridge, "HuaweiHMS");
        gameWebView.loadUrl("file:///android_asset/index.html");
    }

    private void configureSystemBars() {
        Window window = getWindow();
        window.setStatusBarColor(Color.rgb(247, 240, 216));
        window.setNavigationBarColor(Color.rgb(247, 240, 216));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        }
    }

    @Override
    public void onBackPressed() {
        if (gameWebView != null && gameWebView.canGoBack()) {
            gameWebView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (gameWebView != null) {
            gameWebView.removeJavascriptInterface("SDKBridge");
            gameWebView.removeJavascriptInterface("HMSCoreWebViewBridge");
            gameWebView.removeJavascriptInterface("HuaweiHMS");
            gameWebView.destroy();
            gameWebView = null;
        }
        if (sdkBridge != null) {
            sdkBridge.destroy();
            sdkBridge = null;
        }
        super.onDestroy();
    }
}
