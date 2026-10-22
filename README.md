# Legend Player iOS 0.3.3 (build 6)

Phóng lớn logo Auto ở cả dọc/ngang, cắt hình tròn hoàn toàn bằng giao diện, giữ nguyên ảnh và viền xoay. Đang chờ Apple SDK/Simulator xác minh; chưa có IPA 0.3.3.

## Bản 0.3.2 (build 5)

Bổ sung Auto như Android 8/Ver19, viền logo xoay và tự tắt sau thắng/thua. Dời logo lên thanh Fusion/Lưu/Tải ở cả hai hướng; thêm nút tốc độ đồng bộ ở vị trí logo dọc cũ; tối đa chiều cao game ngang trong safe area, giữ 4:3.

Auto C++ đã qua replay native core riêng với trace trùng Android trong bốn kịch bản (trọn trận, Trap, equip, phòng thủ). Bố cục qua 126 kích thước/chế độ. Apple SDK cho iPhone/Simulator và kiểm tra giao diện dọc/ngang đã qua cả ba job. Đã đóng gói IPA 0.3.2 chưa ký; chưa thử gameplay trên iPhone thật. Xem [CAI_DAT_0.3.2.md](CAI_DAT_0.3.2.md).

Lượt 0.3.2: https://github.com/xuyendem249-cloud/Mod_LOGs/actions/runs/39703895976
Commit: `57d12e00e5ed1fc014cdb7780c52ee0f1eca8464`.
IPA: `build/LegendPlayer-iOS-0.3.2-unsigned.ipa`.
SHA-256: `3a110281a3cebd98cf9c9744f70d3c8a9a8c92c699b831b8e4857e2fc138337f`.
Báo cáo: `build/verified-0.3.2.json`.

## Bản 0.3.1 trước đó

Đồng bộ sửa tên bài và đánh x2/x3 từ PC Ver 12, cùng Android 6 / Ver 17, cho iPhone 14, iOS 17.6.1. Giữ các chức năng của iOS 0.3; không thêm tool gian lận hoặc sửa BIOS, ISO, save người dùng.

Nền mới Trò chơi Ngàn năm đã được người dùng xem và duyệt: kim tự tháp/Con mắt Ngàn năm vàng trên đền Ai Cập tím đen, không có chữ AI. Ảnh chỉ dùng cho nền app iOS, nằm dưới vùng game và các nút; tự căn dọc/ngang.

**0.3.1 đã build Apple SDK và qua kiểm tra Simulator ở cả ba tác vụ. Đã xác minh nguồn/tài nguyên, nền mới và đóng gói IPA chưa ký; chưa chạy BIOS/game bản mới trên iPhone thật.**

Lượt 0.3.1: https://github.com/xuyendem249-cloud/Mod_LOGs/actions/runs/39650587896
Commit nguồn: `874ecf87ce8127e9aed2537c0409a0864f978bce`.
IPA đã kiểm chứng: `build/LegendPlayer-iOS-0.3.1-unsigned.ipa`.
Báo cáo: `build/verified-0.3.1.json`. Xem `CAI_DAT_0.3.1.md` để cài cập nhật.
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
phiên bản trong Info.plist/app_build_report.json trước khi đóng gói IPA 0.3.2.
Source ZIP mới: `Legend-iOS-0.3.2-source.zip`. Không dùng IPA 0.2 làm bản sửa.

## Cài cập nhật

Build Apple phải thành công trước, sau đó IPA chưa ký cần ký bằng công cụ cá
nhân như cách đã cài 0.2. Giữ cùng Apple ID/bundle ID và cài đè; không xóa app
cũ để giữ BIOS/game/thẻ nhớ trong Documents/Legend. Không kèm ISO/BIOS/save,
khóa ký hoặc Apple ID trong nguồn/artifact. Chưa có TestFlight.

Hướng dẫn cài đè: [CAI_DAT_0.3.1.md](CAI_DAT_0.3.1.md).

IPA SHA-256: `f32fc82b835e0667a9ed0208ee47895e49e5c41e6bf3b14d186cac5e493a66b0`.
