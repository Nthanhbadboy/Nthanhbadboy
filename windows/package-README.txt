One-Line Physics Draw - Windows offline build
Bản Windows chạy offline (không cần Internet, không cần cài đặt)

QUICK START / CHẠY NGAY
1. Unzip this folder anywhere you like (Desktop is fine).
   Giải nén thư mục này ra bất kỳ đâu (ngoài màn hình Desktop cũng được).
2. Double-click Physics-Draw.exe
   Nhấp đúp vào Physics-Draw.exe
3. A small console window opens and your default browser shows the game.
   Keep that console window open while you play; close it to quit.
   Một cửa sổ dòng lệnh nhỏ hiện ra và trình duyệt mặc định sẽ mở trò chơi.
   Hãy giữ cửa sổ đó trong lúc chơi; đóng lại khi muốn thoát.

If Windows SmartScreen says "Windows protected your PC":
  click "More info" -> "Run anyway". The file is unsigned, that is the only reason.
Nếu SmartScreen báo "Windows protected your PC":
  bấm "More info" -> "Run anyway". File chưa có chữ ký số, chỉ vì lý do đó.

NO INTERNET NEEDED / KHÔNG CẦN MẠNG
The page, Matter.js, the icons and the fonts are compiled into Physics-Draw.exe.
Toàn bộ trang game, thư viện Matter.js, icon và font chữ đã nằm sẵn trong file .exe.

SAVED PROGRESS / TIẾN TRÌNH ĐƯỢC LƯU
The launcher serves the game at http://127.0.0.1:4173/ so your browser can store
unlocked levels, stars, hints and language (Chromium browsers refuse to save data for
files opened straight from disk). Progress belongs to that address, so use the same port
each time - the launcher always tries 4173 first.
Trò chơi được chạy qua http://127.0.0.1:4173/ để trình duyệt lưu được các màn đã mở,
sao, gợi ý và ngôn ngữ (trình duyệt họ Chromium không cho lưu dữ liệu với file mở trực
tiếp từ ổ đĩa). Hãy giữ nguyên cổng mặc định 4173 để không mất tiến trình.

COMMAND LINE / TUỲ CHỌN DÒNG LỆNH
  Physics-Draw.exe --port 4300        serve on another port / chạy ở cổng khác
  Physics-Draw.exe --no-browser       start the server but do not open a browser
  Physics-Draw.exe --print-url        print the address and exit / chỉ in địa chỉ
  Physics-Draw.exe --extract game.html  write the embedded page to a file
                                      (then open game.html in any browser; note that
                                      Chromium will not save progress for file:// pages)
  Physics-Draw.exe --help             all options / xem toàn bộ tuỳ chọn

FALLBACK / NẾU EXE KHÔNG CHẠY
index.html in this folder is the exact same offline build. Double-click it to play in any
browser, or copy it to a phone/PC without this launcher. Antivirus or group policy can
block unsigned executables; the HTML file has no such problem.
index.html trong thư mục này chính là bản offline đó. Nhấp đúp để chơi bằng trình duyệt
bất kỳ, hoặc chép sang máy khác. Một số phần mềm diệt virus/chính sách công ty có thể
chặn file .exe chưa ký; file HTML thì không bị.

REQUIREMENTS / YÊU CẦU
Windows 10 or newer, 64-bit. No installation, no admin rights, no runtime to download.
Windows 10 trở lên, 64-bit. Không cần cài đặt, không cần quyền admin.

The launcher only listens on 127.0.0.1 (your own PC). Nothing is reachable from the
network and nothing is sent anywhere.
Launcher chỉ lắng nghe trên 127.0.0.1 (máy của bạn). Không máy nào khác truy cập được
và không có dữ liệu nào được gửi ra ngoài.
