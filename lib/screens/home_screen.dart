import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:huawei_ads/huawei_ads.dart';
import 'package:provider/provider.dart';

import '../providers/water_ejector_provider.dart';
import '../utils/sound_generator.dart';
import '../widgets/wave_visualizer.dart';

/// Cấu hình Ad Slot ID cho Huawei Petal Ads (HMS Ads Kit).
///
/// LƯU Ý KHI PHÁT HÀNH LÊN HUAWEI APPGALLERY:
/// - Các ID dưới đây là Test Ad Slot ID chính thức từ Huawei Developer Documentation
///   đảm bảo luôn hiển thị quảng cáo mẫu an toàn trong quá trình phát triển & kiểm duyệt.
/// - Trước khi build bản Production chính thức lên AppGallery Connect, hãy thay bằng
///   Slot ID thật được cấp trong Huawei Petal Publisher Center.
class HuaweiAdsConfig {
  HuaweiAdsConfig._();

  /// Banner Ad Slot ID (Kích thước 320x50 đặt cố định ở đáy màn hình chính)
  static const String bannerAdSlotId = 'testw6vs28auh3';

  /// Interstitial Ad Slot ID (Quảng cáo toàn màn hình bung ra khi đẩy nước hoàn tất)
  static const String interstitialAdSlotId = 'testb4znbuh3n2';

  /// Kiểm tra nền tảng Android thực tế để gọi Native PlatformView / MethodChannel của HMS
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

