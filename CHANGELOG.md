# Legend iOS

## Bước 1 — 21/10/2026

- Tách workspace iOS, lấy Android 5 / Ver 16 làm mốc; iPhone 14/iOS 17.6.1.
- Chốt source core, thay đổi có kiểm tra để tạo static core không JIT và nhánh arena iOS dùng file tạm trong sandbox.
- Chuẩn bị primitive màu RGBA/input và test C++, API probe core không dùng BIOS/game.
- Thêm workflow macOS thủ công để kiểm tra core macOS và iPhoneOS ARM64; kèm nguồn tương ứng trong artifact.
- Kiểm tra Windows chỉ xác nhận nguồn/cú pháp, chưa xác nhận Apple SDK build, runtime iPhone, IPA hoặc TestFlight.
