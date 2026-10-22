# Bổ sung iOS 0.3.2

Auto theo Android 8/Ver19 đã chuyển sang C++ và chạy qua cùng native core oracle, trace trùng từng bước ở bốn kịch bản. Điều khiển thật gửi qua mask nguyên tử riêng, người chơi chạm nút sẽ tắt Auto; không sửa trạng thái game. Nút tốc độ và Cấu hình dùng chung bộ giá trị/formatter. Bản này vẫn cần kiểm tra Apple SDK và gameplay iPhone sau cài.

# iOS 0.3.1 — bổ sung sau Android 6 / Ver 17

Bản 0.3.1 build 4 đã qua Apple SDK và Simulator ở run 39650587896, commit 874ecf87ce8127e9aed2537c0409a0864f978bce. Bổ sung hai sửa lỗi tên bài/x2/x3 của PC Ver12 và nền Trò chơi Ngàn năm được duyệt. Ảnh nền đóng trong IPA khớp byte với nguồn và Simulator đã báo tải thành công. Chưa kiểm tra chơi game/BIOS trên iPhone thật; IPA cần ký lại bằng Sideloadly. Auto mới của Android 8 chưa được yêu cầu chuyển sang iOS.

# Legend iOS 0.3 — đối chiếu Android 5 / Ver 16

Bản 0.3 đã build Apple SDK và chạy smoke trong Simulator thành công: https://github.com/xuyendem249-cloud/Mod_LOGs/actions/runs/39609329020 .
Cả ba job xanh, 19 file nguồn/tài nguyên khớp artifact, binary ARM64 iOS 17.
Game/animation/hiệu năng vẫn cần chạy lại trên iPhone thật.

| Chức năng Android | Phần chuyển sang iOS 0.3 | Kiểm tra hiện có |
|---|---|---|
| Mở ISO/BIN/IMG, BIOS 512 KB | Tệp iOS, nhập có SHA-256, dữ liệu trong Documents/Legend | Review nguồn; cần chạy iPhone |
| Interpreter/Software, màu gốc 4:3 | Core tĩnh, đổi pixel rõ RGBA, AVAudioEngine | Test pixel/audio/input; 126 kích thước bố cục |
| Hạ bài không đứng | Sửa context và actor load-delay trước mỗi retro_run | Guard mã/SHA; cần lặp tình huống clip trên iPhone |
| Trap của mod | Đủ 39 hook, 2 vùng mã, delay-safe và giữ điều kiện kích hoạt | C++ iOS thực tế: 23 trap, 1150 vị trí tấn công, 72 thuộc tính, 46 công thức LP, 66 Magic/Equip |
| Xuống sân phá bài | Sửa owner của helper, giữ nhánh chọn phía sân | C++ iOS thực tế: 100 scan + 100 repeat guard, cả hai phía, giữ bài mình và miễn nhiễm |
| VIP Deck/SA POW/BCD POW/SA TECH | 40 NPC, portrait, follow NPC, 40 lá thực tế, lọc ID/tên, tỷ lệ trọng số /2048 | 115520 trọng số khớp oracle, mapping NPC40→0 |
| Toàn bộ Fusion | Bảng đúng terrain, tìm cả nguyên liệu/kết quả, ảnh và mô tả | Khớp cả 7 bảng; kiểm tra 210368 pixel |
| Fusion tắt/số/số+bảng | Đánh số tại tọa độ bài, giữ route được chọn, tôn trọng bài nâng, gợi ý đổi thứ tự mạnh hơn | Khớp RAM thực tế, 850 bonus cases, 4950 so với 4450 và cảnh báo +500 |
| Điều khiển | 14 nút, Select trừ, Start tam giác, D-pad trượt/chéo, multitouch, phím và tay cầm | C++ input; bố cục dọc/ngang; cần thử phần cứng iPhone |
| 10 slot, tốc độ, âm lượng | 10 slot/checksum/core-version/backup; 1/1.3/1.5/2/2.5/3/4×; volume | Review nguồn; cần test UI/save với core trên Apple |
| Nhập/xuất thẻ 128 KB, reset | Xác nhận, backup, MC signature, ghi định kỳ 10s/ra nền | Review nguồn; giữ nguyên tên thẻ iOS 0.2 và legacy state ở slot 1 |
| Giao diện tím/vàng, logo, giấy phép | Nền gradient đậm, viền/glyph vàng rõ, welcome/logo, trình đọc license | Cần kiểm tra giao diện bằng Simulator/iPhone |

## Hiệu chỉnh khi chuyển bộ vá

`legend_android/assets/compat.json` xuất nhóm destruction với địa chỉ ghi
`0xb1dc`, lệch +8 so với helper đã kiểm tra ở `0xb1d4`. Replay C++ đã tái hiện
phá sai phía/không phá phía cần phá. Bộ sinh iOS sửa địa chỉ thành `0xb1d4`,
giữ nguyên BEQ ở `0xb1e0`; replay sau sửa qua toàn bộ 100 tình huống.
Đây là hiệu chỉnh riêng iOS. Không thay đổi thư mục Android, APK hoặc ISO.

## Giới hạn kiểm tra

Replay chạy mã MIPS thực với load-delay/branch-delay, không thay thế thử animation,
âm thanh và cả ván đấu trên iPhone. Fixture ISO/RAM chỉ đọc cục bộ; không nằm
trong bundle nguồn, commit, CI hoặc IPA. Giữ app cũ khi cài cập nhật để giữ BIOS,
game và thẻ nhớ. Bản IPA mới phải được build/kiểm tra rồi ký lại trước khi cài.
