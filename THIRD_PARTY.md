# Mã nguồn bên thứ ba

Core: SwanStation, https://github.com/libretro/swanstation/tree/cc94ebcd38a88a0e90788d7c8bcd764a009a5fa0 . Nguồn upstream có giấy phép GNU GPL v3 ở `LICENSE`; các thư viện kèm core giữ thông báo/giấy phép riêng tại nguồn.

`scripts/prepare_core.py` tải đúng commit và ghi từng thay đổi với SHA256 trước/sau ở `build/core_patch_report.json`. Thư mục vendor không nằm trong gói tải lên GitHub: workflow tự lấy từ upstream công khai.

Artifact thư viện tạo bởi workflow bao gồm `SwanStation_LICENSE.txt` và `CorrespondingSource.tar.gz` chứa nguồn core đã chỉnh. Các script build/patch/frontend được giữ trong repository/gói nguồn. Khi phát hành một app iOS hoàn chỉnh, phải xử lý các nghĩa vụ giấy phép của app/core trước khi phân phối; gói hiện tại không tuyên bố đã giải quyết việc phát hành TestFlight/App Store.

Không có thư viện Android `.so` hoặc Windows `.dll`, ISO/BIOS/save người dùng trong gói này.
