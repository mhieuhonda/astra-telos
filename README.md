# Astra Telos — Ứng dụng nhắn tin sang trọng

Tech stack: Flutter + Dart. Tương thích hoàn hảo: Android (7.1.1+), Windows, Linux.
Máy này làm server chính + database (SQLite) + storage (file cục bộ).

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

Mở app, nhập địa chỉ server (mặc định `http://127.0.0.1:8085`),
Đăng ký tài khoản mới rồi Đăng nhập. Tìm người dùng khác theo tên
hoặc tên tài khoản để bắt đầu trò chuyện realtime.
