import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:huawei_ads/huawei_ads.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/water_ejector_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  // Đảm bảo Flutter Engine & Platform Channels sẵn sàng trước khi gọi native SDK
  WidgetsFlutterBinding.ensureInitialized();

  // Cố định giao diện màn hình dọc & làm trong suốt thanh trạng thái hiện đại
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF050914),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Khởi tạo Huawei Petal Ads SDK (HMS Ads) trên nền tảng Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await HwAds.init();
      await HwAds.setRequestOptions(
        RequestOptions(
          nonPersonalizedAd: NonPersonalizedAd.ALLOW_ALL.value,
          adContentClassification:
              ContentClassification.AD_CONTENT_CLASSIFICATION_W,
        ),
      );
      debugPrint('Huawei Petal Ads SDK (HwAds) initialized successfully.');
    } catch (e) {
      debugPrint('Huawei Petal Ads SDK initialization warning: $e');
    }
  }

  runApp(const WaterEjectorApp());
}

class WaterEjectorApp extends StatelessWidget {
  const WaterEjectorApp({
    super.key,
    this.enablePlatformAudio = true,
    this.initialLocale = const Locale('en'),
  });

  final bool enablePlatformAudio;
  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WaterEjectorProvider>(
      create: (_) => WaterEjectorProvider(
        enablePlatformAudio: enablePlatformAudio,
        initialLocale: initialLocale,
      ),
      child: Consumer<WaterEjectorProvider>(
        builder: (
          BuildContext context,
          WaterEjectorProvider provider,
          Widget? child,
        ) {
          return MaterialApp(
            title: 'Water Ejector: Speaker Cleaner',
            debugShowCheckedModeBanner: false,
            locale: provider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF060B19),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00E5FF),
                brightness: Brightness.dark,
                primary: const Color(0xFF00E5FF),
                secondary: const Color(0xFF64FFDA),
                surface: const Color(0xFF0D1B35),
              ),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
