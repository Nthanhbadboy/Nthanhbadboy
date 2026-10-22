# Privacy Policy — One-Line Physics Draw for Windows

**Applies to:** the Windows package `One-Line-Physics-Draw.msix` (Microsoft Store / MSIX) and the
portable `Physics-Draw-Windows.zip` build.
**Package identity:** `NGUYENMINHTHANH.52765D90C6EA8` · **Version:** 1.0.1.0 · **Publisher:** NGUYEN MINH THANH
**Effective date:** October 22, 2026

This policy covers the Windows builds only. The web and Android builds are covered by the
[general privacy policy](privacy-policy.md), which differs because those builds load libraries and
fonts from content delivery networks.

## At a glance

- No account, no sign-in, no personal information collected or transmitted.
- No advertising, no analytics, no telemetry, no crash reporting, no tracking identifiers.
- No in-app purchases and no payment data.
- The game is fully offline: the page, the physics engine, the icons and the fonts are bundled
  inside the package, so playing it makes no network request.
- Your progress never leaves the device.

## Information we collect

None. The Windows builds do not require an account and do not collect, transmit or sell personal
information. We do not collect names, email addresses, phone numbers, contacts, precise or
approximate location, photographs, microphone recordings, files, payment credentials, health data,
or advertising identifiers. There is no server operated by the developer that the app contacts.

## Information stored on your device

The game saves your own progress in a single browser-storage entry named
`oneLinePhysicsDrawState`, which holds unlocked levels, stars, hints used, the chosen language and
the sound preference. It is written by the game page and read back on the next launch. It is not
sent anywhere.

Where that entry lives:

| Build | Location | How to delete it |
| --- | --- | --- |
| MSIX package (`One-Line-Physics-Draw.msix`) | The WebView2 profile inside the package's own local state, managed by Windows | Settings → Apps → Installed apps → **One-Line Physics Draw** → Advanced options → **Reset**, or uninstall the app (Windows removes the package's local state) |
| Portable payload (`PhysicsDraw.exe` run unpackaged) | `%LOCALAPPDATA%\OneLinePhysicsDraw\WebView2` | Delete that folder |
| Portable launcher (`Physics-Draw.exe`) | Your default browser's local storage for the origin `http://127.0.0.1:4173` | Clear site data for that origin in your browser |

## Network access

The Windows builds make no network request while you play. `scripts/build-offline-html.mjs` inlines
Matter.js, Font Awesome, the Short Stack and Patrick Hand fonts and the favicon into the single
`www/index.html` file that ships in the package, and the build fails if any remote reference
survives; the packaged page is additionally audited on every build for CDN host names and for
remote `<script>`, `<link>` and `<img>` tags.

There is exactly one network-related behaviour, and it is yours to trigger: if the Microsoft Edge
WebView2 Runtime is missing, the app shows a dialog explaining this and asks whether to open
Microsoft's WebView2 download page. Nothing is opened unless you choose **Yes**, and the opening
happens in your own default browser — the app itself transmits no data.

The bundled licence notices contain the URLs `fontawesome.com`, `fontawesome.com/license/free` and
`brm.io/matter-js/` as plain attribution text. No request is made to them.

## Bundled third-party components

These are copied into the package at build time, so their publishers receive nothing when you play:

| Component | Licence | Purpose |
| --- | --- | --- |
| Matter.js 0.19.0 | MIT | 2D physics simulation |
| Font Awesome Free 6.5.2 (solid) | Icons CC BY 4.0, fonts SIL OFL 1.1, code MIT | Interface icons |
| Short Stack, Patrick Hand | SIL Open Font License 1.1 | Interface fonts, including the Vietnamese subset |

## Microsoft Edge WebView2 Runtime

