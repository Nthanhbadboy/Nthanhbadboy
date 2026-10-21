# Water Ejector: Speaker Cleaner (`NGUYENMINHTHANH.WaterEjector`)

Ứng dụng **Flutter Production-Ready** giúp đẩy nước khỏi màng loa điện thoại bằng sóng âm cộng hưởng **165Hz** và dải quét tần số **100Hz – 200Hz**, kết hợp bộ công cụ **Test Speaker (Bass / Treble / Beep)**, **Đa ngôn ngữ Quốc tế (9 ngôn ngữ)**, **Chính sách Bảo mật chuẩn Huawei AppGallery Connect**, và **Huawei Petal Ads SDK (`huawei_ads`)**.

---

## Thông tin Dự án & Nhà phát triển

| Thuộc tính | Giá trị |
| :--- | :--- |
| **Tên ứng dụng** | `Water Ejector: Speaker Cleaner` |
| **Package Name / Application ID** | `NGUYENMINHTHANH.WaterEjector` |
| **Nhà phát triển** | **Nguyen Minh Thanh** (`alphaplus.thanh82@gmail.com`) |
| **Nền tảng đích** | Android / HarmonyOS (**Huawei AppGallery**) |
| **Quảng cáo tích hợp** | **Huawei Petal Ads (`huawei_ads: ^13.4.72+300`)** — Banner Ad & Interstitial Ad |
| **Đa ngôn ngữ (9 Locales)** | `en` (Mặc định), `vi`, `zh`, `es`, `pt`, `ru`, `fr`, `ja`, `de` |
| **Chính sách Bảo mật** | `PRIVACY_POLICY.md`, `web/privacy_policy.html`, và Dialog xem trực tiếp trong App |

---

## Các tính năng cốt lõi

1. **Đa ngôn ngữ Quốc tế (9 Ngôn ngữ — `lib/l10n/app_localizations.dart`)**:
   - Hỗ trợ chuyển đổi tức thời (0ms reload) giữa 9 ngôn ngữ: **English (`en` - mặc định)**, **Tiếng Việt (`vi`)**, **简体中文 (`zh`)**, **Español (`es`)**, **Português (`pt`)**, **Русский (`ru`)**, **Français (`fr`)**, **日本語 (`ja`)**, **Deutsch (`de`)**.
2. **Giao diện Trực quan hóa Sóng âm 60 FPS (`WaveVisualizer`)**:
   - Đồ thị dao động sóng sin đa hài, vòng xung kích lan tỏa và hiệu ứng **hạt nước bắn văng khỏi màng loa** trực quan khi đang chạy.
3. **Chức năng Water Ejector & Test Speaker**:
   - **Standard 165Hz**, **100–200Hz Sweep**, và **Turbo Pulse** kèm bộ đếm ngược **30s / 1 phút** và thanh tiến trình.
   - **Test Bass (`65–110 Hz`)**, **Test Treble (`2.8–5.2 kHz`)**, và **Test Beep (`440–1320 Hz`)**.
4. **Huawei Petal Ads (`huawei_ads`) & AppGallery Privacy Compliance**:
   - `HwAds.init()` khởi tạo trong `main()`, **Banner Ad (`320x50`)** cố định ở đáy màn hình, **Interstitial Ad** tự động bung ra khi chu trình đẩy nước hoàn tất 100%.
   - Tích hợp sẵn **Dialog Privacy Policy & Terms** ngay trong ứng dụng và trang HTML tĩnh `web/privacy_policy.html` / `PRIVACY_POLICY.md` đầy đủ thông tin nhà phát triển, khai báo OAID, cam kết không truy cập Microphone, miễn trừ trách nhiệm phần cứng và quyền Opt-out OAID.
