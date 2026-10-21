import 'package:flutter/foundation.dart';
import 'package:huawei_ads/huawei_ads.dart';

/// Cấu hình tập trung chính thức cho Huawei AppGallery & Huawei Petal Ads SDK (HMS Only - NO AdMob).
class HuaweiAdsConfig {
  HuaweiAdsConfig._();

  /// Huawei App ID chính thức trên AppGallery Connect
  static const String appId = '119454967';

  /// Mã đơn vị quảng cáo Banner cố định dưới đáy màn hình (Banner_Bottom - Enabled)
  static const String bannerAdSlotId = 'g37tebz64w';

  /// Mã đơn vị quảng cáo Interstitial sau chu trình làm sạch loa (Interstitial_AfterClean - Enabled)
  static const String interstitialAdSlotId = 'e8du1bx9pa';

  /// Mã đơn vị quảng cáo Interstitial dự phòng tăng tỷ lệ lấp đầy (Interstitial_AfterClean #2 - Enabled)
  static const String backupInterstitialAdSlotId = 'y20zf3cylg';

  /// Thông tin nhà phát triển & định danh ứng dụng chuẩn AppGallery Connect
  static const String developerName = 'NGUYEN MINH THANH';
  static const String appName = 'Water Ejector: Speaker Cleaner';
  static const String packageName = 'NGUYENMINHTHANH.WaterEjector';
  static const String developerEmail = 'alphaplus.thanh82@gmail.com';

  /// Khóa SharedPreferences lưu trạng thái chấp thuận Chính sách Bảo mật & Ngôn ngữ
  static const String privacyAcceptedPrefsKey = 'is_privacy_accepted';
  static const String selectedLocalePrefsKey = 'selected_locale_code';

  static bool _sdkInitialized = false;

  static bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isSdkInitialized => _sdkInitialized;

  /// Đặt lại trạng thái khởi tạo trong môi trường Unit/Widget Test
  @visibleForTesting
  static void resetForTesting() {
    _sdkInitialized = false;
  }

  /// Chỉ khởi tạo Huawei Petal Ads SDK SAU KHI người dùng đã đồng ý Chính sách Bảo mật
  /// (tuân thủ nghiêm ngặt quy định không thu thập OAID trước khi có sự đồng ý trên AppGallery).
  static Future<void> ensureSdkInitialized() async {
    if (_sdkInitialized) return;
    if (!isAndroidPlatform) {
      _sdkInitialized = true;
      return;
    }

    try {
      await HwAds.init();
      await HwAds.setRequestOptions(
        RequestOptions(
          nonPersonalizedAd: NonPersonalizedAd.ALLOW_ALL.value,
          adContentClassification:
              ContentClassification.AD_CONTENT_CLASSIFICATION_W,
        ),
      );
      _sdkInitialized = true;
      debugPrint(
        'Huawei Petal Ads SDK initialized (App ID: $appId, Banner: $bannerAdSlotId, Interstitial: $interstitialAdSlotId).',
      );
    } catch (e) {
      _sdkInitialized = true;
      debugPrint('Huawei Petal Ads SDK initialization warning: $e');
    }
  }
}
