import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'providers/water_ejector_provider.dart';
import 'screens/home_screen.dart';
import 'utils/huawei_ads_config.dart';

Future<void> main() async {
  // Đảm bảo Flutter Engine & Platform Channels sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // Cố định giao diện màn hình dọc & làm trong suốt thanh trạng thái
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

  // Đọc trạng thái chấp thuận Chính sách Bảo mật (is_privacy_accepted) & ngôn ngữ đã lưu
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool privacyAccepted =
      prefs.getBool(HuaweiAdsConfig.privacyAcceptedPrefsKey) ?? false;
  final String? savedLocaleCode =
      prefs.getString(HuaweiAdsConfig.selectedLocalePrefsKey);
  final Locale initialLocale =
      savedLocaleCode != null && savedLocaleCode.isNotEmpty
          ? Locale(savedLocaleCode)
          : const Locale('en');

  // TUÂN THỦ APPGALLERY: Chỉ khởi tạo HwAds.init() ngay khi mở app NẾU người dùng đã đồng ý từ trước
  if (privacyAccepted) {
    await HuaweiAdsConfig.ensureSdkInitialized();
  }

  runApp(
    WaterEjectorApp(
      initialLocale: initialLocale,
      initialPrivacyAccepted: privacyAccepted,
    ),
  );
}

class WaterEjectorApp extends StatelessWidget {
  const WaterEjectorApp({
    super.key,
    this.enablePlatformAudio = true,
    this.initialLocale = const Locale('en'),
    this.initialPrivacyAccepted = true,
  });

  final bool enablePlatformAudio;
  final Locale initialLocale;
  final bool initialPrivacyAccepted;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WaterEjectorProvider>(
      create: (_) => WaterEjectorProvider(
        enablePlatformAudio: enablePlatformAudio,
        initialLocale: initialLocale,
        initialPrivacyAccepted: initialPrivacyAccepted,
      ),
      child: Consumer<WaterEjectorProvider>(
        builder: (
          BuildContext context,
          WaterEjectorProvider provider,
          Widget? child,
        ) {
          return MaterialApp(
            title: HuaweiAdsConfig.appName,
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
              fontFamily: 'Roboto',
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
