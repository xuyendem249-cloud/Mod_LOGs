# Legend Player iOS — Bước 1

Mục tiêu: iPhone 14, iOS 17.6.1. Lấy Android 5 / Ver 16 làm mẫu, giữ nguyên dự án Android.

**Đây là gói nguồn và bộ kiểm tra khả năng build core, chưa phải app iPhone. Chưa có IPA và chưa có link TestFlight. Chưa chạy build bằng Apple SDK hoặc test trên iPhone.**

## Bước hiện tại đã chuẩn bị gì?

- Chốt đúng mã nguồn SwanStation `cc94ebcd38a88a0e90788d7c8bcd764a009a5fa0`, cùng dòng core đang dùng trên Android.
- Script có kiểm tra nguồn trước khi sửa, tắt recompiler/JIT và mmap-fastmem, bỏ mã cấp phát JIT và dependency VIXL khỏi bản build này. Chuyển libretro sang static archive để liên kết trực tiếp vào app sau này, không tải thư viện Android.
- Nhánh cấp phát arena iOS dùng file tạm thuộc sandbox và mmap, thay vì POSIX shared-memory `shm_open`. Đây là thay đổi cần kiểm chứng trên iPhone, không khẳng định đã chạy được chỉ từ việc đọc mã.
- Phần frontend C++ dùng byte RGBA rõ ràng để tránh lỗi đỏ/xanh; nhận input đa chạm và xung tối thiểu theo đồng hồ input riêng, xóa phím khi xoay/ra nền/tải save.
- Workflow thủ công chạy hai cổng kiểm tra trên máy Mac ARM64: core macOS + API init/deinit + unit test frontend; core iPhone ARM64 bằng Apple iPhoneOS SDK. Nó kiểm tra không có source/flag JIT được biên dịch và kiểm tra các hàm libretro cần thiết trong archive.
- Gói nguồn không kèm ISO, BIOS, thẻ nhớ, tài khoản hay khóa ký. Workflow không cần bí mật Apple để biên dịch **thư viện core**.

## Đã kiểm tra đến đâu?

`build/local_check_report.json` ghi rõ các kiểm tra chạy trên Windows: phiên bản nguồn, 6 thay đổi có kiểm tra mẫu, từ chối nguồn khác mẫu, cú pháp Python, bộ workflow và cú pháp C++ ARM64 bằng compiler đã có trong dự án Android. Compiler đó không phải Apple SDK; không dùng kết quả này để tuyên bố core iOS đã build hay đã chạy.

Các kiểm tra runtime C++ và core sẽ chỉ được xác nhận khi workflow macOS chạy thành công. `scripts/build_core.py` từ chối chạy trên Windows với thông báo rõ ràng.

## Bước tiếp theo dành cho bạn

1. Tạo tài khoản GitHub miễn phí tại https://github.com/signup . Chưa cần trả tiền Apple Developer ở bước kiểm tra core.
2. Sau khi có tài khoản, mình sẽ hướng dẫn tạo repository và đưa **nội dung gói nguồn đã giải nén** vào gốc repository. `.github/workflows/core-build.yml` phải nằm đúng ở gốc, không lồng thêm một thư mục ngoài.
3. Vào **Actions → Legend iOS - Step 1 core gate → Run workflow**. Workflow chỉ chạy khi bấm thủ công, không tự chạy khi đẩy file.
4. Nếu thành công, tải hai artifact `Legend-Step1-macosx` và `Legend-Step1-iphoneos`. Đây là thư viện `.a`, báo cáo và mã nguồn core tương ứng; không cài trực tiếp lên điện thoại.
5. Khi core qua cổng kiểm tra này mới làm app UIKit: chọn BIOS/ISO, hình 4:3, âm thanh, nút cảm ứng. Chạy game ổn rồi chuyển VIP/Fusion và sau đó mới làm ký/TestFlight.

Máy Mac chạy trên dịch vụ GitHub, bạn không cần sở hữu Mac. Repository riêng dùng hạn mức phút của tài khoản; hãy giữ tắt chi tiêu trả phí và kiểm tra hạn mức trước khi chạy. Không tạo tài khoản Apple hay nhập khóa Apple vào GitHub ở bước này. Nguồn về runner/hạn mức: https://docs.github.com/en/actions/reference/runners/github-hosted-runners .

## Chạy thủ công trên máy Mac

Cần Git, Python 3, CMake và Xcode đã chọn bằng `xcode-select`:

```text
python3 scripts/prepare_core.py
python3 scripts/build_core.py --sdk macosx
python3 scripts/build_core.py --sdk iphoneos
```

Không nhầm `macosx` với `iphoneos`: test init/deinit trên macOS không thay thế kiểm tra sandbox, hiệu năng, âm thanh và vòng đời app trên iPhone.

## Trình tự sau bước 1

1. Core iPhone qua kiểm tra biên dịch, thư viện và API.
2. App iOS tối thiểu mở game, 4:3, màu/âm thanh, nút và dọc/ngang; test iPhone thật.
3. Thẻ nhớ/save, metadata từ ISO, VIP và hai chế độ gợi ý Fusion.
4. Ký bằng tài khoản phát hành phù hợp, tải App Store Connect, phân phối TestFlight. Việc này cần tài khoản Apple Developer; gói nguồn hiện tại không tự tạo tài khoản, mua gói hay tải bất kỳ ứng dụng nào lên Apple.