The MSIX build renders the game through the Microsoft Edge WebView2 Runtime, a Microsoft component
that ships with Windows 11 and is installed with Microsoft Edge on Windows 10. The runtime is
provided and governed by Microsoft, not by this app, and it is covered by the
[Microsoft Privacy Statement](https://privacy.microsoft.com/privacystatement). The app configures
the runtime to load only the bundled local page, disables browser zoom and the status bar, and
requests no browsing data. Any diagnostics the runtime or Windows itself may produce are controlled
in Windows (Settings → Privacy & security → Diagnostics & feedback), not by this app.

## Permissions and capabilities

`AppxManifest.xml` declares a single capability, `runFullTrust`, which every packaged desktop
(Win32) app requires in order to run its own executable. The package declares no capability for
location, camera, microphone, contacts, calendar, phone calls, the documents/pictures/music
libraries, user account information, or network communication. The embedded application manifest
requests `asInvoker` execution, so the app never asks for administrator rights.

## Data retention and security

Because there is no server, there is nothing to retain, back up, breach or delete on our side.
Your progress stays in your Windows user profile until you reset or uninstall the app.

Packages submitted to the Microsoft Store are re-signed by Microsoft, and the MSIX format verifies
the SHA-256 hash of every 64 KiB block of every file at install time and while the app is
installed, so a modified package will not install or run.

## Children's privacy

The app does not knowingly collect personal information from anyone, including children. There is
no registration, no profile, no messaging, no user-generated content shared with others and no
advertising. Because nothing is collected, there is nothing for a parent or guardian to request
access to or deletion of, and no data is shared with third parties for any purpose.

## Your privacy rights

There is no server-side personal data to export, correct or erase. You can remove everything the
app stores on your device at any time using the Reset option or by uninstalling it (see the table
above). For questions or privacy requests, contact the developer through the
[repository issue tracker](https://github.com/Nthanhbadboy/Nthanhbadboy/issues).

## Changes to this policy

If a future release adds anything that changes these facts — accounts, cloud saves, advertising,
in-app purchases, analytics, or a network feature — this page will be updated before that release
ships and the effective date above will change.

## Tiếng Việt — tóm tắt

Bản Windows (gói `.msix` cho Microsoft Store và bản portable `.zip`) **không thu thập bất kỳ thông
tin cá nhân nào**: không tài khoản, không đăng nhập, không quảng cáo, không phân tích, không telemetry,
không mua hàng trong ứng dụng. Trò chơi chạy **hoàn toàn ngoại tuyến** — trang game, thư viện vật lý
Matter.js, icon và font chữ đều được nhúng sẵn trong gói, nên quá trình chơi không tạo ra một yêu cầu
mạng nào.

Tiến trình chơi (màn đã mở, số sao, gợi ý đã dùng, ngôn ngữ, âm thanh) được lưu **trên máy bạn** trong
kho khoá `oneLinePhysicsDrawState` và không bao giờ được gửi đi đâu. Gỡ ứng dụng, hoặc dùng
**Settings → Apps → One-Line Physics Draw → Advanced options → Reset**, sẽ xoá toàn bộ dữ liệu đó.

Trường hợp duy nhất liên quan đến mạng: nếu máy thiếu **Microsoft Edge WebView2 Runtime**, ứng dụng sẽ
hiện hộp thoại hỏi bạn có muốn mở trang tải của Microsoft hay không — chỉ khi bạn bấm **Yes** thì
trang đó mới mở, và mở bằng trình duyệt của bạn; ứng dụng không tự gửi dữ liệu nào.

Thành phần WebView2 Runtime là của Microsoft và chịu sự điều chỉnh của
[Tuyên bố về quyền riêng tư của Microsoft](https://privacy.microsoft.com/privacystatement). Mọi câu hỏi
xin gửi qua [issue tracker của repository](https://github.com/Nthanhbadboy/Nthanhbadboy/issues).

---

Contact: [github.com/Nthanhbadboy/Nthanhbadboy](https://github.com/Nthanhbadboy/Nthanhbadboy) ·
[Issue tracker](https://github.com/Nthanhbadboy/Nthanhbadboy/issues)
