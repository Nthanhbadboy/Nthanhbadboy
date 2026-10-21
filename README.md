# Water Ejector: Speaker Cleaner (`NGUYENMINHTHANH.WaterEjector`)

Ứng dụng **Flutter Production-Ready** giúp đẩy nước khỏi màng loa điện thoại bằng sóng âm cộng hưởng **165Hz** và dải quét tần số **100Hz – 200Hz**, kết hợp bộ công cụ **Test Speaker (Bass / Treble / Beep)** và tích hợp hoàn chỉnh **Huawei Petal Ads SDK (`huawei_ads`)** tối ưu hóa cho **Huawei AppGallery**.

---

## Thông tin Dự án

| Thuộc tính | Giá trị |
| :--- | :--- |
| **Tên ứng dụng** | `Water Ejector: Speaker Cleaner` |
| **Package Name / Application ID** | `NGUYENMINHTHANH.WaterEjector` |
| **Nền tảng đích** | Android (Tối ưu hóa cho **Huawei AppGallery** & **HMS Core**) |
| **Quảng cáo tích hợp** | **Huawei Petal Ads (`huawei_ads: ^13.4.72+300`)** — Banner Ad & Interstitial Ad |
| **Engine Âm thanh** | DSP PCM 16-bit 44.1kHz thời gian thực (`audioplayers` + `BytesSource`) |

---

## Các tính năng cốt lõi

1. **Giao diện Trực quan hóa Sóng âm 60 FPS (`WaveVisualizer`)**:
   - Đồ thị dao động sóng sin đa hài (Multi-harmonic Sine Oscilloscope), vòng xung kích lan tỏa và hiệu ứng **hạt nước bắn văng khỏi màng loa** trực quan khi đang chạy.
   - Nút kích âm lượng nhanh lên **100% (`AudioManager.STREAM_MUSIC`)** và giữ sáng màn hình (`FLAG_KEEP_SCREEN_ON`) trong suốt quá trình đẩy nước.
2. **Chức năng Water Ejector chuyên sâu**:
   - **Chuẩn 165Hz (`Standard 165Hz`)**: Sóng sin cộng hưởng vàng 165.0Hz kết hợp điều biến áp suất đẩy giọt nước lớn khỏi lưới loa.
   - **Quét dải tần `100Hz – 200Hz` (`Auto Frequency Sweep`)**: Quét pha liên tục `100Hz ↔ 200Hz` kích thích toàn bộ dải cộng hưởng cơ học của loa ngoài.
   - **Xung Mạnh (`165Hz Deep Pulse`)**: Xung áp suất ngắt nhịp 4Hz giúp giũ sạch các hạt sương mịn bám dính.
   - Tùy chọn bộ đếm ngược **30 Giây (`00:30`)** hoặc **1 Phút (`01:00`)** kèm thanh tiến trình (`LinearProgressIndicator` & vòng tròn tiến độ).
3. **Chức năng Test Speaker (Kiểm tra loa sau khi vệ sinh)**:
   - **Test Bass (`65–110 Hz`)**: Kiểm tra dải trầm phát hiện rè màng loa.
   - **Test Treble (`2.8–5.2 kHz`)**: Kiểm tra âm cao phát hiện nghẹt lưới loa.
   - **Test Beep (`440–1320 Hz`)**: Phát chuỗi Beep chuẩn kiểm tra độ trong trẻo tổng thể.
4. **Tích hợp Huawei Petal Ads (`huawei_ads`)**:
   - Khởi tạo `await HwAds.init()` & `HwAds.setRequestOptions(...)` ngay trong `main()`.
   - Hiển thị **Banner Ad (`320x50`)** neo cố định gọn gàng ở đáy màn hình chính (`bottomNavigationBar`).
   - Tự động tải trước (preload) và bung **Interstitial Ad (Quảng cáo toàn màn hình)** ngay khi chu trình đẩy nước hoàn tất 100%, đồng thời tự nạp lại cho lượt tiếp theo.

---

## Cấu trúc Thư mục Chính

```text
├── android/
│   ├── build.gradle                     # Cấu hình Huawei Maven Repo & đồng bộ namespace plugin HMS
│   ├── settings.gradle                  # Khai báo Flutter Plugin Loader, AGP & Huawei Repo
│   └── app/
│       ├── build.gradle                 # applicationId = "NGUYENMINHTHANH.WaterEjector" & HMS Ads dependencies
│       ├── proguard-rules.pro           # Quy tắc R8/ProGuard giữ nguyên class HMS Core & Petal Ads
│       └── src/main/
│           ├── AndroidManifest.xml      # Quyền mạng, âm thanh, queries cho HMS Core (com.huawei.hwid)
│           └── kotlin/NGUYENMINHTHANH/WaterEjector/MainActivity.kt
├── lib/
│   ├── main.dart                        # Khởi tạo HwAds.init(), Provider & MaterialApp
│   ├── providers/
│   │   └── water_ejector_provider.dart  # State management điều phối chu trình đẩy nước & Test Speaker
│   ├── screens/
│   │   └── home_screen.dart             # Giao diện chính, Banner Ad & tự động bung Interstitial Ad
│   ├── utils/
│   │   └── sound_generator.dart         # Bộ tổng hợp sóng âm WAV 165Hz, Sweep 100-200Hz, Bass/Treble/Beep
│   └── widgets/
│       └── wave_visualizer.dart         # Hiệu ứng sóng âm & giọt nước 60 FPS bằng CustomPainter
└── pubspec.yaml
```

---

## Hướng dẫn Chạy & Đóng gói phát hành lên Huawei AppGallery

```bash
# 1. Cài đặt các gói phụ thuộc
flutter pub get

# 2. Kiểm tra mã nguồn & chạy test
flutter analyze
flutter test

# 3. Build APK Release cho Huawei AppGallery
flutter build apk --release
```

### Checklist trước khi Upload lên Huawei AppGallery Connect:
1. Tải file `agconnect-services.json` từ dự án `NGUYENMINHTHANH.WaterEjector` trên **AppGallery Connect** và đặt vào thư mục `android/app/agconnect-services.json` (`android/app/build.gradle` sẽ tự động kích hoạt plugin `com.huawei.agconnect`).
2. Mở `lib/screens/home_screen.dart` (lớp `HuaweiAdsConfig`) và thay 2 mã Test Slot ID (`testw6vs28auh3` và `testb4znbuh3n2`) bằng **Slot ID thật** tạo trên **Huawei Petal Publisher Center**.