    // 2. Tải trước (Preload) Huawei Interstitial Ad để sẵn sàng hiển thị ngay khi đẩy nước xong
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
      // Ở môi trường Web / Preview, đánh dấu chế độ mô phỏng quảng cáo sẵn sàng
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
            // Tự động nạp quảng cáo mới cho lần đẩy nước kế tiếp và mở hộp thoại hoàn tất
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
      debugPrint('Không thể tải trước Huawei Interstitial Ad: $e');
    }
  }

  /// Tự động bung Interstitial Ad ngay khi chu trình đẩy nước (Water Ejector) hoàn tất 100%
  Future<void> _onWaterEjectCycleCompleted() async {
    if (!mounted) return;

    if (HuaweiAdsConfig.isAndroidPlatform && _interstitialAd != null) {
      try {
        final bool loaded = await _interstitialAd!.isLoaded() ?? false;
        if (loaded) {
          await _interstitialAd!.show();
          return; // Hộp thoại kết quả sẽ hiện ngay sau khi người dùng đóng Interstitial Ad
        }
      } catch (e) {
        debugPrint('Lỗi khi hiển thị Huawei Interstitial Ad: $e');
      }
      _loadInterstitialAd();
      if (mounted) {
        _showCleanSuccessDialog();
      }
      return;
    }

    // Trên Web / Preview: Hiển thị màn hình mô phỏng Huawei Petal Interstitial Ad trực quan
    await _showPreviewInterstitialModal();
    if (mounted) {
      _showCleanSuccessDialog();
    }
  }

  /// Hộp thoại thông báo hoàn tất đẩy nước & gợi ý kiểm tra lại loa ngay
  void _showCleanSuccessDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1D38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            ),
          ),
          title: const Row(
            children: <Widget>[
              Icon(
                Icons.verified_rounded,
                color: Color(0xFF64FFDA),
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hoàn tất đẩy nước!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Chu trình rung màng loa đã hoàn thành 100%. Hãy lau khô nhẹ bề mặt lưới loa và bấm "Test Beep" hoặc "Test Bass" để kiểm tra độ trong của âm thanh.',
            style: TextStyle(
              color: Color(0xFFB8CCE4),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Color(0xFF90A4AE)),
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
              label: const Text(
                'Test Loa Ngay',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Màn hình mô phỏng Interstitial Ad khi chạy trên trình duyệt Web (Preview Mode)
  Future<void> _showPreviewInterstitialModal() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (BuildContext modalContext) {
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCE0E2D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AD • HUAWEI PETAL ADS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(modalContext).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Đóng quảng cáo',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCE0E2D).withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    size: 52,
                    color: Color(0xFFFF5252),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Huawei Interstitial Ad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Slot ID: ${HuaweiAdsConfig.interstitialAdSlotId}\nQuảng cáo toàn màn hình tự động hiển thị sau khi hoàn tất chu trình đẩy nước trên thiết bị HMS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                    child: const Text(
                      'Đóng & Xem Kết Quả Làm Sạch',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  /// Hộp thoại hướng dẫn đặt máy đúng tư thế vật lý để đẩy nước đạt hiệu quả 100%
  void _showUsageTipsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1830),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.tips_and_updates_rounded, color: Color(0xFF00E5FF)),
                  SizedBox(width: 10),
                  Text(
                    '4 Bước Đẩy Nước Sạch Tối Đa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTipItem(
                '1',
                'Ngắt kết nối tai nghe Bluetooth / có dây để âm thanh phát trực tiếp ra loa ngoài.',
              ),
              _buildTipItem(
                '2',
                'Tăng âm lượng Media lên mức tối đa (100%) để màng loa tạo biên độ rung mạnh nhất.',
              ),
              _buildTipItem(
                '3',
                'Đặt úp màn hình điện thoại xuống bàn phẳng hoặc dốc hướng khe loa xuống dưới theo chiều trọng lực.',
              ),
              _buildTipItem(
                '4',
                'Chạy "Chuẩn 165Hz" trước, sau đó chạy thêm "Quét 100–200Hz" nếu loa vẫn còn hơi rè.',
              ),
            ],
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
    return Consumer<WaterEjectorProvider>(
      builder:
          (BuildContext context, WaterEjectorProvider ejector, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFF060B19),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 18,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Water Ejector',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Speaker Cleaner • 165Hz Acoustic DSP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF80D8FF).withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              // Nút kích âm lượng loa lên 100% chỉ với 1 chạm
              TextButton.icon(
                onPressed: ejector.boostVolumeToMax,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64FFDA),
                  backgroundColor:
                      const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 17),
                label: Text(
                  '${(ejector.mediaVolumePercent * 100).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: _showUsageTipsSheet,
                tooltip: 'Hướng dẫn sử dụng',
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFFB0BEC5),
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
                  // Banner nhắc nhở đặt úp điện thoại & trạng thái HMS Ads
                  _buildTopGuidanceBanner(ejector),
                  const SizedBox(height: 10),

                  // Cụm trực quan hóa sóng âm 165Hz & màng loa trung tâm
                  WaveVisualizer(
                    isEjecting: ejector.isEjecting,
                    isTestingSpeaker: ejector.isTestingSpeaker,
                    progress: ejector.progress,
                    frequencyHz: ejector.currentFrequencyHz,
                    formattedTime: ejector.formattedCountdown,
                    onTapCenterButton: ejector.toggleWaterEjector,
                  ),

                  const SizedBox(height: 8),

                  // Thanh tiến trình (Progress Bar) + thông tin tần số thời gian thực
                  _buildProgressAndTelemetryCard(ejector),
                  const SizedBox(height: 14),

                  // Chọn chế độ tần số (165Hz Chuẩn / Quét 100-200Hz / Xung Mạnh) & Thời gian (30s / 1 phút)
                  _buildModeAndDurationCard(ejector),
                  const SizedBox(height: 14),

                  // Nút hành động chính (Bắt đầu / Dừng chu trình đẩy nước)
                  _buildPrimaryActionButton(ejector),
                  const SizedBox(height: 16),

                  // Khu vực Test Speaker (Bass / Treble / Beep) kiểm tra rè loa
                  _buildSpeakerTestSection(ejector),
                ],
              ),
            ),
          ),

          // Đáy màn hình chính: Tích hợp Huawei Petal Banner Ad cố định gọn gàng
          bottomNavigationBar: _buildBottomHuaweiBannerAd(),
        );
      },
    );
  }

  Widget _buildTopGuidanceBanner(WaterEjectorProvider ejector) {
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
          const Expanded(
            child: Text(
              'Mẹo: Bật âm lượng 100% và đặt úp khe loa hướng xuống dưới khi chạy.',
              style: TextStyle(
                color: Color(0xFFD6E4F0),
                fontSize: 12.2,
                height: 1.3,
              ),
            ),
          ),
          if (ejector.completedCyclesCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF64FFDA).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Đã chạy ${ejector.completedCyclesCount}x',
                style: const TextStyle(
                  color: Color(0xFF64FFDA),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressAndTelemetryCard(WaterEjectorProvider ejector) {
    final int percent = (ejector.progress * 100).round();
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
                  ejector.statusHeadline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.2,
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

  Widget _buildModeAndDurationCard(WaterEjectorProvider ejector) {
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
          const Text(
            'Chế độ sóng âm đẩy nước',
            style: TextStyle(
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
                        horizontal: 8,
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
                            mode.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFCFD8DC),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mode.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF80D8FF)
                                  : const Color(0xFF78909C),
                              fontSize: 10.5,
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
          const Row(
            children: <Widget>[
              Icon(
                Icons.timer_outlined,
                color: Color(0xFF80D8FF),
                size: 18,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Thời gian đếm ngược chu trình',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
                  label: '30 Giây',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDurationChip(
                  ejector: ejector,
                  seconds: 60,
                  label: '1 Phút',
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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

  Widget _buildPrimaryActionButton(WaterEjectorProvider ejector) {
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
          size: 24,
        ),
        label: Text(
          ejector.isEjecting
              ? 'DỪNG ĐẨY NƯỚC (${ejector.formattedCountdown})'
              : 'KÍCH HOẠT ĐẨY NƯỚC NGAY',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakerTestSection(WaterEjectorProvider ejector) {
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
              const Expanded(
                child: Text(
                  'Test Speaker • Kiểm tra loa còn rè không',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
                  child: const Text('Dừng test'),
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
                          type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type.description,
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

  /// Widget Huawei Petal Banner Ad neo ở đáy màn hình chính
  Widget _buildBottomHuaweiBannerAd() {
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
                    const Expanded(
                      child: Text(
                        'Huawei Petal Banner Ad • ${HuaweiAdsConfig.bannerAdSlotId}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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
