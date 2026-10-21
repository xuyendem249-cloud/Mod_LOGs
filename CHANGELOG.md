# 0.3.0 (build 3) — nguồn đang chờ Apple SDK

- VIP/Fusion, 10 slot, cấu hình, thẻ nhớ và điều khiển theo Android 5.
- Chuyển bộ vá hạ bài/trap/LP và hiệu chỉnh địa chỉ owner khi xuống sân phá bài.
- Nền tím/đen và hoa văn/viền vàng rõ hơn.
- Kiểm tra C++ dữ liệu với oracle và replay native PS1 có load-delay.
- Chưa phát hành IPA 0.3; xem PARITY.md.

# Legend iOS

## Xác minh app bước 2 và đóng gói IPA chưa ký — 21/10/2026

- Lượt #8 thành công cả ba tác vụ, đã đọc artifact tải trên Desktop và đối chiếu CRC/SHA-256/Mach-O cùng báo cáo Simulator.
- Đóng gói IPA cho iPhone bằng binary đã build, giữ nguyên executable; tách dSYM khỏi payload cài đặt.
- Chưa ký/cài iPhone thật, chưa thử BIOS/game, chưa upload TestFlight. Người dùng chỉ có Apple ID miễn phí; chưa đăng ký hay mua Developer Program.

## Sửa liên kết CoreGraphics — 21/10/2026

- Log app iPhone và Simulator báo `ld: symbol(s) not found for architecture arm64`, có `kCGColorSpaceSRGB` và các hàm hình học/vẽ CoreGraphics.
- Thêm liên kết tường minh `-framework CoreGraphics` trong build_app.py cho cả hai SDK. Mã giao diện không đổi.
- Bản sửa trên máy chưa được chạy lại bằng Apple SDK.

## Sửa lỗi khai báo tọa độ nút bấm — 21/10/2026

- Lượt build số 3: portable-tests thành công; hai bản app cùng lỗi `property 'CGPointValue' not found on object of type 'id'` tại main.mm.
- Thay mảng NSArray không khai báo kiểu bằng mảng CGPoint tĩnh, giữ nguyên toàn bộ tọa độ và bố cục.
- Chưa chạy lại Apple SDK sau bản sửa này.

## Bước 2 — mã nguồn app UIKit, chờ build Apple — 21/10/2026

- Xác minh hai artifact bước 1 thành công; lưu lại thư viện và báo cáo, không đụng file trên Desktop.
- Thêm wrapper libretro tĩnh, bộ đệm âm thanh SPSC, chọn file bằng document picker, màn hình 4:3 và nút cảm ứng dọc/ngang.
- Thêm lưu/tải state và thẻ nhớ riêng theo SHA-256 game; không có quay clip, chưa có VIP/Fusion và bộ vá tương thích mod.
- Thêm script biên dịch UIKit và kiểm tra mở app Simulator. Workflow dùng lại core-build.yml, tên hiển thị đổi thành Step 2 app build.
- App mới chưa được build bằng Apple SDK; kiểm tra Windows không xác nhận app chạy được. Chưa có IPA ký hoặc TestFlight.

## Sửa lệnh kiểm thử Apple SDK — 21/10/2026

- GitHub run 39554205968: core iPhoneOS thành công; tác vụ macOS lỗi thiếu header C++ khi biên dịch test.
- Thêm `-isysroot` chỉ rõ SDK vào cả hai lệnh clang++ chạy test macOS.
- Bản sửa mới kiểm tra trên Windows, chưa được cập nhật lên GitHub hoặc chạy lại bằng Apple SDK.

## Bước 1 — 21/10/2026

- Tách workspace iOS, lấy Android 5 / Ver 16 làm mốc; iPhone 14/iOS 17.6.1.
- Chốt source core, thay đổi có kiểm tra để tạo static core không JIT và nhánh arena iOS dùng file tạm trong sandbox.
- Chuẩn bị primitive màu RGBA/input và test C++, API probe core không dùng BIOS/game.
- Thêm workflow macOS thủ công để kiểm tra core macOS và iPhoneOS ARM64; kèm nguồn tương ứng trong artifact.
- Kiểm tra Windows chỉ xác nhận nguồn/cú pháp, chưa xác nhận Apple SDK build, runtime iPhone, IPA hoặc TestFlight.
