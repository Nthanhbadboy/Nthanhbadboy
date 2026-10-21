import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../utils/huawei_ads_config.dart';
import '../utils/sound_generator.dart';

/// Provider quản lý chu trình đẩy nước, kiểm tra loa, chấp thuận quyền riêng tư & đổi 9 ngôn ngữ
class WaterEjectorProvider extends ChangeNotifier {
  WaterEjectorProvider({
    bool enablePlatformAudio = true,
    Locale initialLocale = const Locale('en'),
    bool initialPrivacyAccepted = false,
  })  : _enablePlatformAudio = enablePlatformAudio,
        _locale = initialLocale,
        _isPrivacyAccepted = initialPrivacyAccepted,
        _isAdsSdkReady = initialPrivacyAccepted {
    if (_enablePlatformAudio) {
      _initAudioPlayer();
      unawaited(refreshMediaVolume());
    }
    if (_isPrivacyAccepted) {
      unawaited(_activateAdsSdk());
    }
  }

  static const MethodChannel _nativeAudioChannel =
      MethodChannel('NGUYENMINHTHANH.WaterEjector/audio_control');

  final bool _enablePlatformAudio;
  AudioPlayer? _audioPlayer;
  StreamSubscription<void>? _playerCompleteSub;
  Timer? _countdownTimer;

  // Ngôn ngữ hiện hành (Mặc định: Tiếng Anh 'en')
  Locale _locale;

  // Trạng thái đồng ý Chính sách Bảo mật lần đầu (is_privacy_accepted)
  bool _isPrivacyAccepted;
  bool _isAdsSdkReady;

  // Không tự động chạy bất kỳ chu trình âm thanh / rung nào khi mở ứng dụng
  EjectMode _selectedMode = EjectMode.standard165Hz;
  int _selectedDurationSeconds = 30;
  bool _isEjecting = false;
  int _elapsedMilliseconds = 0;
  double _currentFrequencyHz = 165.0;
  int _completedCyclesCount = 0;
  SpeakerTestType? _activeSpeakerTest;
  double _mediaVolumePercent = 1.0;

  /// Callback được kích hoạt tự động mỗi khi hoàn tất trọn vẹn một chu trình đẩy nước
  VoidCallback? onCycleCompleted;

  // --- Getters ---
  Locale get locale => _locale;
  bool get isPrivacyAccepted => _isPrivacyAccepted;
  bool get isAdsSdkReady => _isAdsSdkReady;
  EjectMode get selectedMode => _selectedMode;
  int get selectedDurationSeconds => _selectedDurationSeconds;
  bool get isEjecting => _isEjecting;
  SpeakerTestType? get activeSpeakerTest => _activeSpeakerTest;
  bool get isTestingSpeaker => _activeSpeakerTest != null;
  double get currentFrequencyHz => _currentFrequencyHz;
  int get completedCyclesCount => _completedCyclesCount;
  double get mediaVolumePercent => _mediaVolumePercent;

  Future<void> _activateAdsSdk() async {
    await HuaweiAdsConfig.ensureSdkInitialized();
    if (!_isAdsSdkReady) {
      _isAdsSdkReady = true;
      notifyListeners();
    }
  }

  /// Lưu trạng thái đồng ý Chính sách Bảo mật (is_privacy_accepted = true) và mở khóa HMS Petal Ads
  Future<void> acceptPrivacyPolicy() async {
    if (_isPrivacyAccepted && _isAdsSdkReady) return;
    _isPrivacyAccepted = true;
    _isAdsSdkReady = true;
    HapticFeedback.selectionClick();
    notifyListeners();

    unawaited(_persistPrivacyAcceptance());
    await HuaweiAdsConfig.ensureSdkInitialized();
  }

