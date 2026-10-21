import 'dart:math' as math;
import 'dart:typed_data';

/// Các chế độ rung đẩy nước khỏi màng loa (Water Ejector Modes)
enum EjectMode {
  /// Tần số chuẩn 165Hz: Cộng hưởng biên độ lớn đẩy các giọt nước lớn khỏi lưới loa
  standard165Hz(
    title: 'Chuẩn 165Hz',
    subtitle: 'Đẩy giọt nước lớn',
    badgeFreq: '165 Hz',
  ),

  /// Quét dải tần 100Hz - 200Hz: Quét liên tục qua mọi điểm cộng hưởng cơ học của loa
  frequencySweep(
    title: 'Quét 100–200Hz',
    subtitle: 'Làm sạch toàn dải',
    badgeFreq: '100–200 Hz',
  ),

  /// Xung áp suất 165Hz cường độ cao: Phá vỡ sức căng bề mặt của hạt sương nhỏ bám dính
  deepPulse(
    title: 'Xung Mạnh',
    subtitle: 'Giũ sạch hạt mịn',
    badgeFreq: '165 Hz Pulse',
  );

  final String title;
  final String subtitle;
  final String badgeFreq;

  const EjectMode({
    required this.title,
    required this.subtitle,
    required this.badgeFreq,
  });
}

/// Các bài kiểm tra âm thanh loa sau khi vệ sinh (Test Speaker Modes)
enum SpeakerTestType {
  bass(
    label: 'Test Bass',
    frequencyRange: '65–110 Hz',
    description: 'Kiểm tra rè màng trầm',
  ),
  treble(
    label: 'Test Treble',
    frequencyRange: '2.8–5.2 kHz',
    description: 'Kiểm tra nghẹt âm cao',
  ),
  beep(
    label: 'Test Beep',
    frequencyRange: '440–1320 Hz',
    description: 'Kiểm tra độ trong trẻo',
  );

  final String label;
  final String frequencyRange;
  final String description;

  const SpeakerTestType({
    required this.label,
    required this.frequencyRange,
    required this.description,
  });
}

/// Bộ tổng hợp tín hiệu số DSP tạo file âm thanh WAV (PCM 16-bit, 44.1kHz) trực tiếp trong bộ nhớ.
///
/// Ưu điểm vượt trội:
/// - Độ chính xác tần số tuyệt đối (165.00Hz & quét pha liên tục 100Hz -> 200Hz).
/// - Nối vòng lặp (loop) mượt mà tại điểm cắt không (zero-crossing), không phát tiếng nổ "bụp".
/// - Hoạt động 100% offline trên mọi thiết bị Huawei / Android / Web mà không phụ thuộc codec ngoài.
class SoundGenerator {
  SoundGenerator._();

  static const int sampleRate = 44100;
  static const double sweepCycleSeconds = 6.0;

  static final Map<EjectMode, Uint8List> _ejectCache = <EjectMode, Uint8List>{};
  static final Map<SpeakerTestType, Uint8List> _testCache =
      <SpeakerTestType, Uint8List>{};

  /// Lấy buffer WAV cho chế độ đẩy nước được chọn (có cache RAM tốc độ cao)
  static Uint8List getEjectWavBytes(EjectMode mode) {
    return _ejectCache.putIfAbsent(mode, () {
      switch (mode) {
        case EjectMode.standard165Hz:
          return _generateStandard165HzWav();
        case EjectMode.frequencySweep:
          return _generateSweep100To200HzWav();
        case EjectMode.deepPulse:
          return _generateDeepPulse165HzWav();
      }
    });
  }

  /// Lấy buffer WAV cho bài kiểm tra loa (Bass / Treble / Beep)
  static Uint8List getSpeakerTestWavBytes(SpeakerTestType type) {
    return _testCache.putIfAbsent(type, () {
      switch (type) {
        case SpeakerTestType.bass:
          return _generateBassTestWav();
        case SpeakerTestType.treble:
          return _generateTrebleTestWav();
        case SpeakerTestType.beep:
          return _generateBeepTestWav();
      }
    });
  }

