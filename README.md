# Legend Player iOS 0.3

Chuyển các chức năng của Android 5 / Ver 16 sang iPhone 14, iOS 17.6.1.
Giữ nguyên Android, APK, BIOS, ISO và save người dùng.

**Mã nguồn 0.3 đã được tích hợp và kiểm tra phần C++/dữ liệu/hiệu ứng cục bộ.
Chưa được Apple SDK build hoặc chạy game trên iPhone với phiên bản 0.3.**
Lượt build #8 thuộc 0.2; người dùng đã cài được bản đó và báo đứng khi hạ bài.

## Có trong nguồn 0.3

- Sửa context/actor khi hạ bài; LP battle, 23 trap của mod và nhóm xuống sân
  phá bài. Mỗi lần chạy frame chỉ áp dụng trên đúng SHA game và chữ ký mã RAM.
- VIP: 40 NPC, Deck, SA POW, BCD POW, SA TECH, toàn bộ Fusion theo terrain;
  lọc ID/tên/nguyên liệu/kết quả; ảnh, mô tả có icon, 40 lá thực tế từ RAM.
- Fusion ba chế độ; thứ tự tối ưu 2–5 lá, giữ lựa chọn, nhận bài đã nâng,
  đánh số tại tọa độ bài và cảnh báo đổi thứ tự mạnh hơn.
- 10 slot lưu nhanh có checksum/core-version/backup; giữ thẻ .mcr cũ và cho
  tải state 0.2 ở slot 1. Nhập/xuất thẻ RAW 128 KB, xác nhận reset.
- Tốc độ 1/1.3/1.5/2/2.5/3/4×, âm lượng, đa chạm/D-pad chéo, bàn phím và
  tay cầm; hình gốc 4:3, âm thanh stereo, dọc/ngang theo safe area.
- Nền tím–đen gradient đậm, viền vàng và họa tiết rõ hơn, logo/welcome;
  license/mã nguồn trong cấu hình. Không có chức năng quay clip.

Chi tiết, bằng chứng và giới hạn từng chức năng: [PARITY.md](PARITY.md).

## Build và kiểm tra

Máy Mac/Xcode: `python3 scripts/build_app.py --sdk iphoneos` và tương tự
`iphonesimulator`; `python3 scripts/build_core.py --sdk macosx` chạy kiểm tra
pixel/input/audio, guard vá RAM, bố cục và API core.
`python3 scripts/simulator_smoke.py` kiểm tra khởi động và 14 nút.
Core lấy đúng commit trong sources.lock.json; không dùng JIT hay ký Apple.

Windows: `scripts/local_checks.py` kiểm tra nguồn/ARM64 syntax.
`tests/parity_test.cpp` so sánh với oracle cục bộ (ISO/RAM không đưa lên GitHub).
`scripts/test_native_effects.py` dùng DLL C++ patcher thực tế, chạy lại các
test trap/destruction PS1 load-delay. Báo cáo nằm trong build/native-effects.

Giữ tên artifact `Legend-Step2-*` để tương thích workflow hiện có. Xác minh
phiên bản trong Info.plist/app_build_report.json trước khi đóng gói IPA 0.3.
Source ZIP mới: `Legend-iOS-0.3-source.zip`. Không dùng IPA 0.2 làm bản sửa.

## Cài cập nhật

Build Apple phải thành công trước, sau đó IPA chưa ký cần ký bằng công cụ cá
nhân như cách đã cài 0.2. Giữ cùng Apple ID/bundle ID và cài đè; không xóa app
cũ để giữ BIOS/game/thẻ nhớ trong Documents/Legend. Không kèm ISO/BIOS/save,
khóa ký hoặc Apple ID trong nguồn/artifact. Chưa có TestFlight.
