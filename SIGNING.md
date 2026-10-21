# Ký APK release bằng keystore thật

Không commit file keystore hoặc mật khẩu vào Git. Keystore là chìa khóa cập nhật ứng dụng; mất nó sẽ không thể phát hành bản update cùng application ID.

## 1. Tạo keystore một lần

Có thể dùng Android Studio: **Build > Generate Signed Bundle / APK > Create new**.

Hoặc dùng `keytool`:

```bash
keytool -genkeypair -v \
  -keystore physics-draw-release.jks \
  -storetype JKS \
  -alias physicsdraw \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Lưu file `.jks` ở nhiều nơi an toàn, cùng với:

- Keystore password
- Key alias: `physicsdraw`
- Key password

Không đưa các giá trị này vào chat và không commit `.jks`.

## 2. Đưa keystore vào GitHub Actions Secrets

Mở **Repository > Settings > Secrets and variables > Actions** và tạo bốn secret:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Mã hóa file keystore thành một chuỗi base64.

Linux/macOS:

```bash
base64 -w 0 physics-draw-release.jks > physics-draw-release.jks.base64
```

Nếu `base64 -w` không có:

```bash
base64 physics-draw-release.jks | tr -d '\n' > physics-draw-release.jks.base64
```

Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("physics-draw-release.jks")) | Set-Content physics-draw-release.jks.base64
```

Dán nội dung file `.base64` vào `ANDROID_KEYSTORE_BASE64`; dán các mật khẩu vào đúng secret tương ứng. Xóa file `.base64` sau khi lưu.

## 3. Chạy build

Workflow `.github/workflows/android-build.yml` sẽ:

1. Dùng keystore thật nếu cả bốn secret tồn tại.
2. Build `huaweiRelease`, `amazonRelease`, và `samsungRelease`.
3. Chạy `apksigner verify`.
4. Upload artifact `physics-draw-release-apks`.

Nếu chưa có đủ secrets, CI sẽ dừng trước bước build release và không tạo hoặc upload APK Android nào. Workflow không sinh key tạm và không chấp nhận APK unsigned cho phát hành.

## 4. Trước khi upload store

- Giữ nguyên `applicationId` và dùng đúng keystore cho các bản update.
- Tăng `versionCode` ở mỗi bản phát hành.
- Đảm bảo Ads/IAP đã dùng SDK thật và receipt được xác minh.
- Build flavor đúng store, không dùng test/mock payment.
- Lưu lại SHA-256 và kiểm tra chữ ký APK trước khi upload.
