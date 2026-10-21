import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huawei_ads/huawei_ads.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/water_ejector_provider.dart';
import '../utils/sound_generator.dart';
import '../widgets/wave_visualizer.dart';

/// Cấu hình Ad Slot ID cho Huawei Petal Ads (HMS Ads Kit).
///
/// LƯU Ý KHI PHÁT HÀNH LÊN HUAWEI APPGALLERY:
/// - Các ID dưới đây là Test Ad Slot ID chính thức từ Huawei Developer Documentation.
/// - Trước khi upload bản chính thức lên AppGallery Connect, hãy thay bằng
///   Slot ID thật tạo trong Huawei Petal Publisher Center.
class HuaweiAdsConfig {
  HuaweiAdsConfig._();

  static const String bannerAdSlotId = 'testw6vs28auh3';
  static const String interstitialAdSlotId = 'testb4znbuh3n2';

  static const String developerEmail = 'alphaplus.thanh82@gmail.com';

  static bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InterstitialAd? _interstitialAd;
  late final BannerViewController _bannerController;
  bool _isBannerLoaded = false;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();

    // 1. Khởi tạo Controller lắng nghe sự kiện cho Huawei Banner Ad ở đáy màn hình
    _bannerController = BannerViewController(
      listener: (AdEvent event, {int? errorCode}) {
        debugPrint('Huawei Banner Ad event: ${event.name} (code: $errorCode)');
        if (!mounted) return;
        if (event == AdEvent.loaded) {
          setState(() => _isBannerLoaded = true);
        } else if (event == AdEvent.failed) {
          setState(() => _isBannerLoaded = false);
        }
      },
    );

    // 2. Tải trước (Preload) Huawei Interstitial Ad để sẵn sàng hiển thị khi đẩy nước xong
    _loadInterstitialAd();

