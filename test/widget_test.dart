import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_ejector/l10n/app_localizations.dart';
import 'package:water_ejector/main.dart';
import 'package:water_ejector/providers/water_ejector_provider.dart';
import 'package:water_ejector/utils/huawei_ads_config.dart';
import 'package:water_ejector/utils/sound_generator.dart';
import 'package:water_ejector/widgets/huawei_bottom_banner_ad.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      HuaweiAdsConfig.privacyAcceptedPrefsKey: true,
    });
    HuaweiAdsConfig.resetForTesting();
  });

  group('SoundGenerator DSP WAV Synthesis & Real HMS Config Tests', () {
    test('Verifies real production Huawei App ID & Petal Ad Unit IDs', () {
      expect(HuaweiAdsConfig.appId, equals('119454967'));
      expect(HuaweiAdsConfig.bannerAdSlotId, equals('g37tebz64w'));
      expect(HuaweiAdsConfig.interstitialAdSlotId, equals('e8du1bx9pa'));
      expect(HuaweiAdsConfig.backupInterstitialAdSlotId, equals('y20zf3cylg'));
      expect(HuaweiAdsConfig.developerName, equals('NGUYEN MINH THANH'));
      expect(
        HuaweiAdsConfig.appName,
        equals('Water Ejector: Speaker Cleaner'),
      );
      expect(
        HuaweiAdsConfig.packageName,
        equals('NGUYENMINHTHANH.WaterEjector'),
      );
    });

    test('Synthesizes valid 165Hz RIFF WAVE 16-bit PCM bytes', () {
      final Uint8List bytes =
          SoundGenerator.getEjectWavBytes(EjectMode.standard165Hz);
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(bytes.sublist(36, 40)), equals('data'));
    });

    test('Calculates 100Hz -> 200Hz -> 100Hz sweep frequency accurately', () {
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

    test('Generates all 3 Speaker Test WAV buffers (Bass, Treble, Beep)', () {
      for (final SpeakerTestType type in SpeakerTestType.values) {
        final Uint8List wav = SoundGenerator.getSpeakerTestWavBytes(type);
        expect(wav.length, greaterThan(1000));
      }
    });
  });

  testWidgets(
      'Enforces First-Launch Privacy Consent gate (is_privacy_accepted) before loading Ads',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    try {
      await tester.pumpWidget(
        const WaterEjectorApp(
          enablePlatformAudio: false,
          initialPrivacyAccepted: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      // 1. Hộp thoại First-Launch Privacy Policy bắt buộc hiển thị ngay lập tức
      expect(find.text('Privacy Policy & Terms'), findsOneWidget);
      expect(
        find.textContaining('Developer Name: NGUYEN MINH THANH'),
        findsWidgets,
      );
      expect(
        find.textContaining('App Name: Water Ejector: Speaker Cleaner'),
        findsWidgets,
      );
      expect(find.text('Accept & Continue'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);

      // 2. Trước khi bấm Accept: Banner Ad (g37tebz64w) TUYỆT ĐỐI chưa được tải
      expect(find.textContaining('g37tebz64w'), findsNothing);

      // 3. Bấm "Accept & Continue" -> Lưu is_privacy_accepted = true & mở khóa Banner Ad
      await tester.tap(find.text('Accept & Continue'));
      await tester.pump(const Duration(milliseconds: 300));

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(HuaweiAdsConfig.privacyAcceptedPrefsKey),
        isTrue,
      );
      expect(find.textContaining('g37tebz64w'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'Renders English default HomeScreen, fixed bottom Banner, & completes 30s cycle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const WaterEjectorApp(enablePlatformAudio: false),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Đảm bảo HuaweiBottomBannerAd nằm cố định ngoài SingleChildScrollView (trong bottomNavigationBar)
    expect(find.byType(HuaweiBottomBannerAd), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(HuaweiBottomBannerAd),
      ),
      findsNothing,
    );

    // Đảm bảo không tự động phát âm thanh khi vừa mở ứng dụng
    final BuildContext ctx = tester.element(find.byType(Scaffold));
    expect(
      Provider.of<WaterEjectorProvider>(ctx, listen: false).isEjecting,
      isFalse,
    );

    expect(find.text('Water Ejector'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('Standard 165Hz'), findsOneWidget);
    expect(find.text('100–200Hz Sweep'), findsOneWidget);
    expect(find.text('Test Bass'), findsOneWidget);
    expect(find.text('Test Treble'), findsOneWidget);
    expect(find.text('Test Beep'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.ensureVisible(find.text('1 Min'));
    await tester.tap(find.text('1 Min'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('01:00'), findsOneWidget);

    await tester.ensureVisible(find.text('30 Secs'));
    await tester.tap(find.text('30 Secs'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('00:30'), findsOneWidget);

    await tester.ensureVisible(find.text('ACTIVATE WATER EJECTOR'));
    await tester.tap(find.text('ACTIVATE WATER EJECTOR'));
    await tester.pump(const Duration(seconds: 15));
    expect(find.text('00:15'), findsOneWidget);

    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Water Ejection Complete!'), findsOneWidget);
  });

  testWidgets(
      'Supports all 9 international languages cleanly without UI overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const WaterEjectorApp(enablePlatformAudio: false),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final BuildContext appContext = tester.element(find.byType(Scaffold));
    final WaterEjectorProvider provider =
        Provider.of<WaterEjectorProvider>(appContext, listen: false);

    final Map<String, String> expectedPrivacyButton = <String, String>{
      'en': 'Privacy Policy',
      'vi': 'Chính sách Bảo mật',
      'zh': '隐私政策',
      'es': 'Política de Privacidad',
      'pt': 'Política de Privacidade',
      'ru': 'Конфиденциальность',
      'fr': 'Confidentialité',
      'ja': 'プライバシーポリシー',
      'de': 'Datenschutz',
    };

    expect(AppLocalizations.supportedLocales.length, equals(9));

    for (final Locale locale in AppLocalizations.supportedLocales) {
      provider.changeLocale(locale);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text(expectedPrivacyButton[locale.languageCode]!),
        findsOneWidget,
      );
    }
  });

  testWidgets('Opens in-app Privacy Policy dialog with NGUYEN MINH THANH & OAID details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const WaterEjectorApp(enablePlatformAudio: false),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Privacy Policy & Terms'), findsOneWidget);
    expect(
      find.textContaining('Developer Name: NGUYEN MINH THANH'),
      findsWidgets,
    );
    expect(find.textContaining('alphaplus.thanh82@gmail.com'), findsWidgets);
    expect(find.textContaining('OAID'), findsWidgets);
  });

  testWidgets('Automatically displays Huawei Interstitial Ad (e8du1bx9pa) upon completion',
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

      await tester.ensureVisible(find.text('ACTIVATE WATER EJECTOR'));
      await tester.tap(find.text('ACTIVATE WATER EJECTOR'));
      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Huawei Interstitial Ad'), findsOneWidget);
      expect(find.textContaining('e8du1bx9pa'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
