# Legend Player iOS 0.3.1

Đồng bộ sửa tên bài và đánh x2/x3 từ PC Ver 12, cùng Android 6 / Ver 17, cho iPhone 14, iOS 17.6.1. Giữ các chức năng của iOS 0.3; không thêm tool gian lận hoặc sửa BIOS, ISO, save người dùng.

**0.3.1 đang chờ build Apple SDK và kiểm tra Simulator; không coi lượt build 0.3 cũ là kết quả của bản này. Chưa chạy game bản mới trên iPhone thật.**

Lượt 0.3 cũ: https://github.com/xuyendem249-cloud/Mod_LOGs/actions/runs/39609329020
Tên IPA mới sau khi build/kiểm chứng: `build/LegendPlayer-iOS-0.3.1-unsigned.ipa`.
Báo cáo mới sẽ là `build/verified-0.3.1.json`. Xem `CAI_DAT_0.3.1.md` để cài cập nhật.
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

Hướng dẫn cài đè: [CAI_DAT_0.3.md](CAI_DAT_0.3.md).