    // 3. Lắng nghe sự kiện hoàn tất chu trình đẩy nước từ WaterEjectorProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WaterEjectorProvider>().onCycleCompleted =
          _onWaterEjectCycleCompleted;
    });
  }

  /// Khởi tạo & tải trước Huawei Interstitial Ad (Quảng cáo toàn màn hình)
  Future<void> _loadInterstitialAd() async {
    if (!HuaweiAdsConfig.isAndroidPlatform) {
      if (mounted) {
        setState(() => _isInterstitialReady = true);
      }
      return;
    }

    try {
      await _interstitialAd?.destroy();
      final InterstitialAd interstitial = InterstitialAd(
        adSlotId: HuaweiAdsConfig.interstitialAdSlotId,
        adParam: AdParam(),
        listener: (AdEvent event, {int? errorCode}) {
          debugPrint(
            'Huawei Interstitial Ad event: ${event.name} (code: $errorCode)',
          );
          if (!mounted) return;
          if (event == AdEvent.loaded) {
            setState(() => _isInterstitialReady = true);
          } else if (event == AdEvent.closed) {
            setState(() => _isInterstitialReady = false);
            _loadInterstitialAd();
            _showCleanSuccessDialog();
          } else if (event == AdEvent.failed) {
            setState(() => _isInterstitialReady = false);
          }
        },
      );

      _interstitialAd = interstitial;
      await interstitial.loadAd();
    } catch (e) {
      debugPrint('Huawei Interstitial Ad preload error: $e');
    }
  }

  /// Tự động bung Interstitial Ad ngay khi chu trình đẩy nước hoàn tất 100%
  Future<void> _onWaterEjectCycleCompleted() async {
    if (!mounted) return;

    if (HuaweiAdsConfig.isAndroidPlatform) {
      if (_isInterstitialReady && _interstitialAd != null) {
        try {
          final bool loaded = await _interstitialAd!.isLoaded() ?? false;
          if (loaded) {
            await _interstitialAd!.show();
            return;
          }
        } catch (e) {
          debugPrint('Huawei Interstitial Ad display error: $e');
        }
      }
      _loadInterstitialAd();
      if (mounted) {
        _showCleanSuccessDialog();
      }
      return;
    }

    await _showPreviewInterstitialModal();
    if (mounted) {
      _showCleanSuccessDialog();
    }
  }

  /// Hộp thoại thông báo hoàn tất đẩy nước (đa ngôn ngữ)
  void _showCleanSuccessDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1D38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            ),
          ),
          title: Row(
            children: <Widget>[
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF64FFDA),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.translate('dialog_complete_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            l10n.translate('dialog_complete_body'),
            style: const TextStyle(
              color: Color(0xFFB8CCE4),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.translate('btn_close'),
                style: const TextStyle(color: Color(0xFF90A4AE)),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF041428),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context
                    .read<WaterEjectorProvider>()
                    .toggleSpeakerTest(SpeakerTestType.beep);
              },
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              label: Text(
                l10n.translate('btn_test_now'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Màn hình mô phỏng Interstitial Ad khi chạy trên Web / Preview Mode
  Future<void> _showPreviewInterstitialModal() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (BuildContext modalContext) {
        final AppLocalizations l10n = AppLocalizations.of(modalContext)!;
        return Dialog(
          backgroundColor: const Color(0xFF0B192E),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFCE0E2D), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCE0E2D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.translate('ad_preview_badge'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(modalContext).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCE0E2D).withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    size: 48,
                    color: Color(0xFFFF5252),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.translate('ad_interstitial_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate(
                    'ad_interstitial_body',
                    <String, String>{
                      'slotId': HuaweiAdsConfig.interstitialAdSlotId,
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB0C4DE),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCE0E2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(modalContext).pop(),
                    child: Text(
                      l10n.translate('ad_close_continue'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Menu chọn nhanh 9 ngôn ngữ quốc tế (Language Selector)
  void _showLanguageSelectorDialog(WaterEjectorProvider ejector) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = AppLocalizations.of(dialogContext)!;
        return Dialog(
          backgroundColor: const Color(0xFF0E1D38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.language_rounded,
                      color: Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.translate('language_menu_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF90A4AE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: AppLocalizations.languageOptions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final LanguageOption opt =
                          AppLocalizations.languageOptions[index];
                      final bool selected =
                          ejector.locale.languageCode == opt.code;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: selected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.14)
                            : Colors.transparent,
                        leading: Text(
                          opt.flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(
                          opt.nativeName,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF00E5FF)
                                : Colors.white,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF64FFDA),
                                size: 20,
                              )
                            : Text(
                                opt.code.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF78909C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        onTap: () {
                          ejector.changeLocale(opt.locale);
                          Navigator.of(dialogContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dialog xem trực tiếp Chính sách Bảo mật & Điều khoản (Privacy Policy & Terms) chuẩn AppGallery
  void _showPrivacyPolicyDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = AppLocalizations.of(dialogContext)!;
        return Dialog(
          backgroundColor: const Color(0xFF0C1A32),
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icons/icon_114x114.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.translate('privacy_dialog_title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF90A4AE),
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.translate('privacy_updated'),
                  style: const TextStyle(
                    color: Color(0xFF80D8FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildPrivacySection(
                          l10n.translate('privacy_dev_header'),
                          l10n.translate('privacy_dev_body'),
                        ),
                        _buildPrivacySection(
                          l10n.translate('privacy_ads_header'),
                          l10n.translate('privacy_ads_body'),
                        ),
                        _buildPrivacySection(
                          l10n.translate('privacy_audio_header'),
                          l10n.translate('privacy_audio_body'),
                        ),
                        _buildPrivacySection(
                          l10n.translate('privacy_disclaimer_header'),
                          l10n.translate('privacy_disclaimer_body'),
                        ),
                        _buildPrivacySection(
                          l10n.translate('privacy_rights_header'),
                          l10n.translate('privacy_rights_body'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF80D8FF),
                        side: BorderSide(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(
                            text: HuaweiAdsConfig.developerEmail,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.translate('email_copied_toast'),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(l10n.translate('btn_copy_email')),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF041428),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        l10n.translate('btn_close'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacySection(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132546),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64FFDA),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD6E4F0),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet hướng dẫn sử dụng 4 bước đạt hiệu quả đẩy nước cao nhất
  void _showUsageTipsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1830),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        final AppLocalizations l10n = AppLocalizations.of(sheetContext)!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      color: Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.translate('tips_sheet_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTipItem('1', l10n.translate('tip_step_1')),
                _buildTipItem('2', l10n.translate('tip_step_2')),
                _buildTipItem('3', l10n.translate('tip_step_3')),
                _buildTipItem('4', l10n.translate('tip_step_4')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipItem(String step, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                color: Color(0xFFCFD8DC),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Consumer<WaterEjectorProvider>(
      builder:
          (BuildContext context, WaterEjectorProvider ejector, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFF060B19),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 16,
            title: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9.8),
                    child: Image.asset(
                      'assets/icons/icon_114x114.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.translate('app_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        l10n.translate('app_subtitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              const Color(0xFF80D8FF).withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              // Nút kích âm lượng loa nhanh lên 100%
              IconButton(
                onPressed: ejector.boostVolumeToMax,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.volume_up_rounded,
                  color: Color(0xFF64FFDA),
                  size: 20,
                ),
              ),
              // Nút chọn ngôn ngữ (Language Selector - 9 ngôn ngữ)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showLanguageSelectorDialog(ejector),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.language_rounded,
                        size: 15,
                        color: Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ejector.locale.languageCode.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _showUsageTipsSheet,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.translate('tips_tooltip'),
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFFB0BEC5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF060B19),
                  Color(0xFF0A162D),
                  Color(0xFF071122),
                ],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildTopGuidanceBanner(l10n, ejector),
                  const SizedBox(height: 10),
                  WaveVisualizer(
                    isEjecting: ejector.isEjecting,
                    isTestingSpeaker: ejector.isTestingSpeaker,
                    progress: ejector.progress,
                    frequencyHz: ejector.currentFrequencyHz,
                    formattedTime: ejector.formattedCountdown,
                    startLabel: l10n.translate('center_start'),
                    stopLabel: l10n.translate('center_stop'),
                    onTapCenterButton: ejector.toggleWaterEjector,
                  ),
                  const SizedBox(height: 8),
                  _buildProgressAndTelemetryCard(l10n, ejector),
                  const SizedBox(height: 14),
                  _buildModeAndDurationCard(l10n, ejector),
                  const SizedBox(height: 14),
                  _buildPrimaryActionButton(l10n, ejector),
                  const SizedBox(height: 16),
                  _buildSpeakerTestSection(l10n, ejector),
                  const SizedBox(height: 12),
                  _buildFooterComplianceRow(l10n),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomHuaweiBannerAd(l10n),
        );
      },
    );
  }

  Widget _buildTopGuidanceBanner(
    AppLocalizations l10n,
    WaterEjectorProvider ejector,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF102242).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.screen_rotation_alt_rounded,
            color: Color(0xFF00E5FF),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.translate('top_tip'),
              style: const TextStyle(
                color: Color(0xFFD6E4F0),
                fontSize: 12.2,
                height: 1.3,
              ),
            ),
          ),
          if (ejector.completedCyclesCount > 0) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF64FFDA).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.translate(
                  'cycles_badge',
                  <String, String>{
                    'count': ejector.completedCyclesCount.toString(),
                  },
                ),
                style: const TextStyle(
                  color: Color(0xFF64FFDA),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressAndTelemetryCard(
    AppLocalizations l10n,
    WaterEjectorProvider ejector,
  ) {
    final int percent = (ejector.progress * 100).round();
    final String statusText = ejector.activeSpeakerTest != null
        ? l10n.translate(
            'status_testing',
            <String, String>{
              'test': l10n.translate(ejector.activeSpeakerTest!.labelKey),
              'range': ejector.activeSpeakerTest!.frequencyRange,
            },
          )
        : l10n.translate(ejector.statusStageKey);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ejector.isEjecting
                      ? '${ejector.currentFrequencyHz.toStringAsFixed(1)} Hz • $percent%'
                      : ejector.selectedMode.badgeFreq,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ejector.isEjecting ? ejector.progress : 0.0,
              minHeight: 9,
              backgroundColor: const Color(0xFF192E52),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF00E5FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeAndDurationCard(
    AppLocalizations l10n,
    WaterEjectorProvider ejector,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.translate('mode_section_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB0C4DE),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: EjectMode.values.map((EjectMode mode) {
              final bool isSelected = ejector.selectedMode == mode;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode != EjectMode.values.last ? 8.0 : 0.0,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ejector.selectMode(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.16)
                            : const Color(0xFF132546),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withValues(alpha: 0.06),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            l10n.translate(mode.titleKey),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFCFD8DC),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.translate(mode.subtitleKey),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF80D8FF)
                                  : const Color(0xFF78909C),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(
                Icons.timer_outlined,
                color: Color(0xFF80D8FF),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.translate('duration_section_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB0C4DE),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildDurationChip(
                  ejector: ejector,
                  seconds: 30,
                  label: l10n.translate('duration_30s'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDurationChip(
                  ejector: ejector,
                  seconds: 60,
                  label: l10n.translate('duration_60s'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip({
    required WaterEjectorProvider ejector,
    required int seconds,
    required String label,
  }) {
    final bool selected = ejector.selectedDurationSeconds == seconds;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: ejector.isEjecting ? null : () => ejector.selectDuration(seconds),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00E5FF) : const Color(0xFF132546),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFF041428) : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    AppLocalizations l10n,
    WaterEjectorProvider ejector,
  ) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: ejector.isEjecting
              ? const Color(0xFFFF5252)
              : const Color(0xFF00E5FF),
          foregroundColor:
              ejector.isEjecting ? Colors.white : const Color(0xFF031426),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
        ),
        onPressed: ejector.toggleWaterEjector,
        icon: Icon(
          ejector.isEjecting
              ? Icons.stop_circle_rounded
              : Icons.water_drop_rounded,
          size: 23,
        ),
        label: Text(
          ejector.isEjecting
              ? l10n.translate(
                  'btn_stop_eject',
                  <String, String>{'time': ejector.formattedCountdown},
                )
              : l10n.translate('btn_start_eject'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakerTestSection(
    AppLocalizations l10n,
    WaterEjectorProvider ejector,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.speaker_group_rounded,
                color: Color(0xFF64FFDA),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.translate('test_section_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ejector.isTestingSpeaker)
                TextButton(
                  onPressed: ejector.stopAllAudio,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFFFF8A80),
                  ),
                  child: Text(l10n.translate('btn_stop_test')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: SpeakerTestType.values.map((SpeakerTestType type) {
              final bool isPlayingThis = ejector.activeSpeakerTest == type;
              final IconData iconData = switch (type) {
                SpeakerTestType.bass => Icons.speaker_rounded,
                SpeakerTestType.treble => Icons.auto_awesome_rounded,
                SpeakerTestType.beep => Icons.notifications_active_rounded,
              };

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type != SpeakerTestType.values.last ? 8.0 : 0.0,
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isPlayingThis
                          ? const Color(0xFF64FFDA).withValues(alpha: 0.18)
                          : const Color(0xFF132546),
                      side: BorderSide(
                        color: isPlayingThis
                            ? const Color(0xFF64FFDA)
                            : Colors.white.withValues(alpha: 0.10),
                        width: isPlayingThis ? 1.6 : 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => ejector.toggleSpeakerTest(type),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          isPlayingThis ? Icons.stop_rounded : iconData,
                          color: isPlayingThis
                              ? const Color(0xFF64FFDA)
                              : const Color(0xFF80D8FF),
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.translate(type.labelKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.translate(type.descriptionKey),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF90A4AE),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Hàng nút xem trực tiếp Privacy Policy & Hướng dẫn làm sạch ngay trong App
  Widget _buildFooterComplianceRow(AppLocalizations l10n) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0C4DE),
              backgroundColor: const Color(0xFF0D1B35),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _showUsageTipsSheet,
            icon: const Icon(
              Icons.tips_and_updates_outlined,
              size: 16,
              color: Color(0xFF80D8FF),
            ),
            label: Text(
              l10n.translate('usage_guide_btn'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF80D8FF),
              backgroundColor: const Color(0xFF0D1B35),
              side: BorderSide(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _showPrivacyPolicyDialog,
            icon: const Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: Color(0xFF64FFDA),
            ),
            label: Text(
              l10n.translate('privacy_policy_btn'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Widget Huawei Petal Banner Ad neo ở đáy màn hình chính
  Widget _buildBottomHuaweiBannerAd(AppLocalizations l10n) {
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
        ),
        alignment: Alignment.center,
        child: HuaweiAdsConfig.isAndroidPlatform
            ? SizedBox(
                width: 320,
                height: 50,
                child: BannerView(
                  adSlotId: HuaweiAdsConfig.bannerAdSlotId,
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
                          <String, String>{
                            'slotId': HuaweiAdsConfig.bannerAdSlotId,
                          },
                        ),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE0E6ED),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _isBannerLoaded || _isInterstitialReady
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
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
