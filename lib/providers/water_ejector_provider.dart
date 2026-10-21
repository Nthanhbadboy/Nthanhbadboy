import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/sound_generator.dart';

/// Provider quản lý toàn bộ trạng thái & vòng đời âm thanh cho Water Ejector & Test Speaker
class WaterEjectorProvider extends ChangeNotifier {
  WaterEjectorProvider({bool enablePlatformAudio = true})
      : _enablePlatformAudio = enablePlatformAudio {
    if (_enablePlatformAudio) {
      _initAudioPlayer();
      refreshMediaVolume();
    }
  }

  static const MethodChannel _nativeAudioChannel =
      MethodChannel('NGUYENMINHTHANH.WaterEjector/audio_control');

  final bool _enablePlatformAudio;
  AudioPlayer? _audioPlayer;
  StreamSubscription<void>? _playerCompleteSub;
  Timer? _countdownTimer;

  EjectMode _selectedMode = EjectMode.standard165Hz;
  int _selectedDurationSeconds = 30; // Mặc định 30 giây (hỗ trợ 30s hoặc 60s)
  bool _isEjecting = false;
  int _elapsedMilliseconds = 0;
  double _currentFrequencyHz = 165.0;
  int _completedCyclesCount = 0;
  SpeakerTestType? _activeSpeakerTest;
  double _mediaVolumePercent = 1.0;

  /// Callback được kích hoạt tự động mỗi khi hoàn tất trọn vẹn một chu trình đẩy nước
  VoidCallback? onCycleCompleted;

  // --- Getters ---
  EjectMode get selectedMode => _selectedMode;
  int get selectedDurationSeconds => _selectedDurationSeconds;
  bool get isEjecting => _isEjecting;
  SpeakerTestType? get activeSpeakerTest => _activeSpeakerTest;
  bool get isTestingSpeaker => _activeSpeakerTest != null;
  double get currentFrequencyHz => _currentFrequencyHz;
  int get completedCyclesCount => _completedCyclesCount;
  double get mediaVolumePercent => _mediaVolumePercent;

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

  /// Thông điệp hướng dẫn trực quan theo giai đoạn đẩy nước
  String get statusHeadline {
    if (_activeSpeakerTest != null) {
      return 'Đang phát ${_activeSpeakerTest!.label} (${_activeSpeakerTest!.frequencyRange})';
    }
    if (!_isEjecting) {
      return 'Sẵn sàng làm sạch màng loa';
    }
    if (progress < 0.35) {
      return 'Giai đoạn 1/3: Tạo dao động tách nước khỏi lưới loa...';
    } else if (progress < 0.75) {
      return 'Giai đoạn 2/3: Đẩy giọt nước ra ngoài bằng áp suất sóng âm...';
    } else {
      return 'Giai đoạn 3/3: Làm khô vi màng loa & ổn định âm thanh...';
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
      debugPrint('Khởi tạo AudioPlayer gặp ngoại lệ: $e');
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
    } catch (_) {
      // Bỏ qua an toàn trên thiết bị giả lập hoặc môi trường test
    }
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

  /// Chọn chế độ sóng âm (165Hz Chuẩn / Quét 100-200Hz / Xung Mạnh)
  Future<void> selectMode(EjectMode mode) async {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    _currentFrequencyHz =
        SoundGenerator.calculateLiveFrequency(_selectedMode, 0);
    HapticFeedback.selectionClick();

    // Nếu đang chạy đẩy nước, chuyển mượt ngay sang dạng sóng mới mà không gián đoạn bộ đếm
    if (_isEjecting && _enablePlatformAudio && _audioPlayer != null) {
      try {
        final Uint8List wavBytes = SoundGenerator.getEjectWavBytes(mode);
        await _audioPlayer!.stop();
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      } catch (e) {
        debugPrint('Chuyển chế độ âm thanh lỗi: $e');
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

  /// Bật / Tắt chu trình đẩy nước Water Ejector
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
    notifyListeners();

    HapticFeedback.heavyImpact();
    await refreshMediaVolume();
    await _setKeepScreenOn(true);

    if (_enablePlatformAudio && _audioPlayer != null) {
      try {
        final Uint8List wavBytes =
            SoundGenerator.getEjectWavBytes(_selectedMode);
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      } catch (e) {
        debugPrint('Không thể phát sóng âm đẩy nước: $e');
      }
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _elapsedMilliseconds += 100;
      final double elapsedSec = _elapsedMilliseconds / 1000.0;
      _currentFrequencyHz =
          SoundGenerator.calculateLiveFrequency(_selectedMode, elapsedSec);

      // Rung phản hồi nhẹ mỗi 5 giây trên thiết bị thực để tăng cảm nhận cơ học
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
    await _setKeepScreenOn(false);
    HapticFeedback.mediumImpact();
    notifyListeners();

    // Kích hoạt sự kiện hoàn tất để HomeScreen tự động hiển thị Huawei Interstitial Ad
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
    await _setKeepScreenOn(false);

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
        debugPrint('Không thể phát âm thanh kiểm tra loa: $e');
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
