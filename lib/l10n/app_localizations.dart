import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Mô tả thông tin hiển thị của từng ngôn ngữ được hỗ trợ trên bộ chọn ngôn ngữ
class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.nativeName,
    required this.flag,
  });

  final String code;
  final String nativeName;
  final String flag;

  Locale get locale => Locale(code);
}

/// Bộ quản lý Đa ngôn ngữ Quốc tế (i18n) hỗ trợ 9 ngôn ngữ:
/// Tiếng Anh (en - mặc định), Tiếng Việt (vi), Tiếng Trung (zh),
/// Tây Ban Nha (es), Bồ Đào Nha (pt), Nga (ru), Pháp (fr), Nhật (ja), Đức (de).
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  /// Truy xuất nhanh thể hiện AppLocalizations từ BuildContext
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Danh sách 9 ngôn ngữ hỗ trợ (Tiếng Anh 'en' là mặc định đầu tiên)
  static const List<LanguageOption> languageOptions = <LanguageOption>[
    LanguageOption(code: 'en', nativeName: 'English', flag: '🇺🇸'),
    LanguageOption(code: 'vi', nativeName: 'Tiếng Việt', flag: '🇻🇳'),
    LanguageOption(code: 'zh', nativeName: '简体中文', flag: '🇨🇳'),
    LanguageOption(code: 'es', nativeName: 'Español', flag: '🇪🇸'),
    LanguageOption(code: 'pt', nativeName: 'Português', flag: '🇵🇹'),
    LanguageOption(code: 'ru', nativeName: 'Русский', flag: '🇷🇺'),
    LanguageOption(code: 'fr', nativeName: 'Français', flag: '🇫🇷'),
    LanguageOption(code: 'ja', nativeName: '日本語', flag: '🇯🇵'),
    LanguageOption(code: 'de', nativeName: 'Deutsch', flag: '🇩🇪'),
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
    Locale('zh'),
    Locale('es'),
    Locale('pt'),
    Locale('ru'),
    Locale('fr'),
    Locale('ja'),
    Locale('de'),
  ];

  /// Dịch khóa văn bản sang ngôn ngữ hiện tại (tự động fallback về 'en' nếu thiếu khóa)
  String translate(String key, [Map<String, String>? params]) {
    final String normalizedCode = Intl.shortLocale(locale.toLanguageTag());
    final Map<String, String> activeMap =
        _localizedValues[normalizedCode] ??
            _localizedValues[locale.languageCode] ??
            _localizedValues['en']!;
    String text = activeMap[key] ?? _localizedValues['en']?[key] ?? key;

    if (params != null && params.isNotEmpty) {
      params.forEach((String paramKey, String value) {
        text = text.replaceAll('{$paramKey}', value);
      });
    }
    return text;
  }

  static const Map<String, Map<String, String>> _localizedValues =
      <String, Map<String, String>>{
    // 1. ENGLISH (Default)
    'en': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Speaker Cleaner • 165Hz DSP',
      'language_menu_title': 'Select Language',
      'tips_tooltip': 'Usage Guide',
      'privacy_policy_btn': 'Privacy Policy',
      'usage_guide_btn': 'Cleaning Guide',
      'top_tip':
          'Tip: Set volume to 100% and place phone speaker facing downward.',
      'cycles_badge': '{count}x',
      'center_start': 'START EJECT',
      'center_stop': 'STOP',
      'status_ready': 'Ready to clean speaker membrane',
      'status_testing': 'Playing {test} ({range})',
      'status_stage_1': 'Stage 1/3: Detaching water droplets from mesh...',
      'status_stage_2': 'Stage 2/3: Expelling water via acoustic pressure...',
      'status_stage_3': 'Stage 3/3: Drying micro-membrane & stabilizing...',
      'mode_section_title': 'Acoustic Ejection Mode',
      'mode_standard_title': 'Standard 165Hz',
      'mode_standard_sub': 'Large droplets',
      'mode_sweep_title': '100–200Hz Sweep',
      'mode_sweep_sub': 'Full resonance',
      'mode_pulse_title': 'Turbo Pulse',
      'mode_pulse_sub': 'Stubborn mist',
      'duration_section_title': 'Countdown Timer Duration',
      'duration_30s': '30 Secs',
      'duration_60s': '1 Min',
      'btn_start_eject': 'ACTIVATE WATER EJECTOR',
      'btn_stop_eject': 'STOP EJECTING ({time})',
      'test_section_title': 'Test Speaker • Check Audio Clarity',
      'btn_stop_test': 'Stop',
      'test_bass_label': 'Test Bass',
      'test_bass_desc': 'Low-end rattle',
      'test_treble_label': 'Test Treble',
      'test_treble_desc': 'High clarity',
      'test_beep_label': 'Test Beep',
      'test_beep_desc': 'Pure tone check',
      'dialog_complete_title': 'Water Ejection Complete!',
      'dialog_complete_body':
          'The speaker vibration cycle reached 100%. Gently wipe off any surface moisture on the speaker grille and tap "Test Speaker Now" to verify clarity.',
      'btn_close': 'Close',
      'btn_test_now': 'Test Speaker Now',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID: {slotId}\nFull-screen ad automatically displayed when the Water Ejector cycle completes on HMS devices.',
      'ad_close_continue': 'Close & View Cleaning Result',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 Steps for Maximum Water Ejection',
      'tip_step_1':
          'Disconnect Bluetooth or wired headphones so sound plays through the built-in speaker.',
      'tip_step_2':
          'Raise Media volume to 100% for maximum speaker diaphragm excursion.',
      'tip_step_3':
          'Place the phone screen-down or angle the speaker grille downward with gravity.',
      'tip_step_4':
          'Run "Standard 165Hz" first, then "100–200Hz Sweep" if muffled sound persists.',
      'privacy_dialog_title': 'Privacy Policy & Terms',
      'privacy_updated': 'Effective Date: October 21, 2026',
      'privacy_dev_header': '1. Developer Information',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nPackage ID: NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\nContact Email: alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK & OAID',
      'privacy_ads_body':
          'This app integrates the official Huawei Petal Ads SDK (huawei_ads) to display Banner Ads and Interstitial Ads. The SDK may process device identifiers including Open Advertising ID (OAID), network state, and ad performance metrics strictly for ad delivery and fraud prevention.',
      'privacy_audio_header': '3. Audio Output Only — Zero Microphone Access',
      'privacy_audio_body':
          'Water Ejector strictly uses Audio Output (STREAM_MUSIC) only to emit 165Hz & 100Hz–200Hz cleaning waves. We NEVER record audio and NEVER request or access your device Microphone.',
      'privacy_disclaimer_header': '4. Hardware Liquid Damage Disclaimer',
      'privacy_disclaimer_body':
          'Acoustic vibration assists in expelling surface moisture from speaker grilles and is not a substitute for professional repair. Developer Nguyen Minh Thanh is not liable for pre-existing liquid ingress, corrosion, or hardware damage.',
      'privacy_rights_header': '5. Data Subject Rights & Opt-Out OAID',
      'privacy_rights_body':
          'You can opt out of personalized ads or reset your OAID anytime at: Settings > Privacy > Ads and privacy > Limit ad tracking / Reset Ad-ID. For any data inquiries or deletion requests, email alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Copy Support Email',
      'email_copied_toast': 'Copied alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          'Please review and accept our Privacy Policy before using the app. Huawei Petal Ads (OAID) initializes only after your consent.',
      'btn_accept_continue': 'Accept & Continue',
      'btn_exit_app': 'Exit App',
    },

    // 2. VIETNAMESE (Tiếng Việt)
    'vi': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Làm Sạch Loa • Sóng Âm 165Hz',
      'language_menu_title': 'Chọn ngôn ngữ',
      'tips_tooltip': 'Hướng dẫn sử dụng',
      'privacy_policy_btn': 'Chính sách Bảo mật',
      'usage_guide_btn': 'Mẹo làm sạch',
      'top_tip':
          'Mẹo: Bật âm lượng 100% và đặt úp khe loa hướng xuống dưới khi chạy.',
      'cycles_badge': '{count} lần',
      'center_start': 'BẮT ĐẦU ĐẨY NƯỚC',
      'center_stop': 'DỪNG',
      'status_ready': 'Sẵn sàng làm sạch màng loa',
      'status_testing': 'Đang phát {test} ({range})',
      'status_stage_1': 'Giai đoạn 1/3: Tách nước khỏi lưới loa...',
      'status_stage_2': 'Giai đoạn 2/3: Đẩy giọt nước ra bằng áp suất sóng...',
      'status_stage_3': 'Giai đoạn 3/3: Làm khô vi màng loa & ổn định...',
      'mode_section_title': 'Chế độ sóng âm đẩy nước',
      'mode_standard_title': 'Chuẩn 165Hz',
      'mode_standard_sub': 'Đẩy giọt nước lớn',
      'mode_sweep_title': 'Quét 100–200Hz',
      'mode_sweep_sub': 'Làm sạch toàn dải',
      'mode_pulse_title': 'Xung Mạnh',
      'mode_pulse_sub': 'Giũ sạch hạt mịn',
      'duration_section_title': 'Thời gian đếm ngược chu trình',
      'duration_30s': '30 Giây',
      'duration_60s': '1 Phút',
      'btn_start_eject': 'KÍCH HOẠT ĐẨY NƯỚC NGAY',
      'btn_stop_eject': 'DỪNG ĐẨY NƯỚC ({time})',
      'test_section_title': 'Test Speaker • Kiểm tra loa còn rè không',
      'btn_stop_test': 'Dừng',
      'test_bass_label': 'Test Bass',
      'test_bass_desc': 'Kiểm tra rè trầm',
      'test_treble_label': 'Test Treble',
      'test_treble_desc': 'Kiểm tra âm cao',
      'test_beep_label': 'Test Beep',
      'test_beep_desc': 'Kiểm tra độ trong',
      'dialog_complete_title': 'Hoàn tất đẩy nước!',
      'dialog_complete_body':
          'Chu trình rung màng loa đã hoàn thành 100%. Hãy lau khô nhẹ bề mặt lưới loa và bấm "Test Loa Ngay" để kiểm tra độ trong trẻo.',
      'btn_close': 'Đóng',
      'btn_test_now': 'Test Loa Ngay',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID: {slotId}\nQuảng cáo toàn màn hình tự động bung ra khi chu trình đẩy nước hoàn tất trên thiết bị HMS.',
      'ad_close_continue': 'Đóng & Xem Kết Quả',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 Bước Đẩy Nước Sạch Tối Đa',
      'tip_step_1':
          'Ngắt kết nối tai nghe Bluetooth / có dây để âm thanh phát trực tiếp ra loa ngoài.',
      'tip_step_2':
          'Tăng âm lượng Media lên tối đa (100%) để màng loa đạt biên độ dao động mạnh nhất.',
      'tip_step_3':
          'Đặt úp điện thoại hoặc hướng khe loa dốc xuống dưới theo chiều trọng lực.',
      'tip_step_4':
          'Chạy "Chuẩn 165Hz" trước, sau đó chạy thêm "Quét 100–200Hz" nếu loa vẫn còn rè.',
      'privacy_dialog_title': 'Chính sách Bảo mật & Điều khoản',
      'privacy_updated': 'Ngày hiệu lực: 21/10/2026',
      'privacy_dev_header': '1. Thông tin Nhà phát triển',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nMã gói (Package ID): NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\nEmail liên hệ: alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK & OAID',
      'privacy_ads_body':
          'Ứng dụng tích hợp Huawei Petal Ads SDK (huawei_ads) để hiển thị Banner Ad và Interstitial Ad. SDK có thể xử lý mã định danh quảng cáo mở (OAID), trạng thái mạng và dữ liệu tương tác quảng cáo nhằm phân phối quảng cáo hợp lệ và chống gian lận.',
      'privacy_audio_header': '3. Chỉ Phát Âm Thanh — KHÔNG Ghi Âm',
      'privacy_audio_body':
          'Ứng dụng cam kết chỉ sử dụng đầu ra âm thanh (Audio Output) để phát sóng rung vệ sinh màng loa, tuyệt đối KHÔNG ghi âm và KHÔNG truy cập Microphone.',
      'privacy_disclaimer_header': '4. Miễn trừ Trách nhiệm Phần cứng',
      'privacy_disclaimer_body':
          'Sóng âm hỗ trợ đẩy hơi ẩm bề mặt ra khỏi lưới loa và không thay thế sửa chữa phần cứng chuyên nghiệp. Nhà phát triển miễn trừ trách nhiệm đối với hư hỏng phần cứng do nước ngấm sâu vào bo mạch.',
      'privacy_rights_header': '5. Quyền Quản lý Dữ liệu & Tắt OAID',
      'privacy_rights_body':
          'Bạn có thể đặt lại hoặc tắt theo dõi OAID bất cứ lúc nào tại: Cài đặt > Quyền riêng tư > Quảng cáo và quyền riêng tư > Giới hạn theo dõi quảng cáo / Đặt lại ID quảng cáo. Mọi yêu cầu hỗ trợ hoặc xóa dữ liệu vui lòng gửi về alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Sao chép Email Hỗ trợ',
      'email_copied_toast': 'Đã sao chép alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          'Vui lòng xem và đồng ý Chính sách Bảo mật trước khi sử dụng. Huawei Petal Ads (OAID) chỉ khởi tạo sau khi bạn đồng ý.',
      'btn_accept_continue': 'Đồng ý & Tiếp tục',
      'btn_exit_app': 'Thoát ứng dụng',
    },

    // 3. CHINESE SIMPLIFIED (简体中文)
    'zh': <String, String>{
      'app_title': '声波排水器',
      'app_subtitle': '扬声器清理 • 165Hz 声波引擎',
      'language_menu_title': '选择语言',
      'tips_tooltip': '使用指南',
      'privacy_policy_btn': '隐私政策',
      'usage_guide_btn': '排水指南',
      'top_tip': '提示：请将媒体音量调至 100%，并将手机扬声器朝下放置。',
      'cycles_badge': '{count}次',
      'center_start': '开始排水',
      'center_stop': '停止',
      'status_ready': '准备清理扬声器振膜',
      'status_testing': '正在播放 {test} ({range})',
      'status_stage_1': '阶段 1/3：高频振动分离滤网水珠...',
      'status_stage_2': '阶段 2/3：声压脉冲推出积水...',
      'status_stage_3': '阶段 3/3：干燥振膜并稳定音质...',
      'mode_section_title': '声波排水模式',
      'mode_standard_title': '标准 165Hz',
      'mode_standard_sub': '排出大水滴',
      'mode_sweep_title': '100–200Hz 扫频',
      'mode_sweep_sub': '全频深度清理',
      'mode_pulse_title': '强力脉冲',
      'mode_pulse_sub': '震落细微水雾',
      'duration_section_title': '倒计时清理时长',
      'duration_30s': '30 秒',
      'duration_60s': '1 分钟',
      'btn_start_eject': '立即启动声波排水',
      'btn_stop_eject': '停止排水 ({time})',
      'test_section_title': '扬声器测试 • 检查音质清晰度',
      'btn_stop_test': '停止',
      'test_bass_label': '低音测试',
      'test_bass_desc': '检测低频杂音',
      'test_treble_label': '高音测试',
      'test_treble_desc': '检测高频通透',
      'test_beep_label': '蜂鸣测试',
      'test_beep_desc': '纯净度检测',
      'dialog_complete_title': '声波排水已完成！',
      'dialog_complete_body': '扬声器振动清理已达到 100%。请轻轻擦拭扬声器孔表面水珠，并点击下方按钮测试音质。',
      'btn_close': '关闭',
      'btn_test_now': '立即测试扬声器',
      'ad_preview_badge': '广告 • HUAWEI PETAL ADS',
      'ad_interstitial_title': '华为全屏插页广告',
      'ad_interstitial_body': '广告位 ID：{slotId}\n排水周期完成后自动展示华为 Petal Ads 插页广告。',
      'ad_close_continue': '关闭并查看清理结果',
      'ad_banner_label': '华为 Petal 横幅广告 • {slotId}',
      'tips_sheet_title': '高效排水 4 步指南',
      'tip_step_1': '请先断开蓝牙耳机或有线耳机，确保声音从外放扬声器发出。',
      'tip_step_2': '将手机媒体音量调至最大（100%），以产生最大振膜振幅。',
      'tip_step_3': '将手机屏幕朝下平放，或让扬声器开孔朝下以便重力排液。',
      'tip_step_4': '建议先运行“标准 165Hz”，若仍有轻微杂音再运行“100–200Hz 扫频”。',
      'privacy_dialog_title': '隐私政策与免责声明',
      'privacy_updated': '生效日期：2026年10月21日',
      'privacy_dev_header': '1. 开发者信息',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\n应用包名：NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\n联系邮箱：alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. 华为 Petal Ads SDK 与 OAID 声明',
      'privacy_ads_body':
          '本应用集成了官方华为鲸鸿动能广告 SDK（huawei_ads），可能会收集并处理开放匿名设备标识符（OAID）、网络状态及广告互动数据，仅用于广告展示与反作弊。',
      'privacy_audio_header': '3. 仅音频输出承诺（绝不访问麦克风）',
      'privacy_audio_body':
          '本应用仅使用音频输出通道（Audio Output）播放排水声波，绝不录音，也绝不申请或访问麦克风权限。',
      'privacy_disclaimer_header': '4. 硬件进水免责声明',
      'privacy_disclaimer_body':
          '声波振动仅辅助排出扬声器网罩表面水分，不能替代专业维修。对于液体深度渗入主板或硬件损坏，开发者概不承担责任。',
      'privacy_rights_header': '5. 用户数据权利与重置 OAID 指南',
      'privacy_rights_body':
          '您可随时前往“设置 > 隐私 > 广告与隐私”开启“限制广告跟踪”或点击“重置广告标识符”管理 OAID。如有任何数据相关请求，请联系 alphaplus.thanh82@gmail.com。',
      'btn_copy_email': '复制联系邮箱',
      'email_copied_toast': '已复制 alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          '使用前请阅读并同意隐私政策。华为鲸鸿动能广告 SDK（OAID）仅在您同意后初始化。',
      'btn_accept_continue': '同意并继续',
      'btn_exit_app': '退出应用',
    },

    // 4. SPANISH (Español)
    'es': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Limpiador Altavoz • 165Hz DSP',
      'language_menu_title': 'Seleccionar idioma',
      'tips_tooltip': 'Guía de uso',
      'privacy_policy_btn': 'Política de Privacidad',
      'usage_guide_btn': 'Guía rápida',
      'top_tip':
          'Consejo: Sube el volumen al 100% y coloca el altavoz mirando hacia abajo.',
      'cycles_badge': '{count}x',
      'center_start': 'EXPULSAR AGUA',
      'center_stop': 'DETENER',
      'status_ready': 'Listo para limpiar el altavoz',
      'status_testing': 'Reproduciendo {test} ({range})',
      'status_stage_1': 'Fase 1/3: Desprendiendo gotas de la malla...',
      'status_stage_2': 'Fase 2/3: Expulsando agua con presión acústica...',
      'status_stage_3': 'Fase 3/3: Secando micro-membrana y estabilizando...',
      'mode_section_title': 'Modo de ondas acústicas',
      'mode_standard_title': 'Estándar 165Hz',
      'mode_standard_sub': 'Gotas grandes',
      'mode_sweep_title': 'Barrido 100–200Hz',
      'mode_sweep_sub': 'Limpieza total',
      'mode_pulse_title': 'Pulso Fuerte',
      'mode_pulse_sub': 'Humedad fina',
      'duration_section_title': 'Duración del temporizador',
      'duration_30s': '30 Seg',
      'duration_60s': '1 Min',
      'btn_start_eject': 'ACTIVAR EXPULSIÓN DE AGUA',
      'btn_stop_eject': 'DETENER ({time})',
      'test_section_title': 'Probar Altavoz • Verificar sonido',
      'btn_stop_test': 'Parar',
      'test_bass_label': 'Test Graves',
      'test_bass_desc': 'Vibración baja',
      'test_treble_label': 'Test Agudos',
      'test_treble_desc': 'Claridad alta',
      'test_beep_label': 'Test Pitido',
      'test_beep_desc': 'Tono puro',
      'dialog_complete_title': '¡Expulsión completada!',
      'dialog_complete_body':
          'El ciclo de vibración llegó al 100%. Seca suavemente la rejilla exterior y pulsa "Probar ahora" para comprobar la nitidez.',
      'btn_close': 'Cerrar',
      'btn_test_now': 'Probar ahora',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID: {slotId}\nAnuncio a pantalla completa mostrado automáticamente al finalizar la limpieza.',
      'ad_close_continue': 'Cerrar y ver resultado',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 Pasos para Limpieza Máxima',
      'tip_step_1':
          'Desconecta auriculares Bluetooth o con cable para usar el altavoz externo.',
      'tip_step_2':
          'Ajusta el volumen multimedia al 100% para lograr la máxima vibración.',
      'tip_step_3':
          'Coloca el móvil boca abajo para que la gravedad ayude a expulsar el agua.',
      'tip_step_4':
          'Ejecuta primero "Estándar 165Hz" y luego "Barrido 100–200Hz" si persiste distorsión.',
      'privacy_dialog_title': 'Política de Privacidad y Términos',
      'privacy_updated': 'Fecha de entrada en vigor: 21/10/2026',
      'privacy_dev_header': '1. Información del Desarrollador',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nID de paquete: NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\nCorreo de contacto: alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK y OAID',
      'privacy_ads_body':
          'Esta app integra Huawei Petal Ads SDK (huawei_ads) para mostrar anuncios Banner e Interstitial, recopilando el identificador de publicidad abierto (OAID) y estado de red únicamente para entrega publicitaria y prevención de fraude.',
      'privacy_audio_header': '3. Solo Salida de Audio — Cero Micrófono',
      'privacy_audio_body':
          'Usamos exclusivamente la salida de audio (Audio Output) para limpiar el altavoz. NUNCA grabamos audio ni accedemos al micrófono.',
      'privacy_disclaimer_header': '4. Exención de Responsabilidad de Hardware',
      'privacy_disclaimer_body':
          'La vibración acústica ayuda a expulsar humedad superficial y no sustituye una reparación técnica. El desarrollador no se responsabiliza por daños internos provocados por filtración profunda de líquidos.',
      'privacy_rights_header': '5. Derechos de Datos y Control de OAID',
      'privacy_rights_body':
          'Puedes restablecer o limitar el seguimiento de tu OAID en: Ajustes > Privacidad > Anuncios y privacidad > Limitar seguimiento de anuncios. Contacto: alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Copiar correo de soporte',
      'email_copied_toast': 'Copiado: alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          'Revisa y acepta nuestra Política de Privacidad antes de continuar. Huawei Petal Ads (OAID) solo se inicia tras tu consentimiento.',
      'btn_accept_continue': 'Aceptar y Continuar',
      'btn_exit_app': 'Salir',
    },

    // 5. PORTUGUESE (Português)
    'pt': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Limpar Alto-falante • 165Hz',
      'language_menu_title': 'Selecionar idioma',
      'tips_tooltip': 'Guia de uso',
      'privacy_policy_btn': 'Política de Privacidade',
      'usage_guide_btn': 'Dicas de limpeza',
      'top_tip':
          'Dica: Aumente o volume para 100% e vire a saída de som para baixo.',
      'cycles_badge': '{count}x',
      'center_start': 'EJETAR ÁGUA',
      'center_stop': 'PARAR',
      'status_ready': 'Pronto para limpar o alto-falante',
      'status_testing': 'Tocando {test} ({range})',
      'status_stage_1': 'Etapa 1/3: Soltando gotículas da grade...',
      'status_stage_2': 'Etapa 2/3: Expelindo água com pressão sonora...',
      'status_stage_3': 'Etapa 3/3: Secando a membrana acústica...',
      'mode_section_title': 'Modo de ejeção acústica',
      'mode_standard_title': 'Padrão 165Hz',
      'mode_standard_sub': 'Gotas grandes',
      'mode_sweep_title': 'Varredura 100–200Hz',
      'mode_sweep_sub': 'Limpeza completa',
      'mode_pulse_title': 'Pulso Forte',
      'mode_pulse_sub': 'Névoa fina',
      'duration_section_title': 'Duração da contagem regressiva',
      'duration_30s': '30 Seg',
      'duration_60s': '1 Min',
      'btn_start_eject': 'ATIVAR EJEÇÃO DE ÁGUA',
      'btn_stop_eject': 'PARAR EJEÇÃO ({time})',
      'test_section_title': 'Testar Alto-falante • Verificar áudio',
      'btn_stop_test': 'Parar',
      'test_bass_label': 'Testar Grave',
      'test_bass_desc': 'Vibração grave',
      'test_treble_label': 'Testar Agudo',
      'test_treble_desc': 'Nitidez aguda',
      'test_beep_label': 'Testar Beep',
      'test_beep_desc': 'Som cristalino',
      'dialog_complete_title': 'Limpeza concluída!',
      'dialog_complete_body':
          'O ciclo de ejeção atingiu 100%. Limpe levemente a grade externa e toque em "Testar agora" para verificar o som.',
      'btn_close': 'Fechar',
      'btn_test_now': 'Testar agora',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID: {slotId}\nAnúncio em tela cheia exibido automaticamente ao concluir o ciclo.',
      'ad_close_continue': 'Fechar e ver resultado',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 Passos para Ejeção Máxima',
      'tip_step_1':
          'Desconecte fones Bluetooth ou com fio para reproduzir pelo alto-falante.',
      'tip_step_2':
          'Coloque o volume de mídia em 100% para máxima vibração da membrana.',
      'tip_step_3':
          'Posicione o celular virado para baixo a favor da gravidade.',
      'tip_step_4':
          'Use "Padrão 165Hz" primeiro e depois "Varredura 100–200Hz" se necessário.',
      'privacy_dialog_title': 'Política de Privacidade e Termos',
      'privacy_updated': 'Data de vigência: 21/10/2026',
      'privacy_dev_header': '1. Informações do Desenvolvedor',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nPackage ID: NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\nE-mail de contato: alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK e OAID',
      'privacy_ads_body':
          'Este app utiliza o Huawei Petal Ads SDK (huawei_ads) e pode coletar o Open Advertising ID (OAID) e estado da rede exclusivamente para exibição segura de anúncios.',
      'privacy_audio_header': '3. Apenas Saída de Áudio — Sem Microfone',
      'privacy_audio_body':
          'O aplicativo usa estritamente a saída de áudio (Audio Output) e NUNCA grava sons nem acessa o microfone do aparelho.',
      'privacy_disclaimer_header': '4. Isenção de Responsabilidade de Hardware',
      'privacy_disclaimer_body':
          'A vibração sonora auxilia na remoção de umidade superficial e não substitui assistência técnica. O desenvolvedor não se responsabiliza por danos causados por infiltração profunda de líquidos.',
      'privacy_rights_header': '5. Direitos do Titular e Desativação do OAID',
      'privacy_rights_body':
          'Você pode redefinir ou desativar a personalização do OAID em: Configurações > Privacidade > Anúncios e privacidade. Solicitações de dados: alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Copiar E-mail de Suporte',
      'email_copied_toast': 'Copiado: alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          'Leia e aceite nossa Política de Privacidade antes de usar. O Huawei Petal Ads (OAID) só é iniciado após o seu consentimento.',
      'btn_accept_continue': 'Aceitar e Continuar',
      'btn_exit_app': 'Sair do App',
    },

    // 6. RUSSIAN (Русский)
    'ru': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Очистка динамика • 165 Гц',
      'language_menu_title': 'Выберите язык',
      'tips_tooltip': 'Инструкция',
      'privacy_policy_btn': 'Конфиденциальность',
      'usage_guide_btn': 'Советы',
      'top_tip':
          'Совет: включите громкость 100% и поверните телефон динамиком вниз.',
      'cycles_badge': '{count}x',
      'center_start': 'ОЧИСТИТЬ',
      'center_stop': 'СТОП',
      'status_ready': 'Готов к очистке динамика',
      'status_testing': 'Проверка: {test} ({range})',
      'status_stage_1': 'Этап 1/3: Отделение капель от сетки...',
      'status_stage_2': 'Этап 2/3: Выталкивание воды звуковой волной...',
      'status_stage_3': 'Этап 3/3: Просушка мембраны динамика...',
      'mode_section_title': 'Режим звуковой очистки',
      'mode_standard_title': '165 Гц Базовый',
      'mode_standard_sub': 'Крупные капли',
      'mode_sweep_title': '100–200 Гц Скан',
      'mode_sweep_sub': 'Полный спектр',
      'mode_pulse_title': 'Импульс',
      'mode_pulse_sub': 'Мелкая влага',
      'duration_section_title': 'Таймер обратного отсчёта',
      'duration_30s': '30 сек',
      'duration_60s': '1 мин',
      'btn_start_eject': 'ЗАПУСТИТЬ ОЧИСТКУ ДИНАМИКА',
      'btn_stop_eject': 'ОСТАНОВИТЬ ({time})',
      'test_section_title': 'Проверка динамика • Тест чистоты звука',
      'btn_stop_test': 'Стоп',
      'test_bass_label': 'Тест Баса',
      'test_bass_desc': 'Низкие частоты',
      'test_treble_label': 'Тест Высоких',
      'test_treble_desc': 'Чёткость звука',
      'test_beep_label': 'Тест Сигнала',
      'test_beep_desc': 'Чистый тон',
      'dialog_complete_title': 'Очистка завершена!',
      'dialog_complete_body':
          'Цикл вибрации динамика выполнен на 100%. Протрите решётку сухой тканью и нажмите «Проверить звук».',
      'btn_close': 'Закрыть',
      'btn_test_now': 'Проверить звук',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID: {slotId}\nПолноэкранная реклама автоматически показывается после завершения очистки.',
      'ad_close_continue': 'Закрыть и продолжить',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 шага эффективной очистки',
      'tip_step_1':
          'Отключите наушники Bluetooth или кабель для вывода звука через динамик.',
      'tip_step_2':
          'Установите громкость мультимедиа на 100% для максимальной амплитуды.',
      'tip_step_3':
          'Положите смартфон экраном вниз или направьте динамик вниз.',
      'tip_step_4':
          'Сначала запустите «165 Гц Базовый», затем «100–200 Гц Скан».',
      'privacy_dialog_title': 'Политика конфиденциальности',
      'privacy_updated': 'Дата вступления в силу: 21.10.2026',
      'privacy_dev_header': '1. Сведения о разработчике',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nPackage ID: NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\nКонтактный Email: alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK и OAID',
      'privacy_ads_body':
          'Приложение использует Huawei Petal Ads SDK (huawei_ads) и может обрабатывать рекламный идентификатор OAID и статус сети исключительно для показа рекламы и защиты от мошенничества.',
      'privacy_audio_header': '3. Только вывод звука — без доступа к микрофону',
      'privacy_audio_body':
          'Приложение использует только аудиовыход (Audio Output) для очистки динамика, НИКОГДА не записывает звук и не запрашивает доступ к микрофону.',
      'privacy_disclaimer_header': '4. Ограничение ответственности',
      'privacy_disclaimer_body':
          'Звуковая очистка помогает удалить поверхностную влагу и не заменяет сервисный ремонт. Разработчик не несёт ответственности за аппаратные повреждения от глубокого проникновения воды.',
      'privacy_rights_header': '5. Права пользователя и отключение OAID',
      'privacy_rights_body':
          'Вы можете сбросить или ограничить OAID в меню: Настройки > Конфиденциальность > Реклама и конфиденциальность. По вопросам данных: alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Скопировать Email',
      'email_copied_toast': 'Скопировано: alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          'Пожалуйста, примите Политику конфиденциальности перед началом работы. Huawei Petal Ads (OAID) запускается только после вашего согласия.',
      'btn_accept_continue': 'Принять и продолжить',
      'btn_exit_app': 'Выйти',
    },

    // 7. FRENCH (Français)
    'fr': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Nettoyeur Haut-parleur • 165Hz',
      'language_menu_title': 'Choisir la langue',
      'tips_tooltip': 'Guide pratique',
      'privacy_policy_btn': 'Confidentialité',
      'usage_guide_btn': 'Conseils',
      'top_tip':
          'Astuce : Réglez le volume à 100 % et orientez le haut-parleur vers le bas.',
      'cycles_badge': '{count}x',
      'center_start': 'ÉJECTER L’EAU',
      'center_stop': 'ARRÊTER',
      'status_ready': 'Prêt à nettoyer le haut-parleur',
      'status_testing': 'Lecture {test} ({range})',
      'status_stage_1': 'Étape 1/3 : Détachement des gouttelettes...',
      'status_stage_2': 'Étape 2/3 : Éjection par pression acoustique...',
      'status_stage_3': 'Étape 3/3 : Séchage de la micro-membrane...',
      'mode_section_title': 'Mode d’onde acoustique',
      'mode_standard_title': 'Standard 165Hz',
      'mode_standard_sub': 'Grosses gouttes',
      'mode_sweep_title': 'Balayage 100–200Hz',
      'mode_sweep_sub': 'Spectre complet',
      'mode_pulse_title': 'Impulsion Forte',
      'mode_pulse_sub': 'Fines gouttes',
      'duration_section_title': 'Durée du compte à rebours',
      'duration_30s': '30 Sec',
      'duration_60s': '1 Min',
      'btn_start_eject': 'LANCER L’ÉJECTION D’EAU',
      'btn_stop_eject': 'ARRÊTER ({time})',
      'test_section_title': 'Tester le Haut-parleur • Clarté audio',
      'btn_stop_test': 'Stop',
      'test_bass_label': 'Test Basses',
      'test_bass_desc': 'Graves & vibrations',
      'test_treble_label': 'Test Aigus',
      'test_treble_desc': 'Clarté aiguë',
      'test_beep_label': 'Test Bip',
      'test_beep_desc': 'Son pur',
      'dialog_complete_title': 'Nettoyage terminé !',
      'dialog_complete_body':
          'Le cycle à 100 % est terminé. Essuyez délicatement la grille du haut-parleur puis appuyez sur « Tester le son ».',
      'btn_close': 'Fermer',
      'btn_test_now': 'Tester le son',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID : {slotId}\nPublicité plein écran affichée automatiquement à la fin du cycle.',
      'ad_close_continue': 'Fermer et voir le résultat',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 Étapes pour une Éjection Optimale',
      'tip_step_1':
          'Débranchez tout casque Bluetooth ou filaire pour activer le haut-parleur externe.',
      'tip_step_2':
          'Montez le volume multimédia à 100 % pour maximiser l’amplitude.',
      'tip_step_3':
          'Posez le téléphone écran vers le bas ou haut-parleur orienté vers le sol.',
      'tip_step_4':
          'Lancez d’abord « Standard 165Hz », puis « Balayage 100–200Hz » si besoin.',
      'privacy_dialog_title': 'Politique de Confidentialité & Conditions',
      'privacy_updated': 'Date d’effet : 21/10/2026',
      'privacy_dev_header': '1. Informations sur le Développeur',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nPackage ID : NGUYENMINHTHANH.WaterEjector\nHuawei App ID : 119454967\nE-mail de contact : alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK et OAID',
      'privacy_ads_body':
          'Cette application intègre Huawei Petal Ads SDK (huawei_ads) et utilise l’identifiant publicitaire ouvert (OAID) uniquement pour la diffusion d’annonces et la prévention de la fraude.',
      'privacy_audio_header': '3. Sortie Audio Uniquement — Aucun Microphone',
      'privacy_audio_body':
          'L’application utilise exclusivement la sortie audio (Audio Output) et n’enregistre JAMAIS le son ni n’accède au microphone.',
      'privacy_disclaimer_header': '4. Clause de Non-responsabilité Matérielle',
      'privacy_disclaimer_body':
          'Les ondes sonores aident à évacuer l’humidité superficielle et ne remplacent pas une réparation matérielle. Le développeur décline toute responsabilité en cas d’infiltration profonde.',
      'privacy_rights_header': '5. Vos Droits & Désactivation OAID',
      'privacy_rights_body':
          'Désactivez le suivi ou réinitialisez votre OAID dans : Paramètres > Confidentialité > Publicités et confidentialité. Contact : alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Copier l’e-mail support',
      'email_copied_toast': 'Copié : alphaplus.thanh82@gmail.com',
      'privacy_first_launch_intro':
          'Veuillez lire et accepter notre Politique de Confidentialité avant de continuer. Huawei Petal Ads (OAID) ne s’active qu’après votre accord.',
      'btn_accept_continue': 'Accepter et Continuer',
      'btn_exit_app': 'Quitter',
    },

    // 8. JAPANESE (日本語)
    'ja': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'スピーカー水抜き • 165Hz 音響洗浄',
      'language_menu_title': '言語を選択',
      'tips_tooltip': '使い方ガイド',
      'privacy_policy_btn': 'プライバシーポリシー',
      'usage_guide_btn': '水抜きのコツ',
      'top_tip': 'ヒント：音量を100%にし、スピーカーを下向きにして実行してください。',
      'cycles_badge': '{count}回',
      'center_start': '水抜き開始',
      'center_stop': '停止',
      'status_ready': 'スピーカー水抜き準備完了',
      'status_testing': '{test} 再生中 ({range})',
      'status_stage_1': 'ステップ 1/3：メッシュから水滴を分離中...',
      'status_stage_2': 'ステップ 2/3：音響圧力で水分を排出中...',
      'status_stage_3': 'ステップ 3/3：振動板を乾燥・安定化中...',
      'mode_section_title': '音響水抜きモード',
      'mode_standard_title': '標準 165Hz',
      'mode_standard_sub': '大きな水滴向け',
      'mode_sweep_title': '100–200Hz スイープ',
      'mode_sweep_sub': '全帯域クリーニング',
      'mode_pulse_title': '強力パルス',
      'mode_pulse_sub': '細かい水滴除去',
      'duration_section_title': 'カウントダウン時間',
      'duration_30s': '30秒',
      'duration_60s': '1分',
      'btn_start_eject': '今すぐ水抜きを開始',
      'btn_stop_eject': '水抜きを停止 ({time})',
      'test_section_title': 'スピーカーテスト • 音割れ確認',
      'btn_stop_test': '停止',
      'test_bass_label': '低音テスト',
      'test_bass_desc': 'ビビリ音確認',
      'test_treble_label': '高音テスト',
      'test_treble_desc': 'こもり音確認',
      'test_beep_label': 'ビープ音',
      'test_beep_desc': 'クリア度確認',
      'dialog_complete_title': '水抜きが完了しました！',
      'dialog_complete_body':
          '100%の振動サイクルが完了しました。スピーカー穴の水分を軽く拭き取り、「今すぐテスト」で音を確認してください。',
      'btn_close': '閉じる',
      'btn_test_now': '今すぐテスト',
      'ad_preview_badge': '広告 • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'スロットID：{slotId}\n水抜き完了時に全画面広告が自動表示されます。',
      'ad_close_continue': '閉じて結果を確認',
      'ad_banner_label': 'Huawei Petal バナー広告 • {slotId}',
      'tips_sheet_title': '効果を最大化する4つのポイント',
      'tip_step_1': 'イヤホンやBluetooth機器を解除し、本体スピーカーから音を出してください。',
      'tip_step_2': 'メディア音量を最大（100%）に設定してください。',
      'tip_step_3': '画面を下にするか、スピーカー口を下向きにして置いてください。',
      'tip_step_4': 'まず「標準 165Hz」を実行し、必要に応じて「100–200Hz スイープ」をお試しください。',
      'privacy_dialog_title': 'プライバシーポリシーと利用規約',
      'privacy_updated': '発効日：2026年10月21日',
      'privacy_dev_header': '1. 開発者情報',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nパッケージID：NGUYENMINHTHANH.WaterEjector\nHuawei App ID：119454967\n連絡先メール：alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK と OAID について',
      'privacy_ads_body':
          '本アプリは広告配信のため Huawei Petal Ads SDK（huawei_ads）を使用し、オープン広告ID（OAID）およびネットワーク状態を取得する場合があります。',
      'privacy_audio_header': '3. 音声出力のみ使用（マイク録音なし）',
      'privacy_audio_body':
          '本アプリはスピーカー清掃のための音声出力（Audio Output）のみを使用し、録音やマイクへのアクセスは一切行いません。',
      'privacy_disclaimer_header': '4. 免責事項',
      'privacy_disclaimer_body':
          '音響振動は表面の水分排出を補助するものであり、内部浸水による故障の修理を保証するものではありません。水没等によるハードウェア損傷について開発者は責任を負いません。',
      'privacy_rights_header': '5. データの権利と OAID オプトアウト方法',
      'privacy_rights_body':
          '端末の「設定 > プライバシー > 広告とプライバシー」からいつでも広告追跡の制限や OAID のリセットが可能です。お問い合わせ：alphaplus.thanh82@gmail.com',
      'btn_copy_email': 'サポートメールをコピー',
      'email_copied_toast': 'alphaplus.thanh82@gmail.com をコピーしました',
      'privacy_first_launch_intro':
          'ご利用前にプライバシーポリシーをご確認のうえ同意してください。Huawei Petal Ads（OAID）は同意後にのみ初期化されます。',
      'btn_accept_continue': '同意して続行',
      'btn_exit_app': '終了する',
    },

    // 9. GERMAN (Deutsch)
    'de': <String, String>{
      'app_title': 'Water Ejector',
      'app_subtitle': 'Lautsprecher-Reiniger • 165Hz',
      'language_menu_title': 'Sprache wählen',
      'tips_tooltip': 'Anleitung',
      'privacy_policy_btn': 'Datenschutz',
      'usage_guide_btn': 'Reinigungstipps',
      'top_tip':
          'Tipp: Lautstärke auf 100 % stellen und Lautsprecher nach unten richten.',
      'cycles_badge': '{count}x',
      'center_start': 'WASSER AUSWERFEN',
      'center_stop': 'STOPP',
      'status_ready': 'Bereit zur Lautsprecher-Reinigung',
      'status_testing': 'Wiedergabe: {test} ({range})',
      'status_stage_1': 'Phase 1/3: Wassertropfen vom Gitter lösen...',
      'status_stage_2': 'Phase 2/3: Wasser per Schalldruck ausstoßen...',
      'status_stage_3': 'Phase 3/3: Membran trocknen & stabilisieren...',
      'mode_section_title': 'Akustischer Reinigungsmodus',
      'mode_standard_title': 'Standard 165Hz',
      'mode_standard_sub': 'Große Tropfen',
      'mode_sweep_title': '100–200Hz Sweep',
      'mode_sweep_sub': 'Vollspektrum',
      'mode_pulse_title': 'Stark-Impuls',
      'mode_pulse_sub': 'Feiner Nebel',
      'duration_section_title': 'Countdown-Dauer',
      'duration_30s': '30 Sek.',
      'duration_60s': '1 Min.',
      'btn_start_eject': 'WASSERAUSWURF STARTEN',
      'btn_stop_eject': 'STOPPEN ({time})',
      'test_section_title': 'Lautsprecher-Test • Klang prüfen',
      'btn_stop_test': 'Stopp',
      'test_bass_label': 'Bass-Test',
      'test_bass_desc': 'Tiefton-Prüfung',
      'test_treble_label': 'Höhen-Test',
      'test_treble_desc': 'Hochton-Klarheit',
      'test_beep_label': 'Piepton-Test',
      'test_beep_desc': 'Reiner Prüfton',
      'dialog_complete_title': 'Reinigung abgeschlossen!',
      'dialog_complete_body':
          'Der Vibrationszyklus hat 100 % erreicht. Wischen Sie das Lautsprechergitter vorsichtig trocken und tippen Sie auf „Jetzt testen“.',
      'btn_close': 'Schließen',
      'btn_test_now': 'Jetzt testen',
      'ad_preview_badge': 'AD • HUAWEI PETAL ADS',
      'ad_interstitial_title': 'Huawei Interstitial Ad',
      'ad_interstitial_body':
          'Slot ID: {slotId}\nVollbildanzeige wird nach Abschluss des Reinigungszyklus automatisch eingeblendet.',
      'ad_close_continue': 'Schließen & Ergebnis anzeigen',
      'ad_banner_label': 'Huawei Petal Banner Ad • {slotId}',
      'tips_sheet_title': '4 Schritte für maximale Reinigung',
      'tip_step_1':
          'Trennen Sie Bluetooth- oder Kabelkopfhörer für die Lautsprecher-Ausgabe.',
      'tip_step_2':
          'Erhöhen Sie die Medienlautstärke auf 100 % für maximale Vibration.',
      'tip_step_3':
          'Legen Sie das Smartphone mit dem Display nach unten ab.',
      'tip_step_4':
          'Starten Sie zuerst „Standard 165Hz“ und danach bei Bedarf „100–200Hz Sweep“.',
      'privacy_dialog_title': 'Datenschutzerklärung & Bedingungen',
      'privacy_updated': 'Gültig ab: 21.10.2026',
      'privacy_dev_header': '1. Entwicklerangaben',
      'privacy_dev_body':
          'Developer Name: NGUYEN MINH THANH\nApp Name: Water Ejector: Speaker Cleaner\nPaket-ID: NGUYENMINHTHANH.WaterEjector\nHuawei App ID: 119454967\nKontakt-E-Mail: alphaplus.thanh82@gmail.com',
      'privacy_ads_header': '2. Huawei Petal Ads SDK & OAID',
      'privacy_ads_body':
          'Diese App nutzt das offizielle Huawei Petal Ads SDK (huawei_ads) und verarbeitet die Open Advertising ID (OAID) sowie den Netzwerkstatus ausschließlich zur Werbeauslieferung und Betrugsprävention.',
      'privacy_audio_header': '3. Nur Audioausgabe — Kein Mikrofonzugriff',
      'privacy_audio_body':
          'Die App verwendet ausschließlich die Audioausgabe (Audio Output) und zeichnet NIEMALS Audio auf und greift NICHT auf das Mikrofon zu.',
      'privacy_disclaimer_header': '4. Haftungsausschluss bei Wasserschäden',
      'privacy_disclaimer_body':
          'Schallwellen unterstützen das Entfernen oberflächlicher Feuchtigkeit und ersetzen keine Fachreparatur. Der Entwickler haftet nicht für tief eingedrungene Flüssigkeitsschäden.',
      'privacy_rights_header': '5. Betroffenenrechte & OAID-Widerspruch',
      'privacy_rights_body':
          'Sie können das Ad-Tracking jederzeit deaktivieren oder Ihre OAID zurücksetzen unter: Einstellungen > Datenschutz > Werbung und Datenschutz. Kontakt: alphaplus.thanh82@gmail.com.',
      'btn_copy_email': 'Support-E-Mail kopieren',
      'email_copied_toast': 'alphaplus.thanh82@gmail.com kopiert',
      'privacy_first_launch_intro':
          'Bitte lesen und akzeptieren Sie vor der Nutzung unsere Datenschutzerklärung. Huawei Petal Ads (OAID) startet erst nach Ihrer Zustimmung.',
      'btn_accept_continue': 'Akzeptieren & Weiter',
      'btn_exit_app': 'Beenden',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((Locale l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant _AppLocalizationsDelegate old) => false;
}