  Future<void> _persistPrivacyAcceptance() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(HuaweiAdsConfig.privacyAcceptedPrefsKey, true);
    } catch (_) {}
  }

  /// Đổi ngôn ngữ giao diện linh hoạt trong 9 ngôn ngữ quốc tế được hỗ trợ & lưu vào SharedPreferences
  void changeLocale(Locale newLocale) {
    final bool supported = AppLocalizations.supportedLocales.any(
      (Locale item) => item.languageCode == newLocale.languageCode,
    );
    final Locale resolved =
        supported ? Locale(newLocale.languageCode) : const Locale('en');
    if (_locale.languageCode == resolved.languageCode) return;

    _locale = resolved;
    HapticFeedback.selectionClick();
    notifyListeners();
    unawaited(_persistLocale(resolved.languageCode));
  }

  Future<void> _persistLocale(String code) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(HuaweiAdsConfig.selectedLocalePrefsKey, code);
    } catch (_) {}
  }

  int get totalDurationMilliseconds => _selectedDurationSeconds * 1000;

  int get remainingMilliseconds =>
      (totalDurationMilliseconds - _elapsedMilliseconds)
          .clamp(0, totalDurationMilliseconds);

  int get remainingSeconds => (remainingMilliseconds / 1000).ceil();

  /// Tiến độ từ 0.0 -> 1.0 dùng cho Progress Bar
  double get progress {
    if (!_isEjecting || totalDurationMilliseconds == 0) return 0.0;
    return (_elapsedMilliseconds / totalDurationMilliseconds).clamp(0.0, 1.0);
  }

  /// Định dạng đồng hồ đếm ngược MM:SS (ví dụ: 00:30, 01:00)
  String get formattedCountdown {
    final int secs = _isEjecting ? remainingSeconds : _selectedDurationSeconds;
    final int minutes = secs ~/ 60;
    final int remSecs = secs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}';
  }

  /// Khóa trạng thái đa ngôn ngữ theo giai đoạn đẩy nước
  String get statusStageKey {
    if (!_isEjecting) return 'status_ready';
    if (progress < 0.35) {
      return 'status_stage_1';
    } else if (progress < 0.75) {
      return 'status_stage_2';
    } else {
      return 'status_stage_3';
    }
  }

  void _initAudioPlayer() {
    try {
      _audioPlayer = AudioPlayer();
      _playerCompleteSub = _audioPlayer!.onPlayerComplete.listen((_) {
        if (_activeSpeakerTest != null) {
          _activeSpeakerTest = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('AudioPlayer initialization warning: $e');
    }
  }

  /// Đọc mức âm lượng loa hiện tại của thiết bị Android
  Future<void> refreshMediaVolume() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final double? vol = await _nativeAudioChannel
          .invokeMethod<double>('getMediaVolumePercent');
      if (vol != null) {
        _mediaVolumePercent = vol.clamp(0.0, 1.0);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Đặt nhanh âm lượng loa lên 100% để đạt lực đẩy nước tối đa
  Future<void> boostVolumeToMax() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeAudioChannel.invokeMethod<double>('setMaxMediaVolume');
      } catch (_) {}
    }
    _mediaVolumePercent = 1.0;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  Future<void> _setKeepScreenOn(bool keepOn) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeAudioChannel.invokeMethod<bool>(
        'setKeepScreenOn',
        <String, dynamic>{'keepOn': keepOn},
      );
    } catch (_) {}
  }

  /// Chọn chế độ sóng âm (165Hz Standard / 100-200Hz Sweep / Turbo Pulse)
  Future<void> selectMode(EjectMode mode) async {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    _currentFrequencyHz =
        SoundGenerator.calculateLiveFrequency(_selectedMode, 0);
    HapticFeedback.selectionClick();

    if (_isEjecting && _enablePlatformAudio && _audioPlayer != null) {
      try {
        final Uint8List wavBytes = SoundGenerator.getEjectWavBytes(mode);
        await _audioPlayer!.stop();
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      } catch (e) {
        debugPrint('Error switching audio mode: $e');
      }
    }
    notifyListeners();
  }

  /// Chọn thời lượng chu trình (30 giây hoặc 60 giây)
  void selectDuration(int seconds) {
    if (_isEjecting || _selectedDurationSeconds == seconds) return;
    _selectedDurationSeconds = seconds;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Bật / Tắt chu trình đẩy nước Water Ejector (Chỉ chạy khi người dùng chủ động bấm)
  Future<void> toggleWaterEjector() async {
    if (_isEjecting) {
      await stopAllAudio();
    } else {
      await startWaterEjector();
    }
  }

  /// Bắt đầu chu trình phát sóng âm đẩy nước + đếm ngược
  Future<void> startWaterEjector() async {
    await stopAllAudio();

    _isEjecting = true;
    _activeSpeakerTest = null;
    _elapsedMilliseconds = 0;
    _currentFrequencyHz =
        SoundGenerator.calculateLiveFrequency(_selectedMode, 0);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _elapsedMilliseconds += 100;
      final double elapsedSec = _elapsedMilliseconds / 1000.0;
      _currentFrequencyHz =
          SoundGenerator.calculateLiveFrequency(_selectedMode, elapsedSec);

      if (_elapsedMilliseconds % 5000 == 0) {
        HapticFeedback.lightImpact();
      }

      if (_elapsedMilliseconds >= totalDurationMilliseconds) {
        timer.cancel();
        _completeWaterEjectCycle();
      } else {
        notifyListeners();
      }
    });

    notifyListeners();

    HapticFeedback.heavyImpact();
    unawaited(refreshMediaVolume());
    unawaited(_setKeepScreenOn(true));

    if (_enablePlatformAudio && _audioPlayer != null) {
      try {
        final Uint8List wavBytes =
            SoundGenerator.getEjectWavBytes(_selectedMode);
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      } catch (e) {
        debugPrint('Unable to play water ejection wave: $e');
      }
    }
  }

  /// Xử lý khi hoàn tất 100% chu trình đẩy nước -> dừng loa & gọi callback bung Interstitial Ad
  Future<void> _completeWaterEjectCycle() async {
    _isEjecting = false;
    _elapsedMilliseconds = 0;
    _currentFrequencyHz = 165.0;
    _completedCyclesCount += 1;

    if (_enablePlatformAudio && _audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
      } catch (_) {}
    }
    unawaited(_setKeepScreenOn(false));
    HapticFeedback.mediumImpact();
    notifyListeners();

    onCycleCompleted?.call();
  }

  /// Dừng ngay mọi hoạt động phát âm thanh (Water Ejector hoặc Test Speaker)
  Future<void> stopAllAudio() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    final bool wasRunning = _isEjecting || _activeSpeakerTest != null;
    _isEjecting = false;
    _activeSpeakerTest = null;
    _elapsedMilliseconds = 0;
    _currentFrequencyHz = 165.0;

    if (_enablePlatformAudio && _audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
      } catch (_) {}
    }
    unawaited(_setKeepScreenOn(false));

    if (wasRunning) {
      HapticFeedback.selectionClick();
      notifyListeners();
    }
  }

  /// Phát hoặc dừng bài kiểm tra loa (Bass, Treble, hoặc Beep)
  Future<void> toggleSpeakerTest(SpeakerTestType testType) async {
    if (_activeSpeakerTest == testType) {
      await stopAllAudio();
      return;
    }

    await stopAllAudio();
    _activeSpeakerTest = testType;
    HapticFeedback.selectionClick();
    notifyListeners();

    if (_enablePlatformAudio && _audioPlayer != null) {
      try {
        final Uint8List wavBytes =
            SoundGenerator.getSpeakerTestWavBytes(testType);
        await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      } catch (e) {
        debugPrint('Unable to play speaker test tone: $e');
        _activeSpeakerTest = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playerCompleteSub?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
