# Astra Telos — Ứng dụng nhắn tin cho mọi người

Tech stack: Flutter + Dart. Chạy trên Android (7.1.1+), Windows, Linux.
Người dùng chỉ cần cài app, đăng ký bằng số điện thoại là nhắn tin được ngay,
giống Messenger/Zalo — không cần biết gì về máy chủ.

Hạ tầng đám mây Astra Telos (server + SQLite + storage) do đội ngũ vận hành,
app tự kết nối sẵn, người dùng không phải nhập địa chỉ server.

## Trải nghiệm người dùng

- Đăng ký / đăng nhập bằng số điện thoại + mật khẩu
- 3 tab quen thuộc: Tin nhắn · Danh bạ · Hồ sơ
- Nhắn tin realtime, xem "đang nhập...", gửi ảnh/tệp, báo đã xem
- Giao diện vàng sang trọng trên nền đen, toàn bộ tiếng Việt

## Cấu trúc

```
astra_telos/
  server/            Máy chủ Dart (chạy trên máy này)
    bin/server.dart  Điểm khởi động
    lib/             database, auth, api, realtime, storage
    data/            Sinh ra khi chạy: astra.db + files/
  app/               Ứng dụng Flutter đa nền tảng
    lib/             main, theme, core, screens
```

## Chạy server (máy này)

```bash
cd astra_telos/server
/opt/flutter/bin/dart pub get
ASTRA_PORT=8085 /opt/flutter/bin/dart run bin/server.dart
```

Server lắng nghe `http://0.0.0.0:8085`, WebSocket realtime tại `/ws`,
file đính kèm tại `/files/...`, kiểm tra sức khỏe tại `/health`.

## Chạy app

```bash
cd astra_telos/app
/opt/flutter/bin/flutter pub get

# Linux (máy này, cần màn hình)
/opt/flutter/bin/flutter run -d linux

# Windows (trên máy Windows, cài Flutter rồi chạy)
/opt/flutter/bin/flutter run -d windows

# Android (APK, minSdk 25 = Android 7.1.1)
/opt/flutter/bin/flutter build apk --release
```

File `android/app/build.gradle` đã cấu hình `minSdk 25`, `targetSdk 34`,
tên app "Astra Telos", Material 3 + font Be Vietnam Pro, giao diện vàng
sang trọng trên nền đen, toàn bộ tiếng Việt.

## Tài khoản

Mở app → Đăng ký bằng số điện thoại → Đăng nhập.
Tìm bạn bè bằng số điện thoại hoặc tên để bắt đầu trò chuyện realtime.

## Dành cho nhà phát triển

Địa chỉ đám mây được gắn sẵn trong `app/lib/core.dart` (lớp `Cloud`).
Muốn tự host: chạy `server/` bằng `dart run bin/server.dart`,
rồi đổi `Cloud.baseUrl` thành địa chỉ của bạn và build lại app.
