# Yu-Gi-Oh! FM: Legend cho iOS

Mã nguồn đang nâng cấp từ iOS 0.3.3 lên cùng phạm vi tính năng với Android Ver 92. Bundle ID `vn.anhchugia35.legend` được giữ để tiếp tục dùng thư mục dữ liệu của bản iOS trước.

| Phần đối chiếu | Trạng thái |
| --- | --- |
| Dữ liệu Mod 2 | Mã C++ đã đối chiếu đủ 800 tên, mô tả gốc, ATK/DEF theo sân, ảnh và icon Attr/Type với bộ đọc Ver 92. Khớp danh sách Deck/Drop của 39 NPC, 17 Deck cố định và bảng Fusion cả 7 sân. |
| Deck/DropList | Mã UIKit đã dùng bộ đọc mới, tự tích 40 lá đã chia và đưa icon Attr/Type vào bốn tab danh sách bài. Cần thử cuộn, chọn NPC, tìm kiếm và xoay máy trên iPhone. |
| Tay cầm, phím tắt và tốc độ | Bố cục ngang/dọc dùng cùng vùng với Ver 92. Nút Speed, Sound, Save, Load nằm trên màn game. Speed chạm để bật/tắt và giữ để chọn. MODE bật/tắt nhận tay cầm. F1–F10 chọn công thức, F11 lưu, F12 tải. Mã bộ chọn đã kiểm tra bằng RAM thử với ID 799 và 800. |
| Mod 2 đi kèm, bảo vệ lưu và Quick Save/Load | Bản iOS cũ dùng file nhập và cơ chế lưu riêng. Cần chuyển luồng đóng gói, xác thực dữ liệu, bảo vệ số sao và đo tốc độ lưu/tải theo Ver 92. |
| VIP Chest/Deck, Tự soạn Deck | Mã dùng cùng hồ sơ nhận diện editor với Ver 92. Bản C++ chọn đúng 40 lá và chuỗi Fusion như Android trên cả 7 sân. Xếp Deck qua core thật trên Windows với dữ liệu riêng, xác nhận đủ 40 lá, bảo toàn số bản sở hữu và khôi phục khi giao dịch bị hủy. Giao diện UIKit cần chạy Apple SDK. |
| Gacha | Lõi C++ đã chạy Pack x1, x5 và x10 trên core riêng với SAVE thử. Đã kiểm tra phí, các ID trúng, lịch sử NEW, ghép vào Chest, SAVE gốc và khôi phục khi ghi lỗi. Cần nối vào giao diện iOS cùng âm xé túi, xoay pack, bụi vàng, xác thực gift code và sổ mã dùng một lần. |
| Auto | Cần thử cùng Mod 2 đi kèm sau khi cập nhật luồng đóng gói và kiểm tra trên iPhone. |

Kiểm thử Windows chạy Zig C++17 cho pixel, audio, bộ bấm tay cầm, 126 trường hợp bố cục và bộ đọc đĩa. Bộ kiểm tra trong `tests` đối chiếu với mã Android Ver 92 và chạy bộ giao dịch trên phiên SwanStation riêng. Đĩa, RAM, thẻ nhớ và dữ liệu đối chiếu để ở máy kiểm tra.

Lệnh Apple SDK hiện có là `python3 scripts/build_app.py --sdk iphoneos` và `python3 scripts/build_app.py --sdk iphonesimulator`. Workflow macOS đã dùng cho bản 0.3.3 nằm tại `.github/workflows/core-build.yml`. Chưa có bản IPA mới được cài hoặc kiểm tra trên iPhone.