  /// Tính tần số tức thời (Hz) theo thời gian chạy thực tế để hiển thị đồng bộ lên màn hình
  static double calculateLiveFrequency(EjectMode mode, double elapsedSeconds) {
    switch (mode) {
      case EjectMode.standard165Hz:
      case EjectMode.deepPulse:
        return 165.0;
      case EjectMode.frequencySweep:
        final double cyclePos =
            (elapsedSeconds % sweepCycleSeconds) / sweepCycleSeconds;
        final double triangle =
            cyclePos < 0.5 ? cyclePos * 2.0 : (1.0 - cyclePos) * 2.0;
        return 100.0 + (100.0 * triangle);
    }
  }

  /// 1. Tạo sóng chuẩn 165Hz kết hợp hài bậc 3 nhẹ giúp tăng biên độ dao động màng loa
  static Uint8List _generateStandard165HzWav() {
    const double durationSec = 4.0; // 4.0s * 165Hz = 660 chu kỳ nguyên chẵn
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List samples = Float64List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      // Điều biến áp suất nhẹ 1.5Hz giúp đẩy giọt nước hiệu quả hơn sóng tĩnh đơn thuần
      final double pressureEnvelope =
          0.86 + 0.14 * math.sin(2.0 * math.pi * 1.5 * t);
      final double fundamental = math.sin(2.0 * math.pi * 165.0 * t);
      final double harmonic = 0.14 * math.sin(2.0 * math.pi * 495.0 * t);
      samples[i] = _softClip((fundamental + harmonic) * pressureEnvelope * 0.95);
    }

