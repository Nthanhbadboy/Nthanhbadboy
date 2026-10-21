import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_ejector/main.dart';
import 'package:water_ejector/utils/sound_generator.dart';

void main() {
  group('SoundGenerator DSP WAV Synthesis Tests', () {
    test('Tạo sóng chuẩn 165Hz hợp lệ với header RIFF WAVE PCM 16-bit', () {
      final Uint8List bytes =
          SoundGenerator.getEjectWavBytes(EjectMode.standard165Hz);
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(bytes.sublist(36, 40)), equals('data'));
    });

    test('Tính đúng dải tần quét 100Hz -> 200Hz -> 100Hz', () {
      expect(
        SoundGenerator.calculateLiveFrequency(EjectMode.frequencySweep, 0.0),
        equals(100.0),
      );
      expect(
        SoundGenerator.calculateLiveFrequency(EjectMode.frequencySweep, 3.0),
        equals(200.0),
      );
      expect(
        SoundGenerator.calculateLiveFrequency(EjectMode.standard165Hz, 2.5),
        equals(165.0),
      );
    });

    test('Tạo đầy đủ 3 bài Test Speaker (Bass, Treble, Beep)', () {
      for (final SpeakerTestType type in SpeakerTestType.values) {
        final Uint8List wav = SoundGenerator.getSpeakerTestWavBytes(type);
        expect(wav.length, greaterThan(1000));
      }
    });
  });

  testWidgets(
      'Hiển thị đầy đủ HomeScreen trên Android, đếm ngược 30s & hoàn tất chu trình',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const WaterEjectorApp(enablePlatformAudio: false),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Tiêu đề & đồng hồ đếm ngược mặc định 30 giây
    expect(find.text('Water Ejector'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('Chuẩn 165Hz'), findsOneWidget);
    expect(find.text('Quét 100–200Hz'), findsOneWidget);

    // Các nút Test Speaker
    expect(find.text('Test Bass'), findsOneWidget);
    expect(find.text('Test Treble'), findsOneWidget);
    expect(find.text('Test Beep'), findsOneWidget);

    // Chuyển thời lượng sang 1 Phút (01:00) rồi quay về 30 Giây (00:30)
    await tester.tap(find.text('1 Phút'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('01:00'), findsOneWidget);

    await tester.tap(find.text('30 Giây'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('00:30'), findsOneWidget);

    // Kích hoạt đẩy nước 30 giây và kiểm tra đếm ngược + hoàn tất chu trình
    await tester.tap(find.text('KÍCH HOẠT ĐẨY NƯỚC NGAY'));
    await tester.pump(const Duration(seconds: 15));
    expect(find.text('00:15'), findsOneWidget);

    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hoàn tất đẩy nước!'), findsOneWidget);
  });

  testWidgets(
      'Tự động bung Huawei Interstitial Ad ở chế độ Preview khi xong chu trình',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    try {
      await tester.pumpWidget(
        const WaterEjectorApp(enablePlatformAudio: false),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('KÍCH HOẠT ĐẨY NƯỚC NGAY'));
      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Huawei Interstitial Ad'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
