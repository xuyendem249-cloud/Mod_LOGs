# Legend iOS 0.3 — đối chiếu Android 5 / Ver 16

Bản này là mã nguồn đang chờ Apple SDK build và chạy lại trên iPhone. Kết quả
build thành công cũ (#8, iOS 0.2) không xác minh giao diện hoặc game của 0.3.

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