    return _encodePcm16MonoWav(samples, fadeMs: 12);
  }

  /// 2. Tạo sóng quét dải tần liên tục 100Hz <-> 200Hz (Phase-Continuous Chirp)
  static Uint8List _generateSweep100To200HzWav() {
    final int totalSamples = (sampleRate * sweepCycleSeconds).round();
    final Float64List samples = Float64List(totalSamples);
    double phase = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final double cyclePos = i / totalSamples;
      final double triangle =
          cyclePos < 0.5 ? cyclePos * 2.0 : (1.0 - cyclePos) * 2.0;
      final double freq = 100.0 + 100.0 * triangle;
      phase += (2.0 * math.pi * freq) / sampleRate;
      if (phase > 2.0 * math.pi * 1024) {
        phase -= 2.0 * math.pi * 1024;
      }
      final double subHarmonic = 0.12 * math.sin(phase * 2.0);
      samples[i] = _softClip((math.sin(phase) + subHarmonic) * 0.94);
    }

    return _encodePcm16MonoWav(samples, fadeMs: 15);
  }

  /// 3. Tạo xung áp suất 165Hz (4 nhịp xung mạnh mỗi giây) phá sức căng bề mặt nước
  static Uint8List _generateDeepPulse165HzWav() {
    const double durationSec = 4.0;
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List samples = Float64List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final double burstPos = (t * 4.0) % 1.0; // 4 xung / giây (250ms/chu kỳ)
      double gate = 0.0;
      if (burstPos < 0.72) {
        // Sườn lên/xuống mượt tránh tiếng lách tách nhưng giữ lực đẩy cơ học mạnh
        final double normalized = burstPos / 0.72;
        gate = math.sin(math.pi * normalized).clamp(0.0, 1.0);
        gate = math.pow(gate, 0.35).toDouble();
      }
      final double wave = math.sin(2.0 * math.pi * 165.0 * t) +
          0.18 * math.sin(2.0 * math.pi * 330.0 * t);
      samples[i] = _softClip(wave * gate * 0.96);
    }

    return _encodePcm16MonoWav(samples, fadeMs: 10);
  }

  /// 4. Bài kiểm tra Bass (65Hz -> 110Hz): Phát hiện nhanh hiện tượng loa trầm còn rè hoặc ù
  static Uint8List _generateBassTestWav() {
    const double durationSec = 3.6;
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List samples = Float64List(totalSamples);
    final List<double> bassNotes = <double>[65.41, 82.41, 98.00, 110.00];
    final int noteSamples = totalSamples ~/ bassNotes.length;
    double phase = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final int idx = (i ~/ noteSamples).clamp(0, bassNotes.length - 1);
      final double localPos = (i % noteSamples) / noteSamples;
      final double env = localPos < 0.88
          ? math.sin(math.pi * (localPos / 0.88)).clamp(0.0, 1.0)
          : 0.0;
      final double freq = bassNotes[idx];
      phase += (2.0 * math.pi * freq) / sampleRate;
      final double warmBass =
          0.85 * math.sin(phase) + 0.15 * math.sin(phase * 2.0);
      samples[i] = _softClip(warmBass * math.pow(env, 0.45).toDouble() * 0.92);
    }

    return _encodePcm16MonoWav(samples, fadeMs: 15);
  }

  /// 5. Bài kiểm tra Treble (2.8kHz -> 5.2kHz): Kiểm tra độ sáng & độ thoáng của màng lưới loa
  static Uint8List _generateTrebleTestWav() {
    const double durationSec = 3.6;
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List samples = Float64List(totalSamples);
    final List<double> trebleNotes = <double>[2793.83, 3520.00, 4186.01, 5274.04];
    final int noteSamples = totalSamples ~/ trebleNotes.length;

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final int idx = (i ~/ noteSamples).clamp(0, trebleNotes.length - 1);
      final double localPos = (i % noteSamples) / noteSamples;
      final double env = math.exp(-3.2 * localPos) *
          (localPos < 0.05 ? localPos / 0.05 : 1.0);
      final double freq = trebleNotes[idx];
      samples[i] =
          (math.sin(2.0 * math.pi * freq * t) * env * 0.80).clamp(-1.0, 1.0);
    }

    return _encodePcm16MonoWav(samples, fadeMs: 10);
  }

  /// 6. Bài kiểm tra Tiếng Beep chuẩn (440Hz - 659Hz - 880Hz - 1320Hz)
  static Uint8List _generateBeepTestWav() {
    const double durationSec = 3.2;
    final int totalSamples = (sampleRate * durationSec).round();
    final Float64List samples = Float64List(totalSamples);
    final List<double> beepFreqs = <double>[440.0, 659.25, 880.0, 1318.51];
    final int slotSamples = totalSamples ~/ beepFreqs.length;

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final int idx = (i ~/ slotSamples).clamp(0, beepFreqs.length - 1);
      final double localPos = (i % slotSamples) / slotSamples;
      double env = 0.0;
      if (localPos < 0.72) {
        final double n = localPos / 0.72;
        if (n < 0.08) {
          env = n / 0.08;
        } else if (n > 0.85) {
          env = (1.0 - n) / 0.15;
        } else {
          env = 1.0;
        }
      }
      samples[i] =
          (math.sin(2.0 * math.pi * beepFreqs[idx] * t) * env * 0.82)
              .clamp(-1.0, 1.0);
    }

    return _encodePcm16MonoWav(samples, fadeMs: 10);
  }

  /// Nén biên độ mềm (Soft Clipping) giữ năng lượng sóng cao mà không gây vỡ tiếng loa
  static double _softClip(double x) {
    if (x > 1.0) return 1.0;
    if (x < -1.0) return -1.0;
    return x - (x * x * x) / 6.0;
  }

  /// Đóng gói mảng mẫu thực [-1.0, 1.0] thành định dạng chuẩn RIFF WAVE 16-bit Mono
  static Uint8List _encodePcm16MonoWav(
    Float64List samples, {
    int fadeMs = 10,
  }) {
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int blockAlign = numChannels * (bitsPerSample ~/ 8);

    final int numSamples = samples.length;
    final int dataByteLength = numSamples * 2;
    final int totalFileSize = 44 + dataByteLength;
    final int fadeSamples =
        ((sampleRate * fadeMs) ~/ 1000).clamp(1, numSamples ~/ 4);

    final ByteData buffer = ByteData(totalFileSize);

    // RIFF chunk descriptor
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, 36 + dataByteLength, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // 'fmt ' sub-chunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // PCM header size
    buffer.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);

    // 'data' sub-chunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataByteLength, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      double env = 1.0;
      if (i < fadeSamples) {
        env = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        env = (numSamples - i) / fadeSamples;
      }
      final int pcmSample =
          (samples[i] * env * 32760.0).round().clamp(-32767, 32767);
      buffer.setInt16(44 + i * 2, pcmSample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
