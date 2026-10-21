import 'package:flutter/material.dart';
import 'package:huawei_ads/huawei_ads.dart';

import '../l10n/app_localizations.dart';
import '../utils/huawei_ads_config.dart';

/// Widget tái sử dụng hiển thị Huawei Petal Banner Ad (320x50) cố định dưới đáy màn hình.
///
/// Thiết kế chuẩn AppGallery:
/// - Đặt bên trong `Scaffold.bottomNavigationBar` (TUYỆT ĐỐI KHÔNG đặt trong ScrollView).
/// - Chỉ tải quảng cáo sau khi người dùng đã chấp thuận Chính sách Bảo mật (`isPrivacyAccepted == true`).
class HuaweiBottomBannerAd extends StatefulWidget {
  const HuaweiBottomBannerAd({
    super.key,
    required this.isPrivacyAccepted,
    required this.isAdsSdkReady,
    this.adSlotId = HuaweiAdsConfig.bannerAdSlotId,
  });

  final bool isPrivacyAccepted;
  final bool isAdsSdkReady;
  final String adSlotId;

  @override
  State<HuaweiBottomBannerAd> createState() => _HuaweiBottomBannerAdState();
}

class _HuaweiBottomBannerAdState extends State<HuaweiBottomBannerAd> {
  late final BannerViewController _bannerController;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _bannerController = BannerViewController(
      listener: (AdEvent event, {int? errorCode}) {
        debugPrint(
          'Huawei BannerView (${widget.adSlotId}) event: ${event.name} (code: $errorCode)',
        );
        if (!mounted) return;
        if (event == AdEvent.loaded) {
          setState(() => _isBannerLoaded = true);
        } else if (event == AdEvent.failed) {
          setState(() => _isBannerLoaded = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool canLoadAds = widget.isPrivacyAccepted && widget.isAdsSdkReady;

    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF050914),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: !canLoadAds
            ? const SizedBox(width: 320, height: 50)
            : HuaweiAdsConfig.isAndroidPlatform
                ? SizedBox(
                    width: 320,
                    height: 50,
                    child: BannerView(
                      adSlotId: widget.adSlotId,
                      size: BannerAdSize.s320x50,
                      adParam: AdParam(),
                      refreshDuration: const Duration(seconds: 60),
                      controller: _bannerController,
                    ),
                  )
                : Container(
                    width: 320,
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10203B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFCE0E2D).withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCE0E2D),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.translate(
                              'ad_banner_label',
                              <String, String>{'slotId': widget.adSlotId},
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE0E6ED),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _isBannerLoaded
                              ? Icons.check_circle_rounded
                              : Icons.verified_rounded,
                          size: 16,
                          color: const Color(0xFF64FFDA),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
