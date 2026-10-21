package com.doodle.physics.draw;

import android.app.Activity;
import android.util.Log;

/**
 * Links the Huawei release to the official HMS Core IAP SDK without exposing
 * a checkout flow in the free release. Products and delivery stay disabled
 * until the AppGallery product catalogue, AG Connect configuration, and
 * server-side purchase verification are ready.
 */
public final class HuaweiIapIntegration {
    private static final String TAG = "HuaweiIapIntegration";

    private HuaweiIapIntegration() {
    }

    public static void initialize(Activity activity) {
        if (activity == null) {
            return;
        }
        try {
            // Reflection keeps the host class resilient across HMS Core minor
            // versions while the Huawei flavor still packages the official SDK.
            Class<?> iap = Class.forName("com.huawei.hms.iap.Iap");
            Object client = iap.getMethod("getIapClient", Activity.class)
                    .invoke(null, activity);
            if (client == null) {
                Log.w(TAG, "HMS Core IAP client is unavailable; paid features remain disabled.");
            } else {
                Log.i(TAG, "Official HMS Core IAP SDK is linked; paid features remain disabled.");
            }
        } catch (Exception exception) {
            // A device without a usable HMS Core environment must still run
            // the free game. No product or entitlement is attempted here.
            Log.w(TAG, "HMS Core IAP initialization skipped.", exception);
        }
    }
}
