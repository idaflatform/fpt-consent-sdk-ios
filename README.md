# ConsentCmp — CMP Data Consent SDK cho iOS (Swift)

Swift Package: core + UI SwiftUI cho luồng Data Consent của CMP.```

## Yêu cầu

- iOS 14+ / macOS 11+, Swift 5.9+
- Không có dependency ngoài nào

## Bắt đầu nhanh — 3 bước

### Bước 1. Thêm package

Swift Package Manager, thêm vào `Package.swift` của app (hoặc Xcode → *Add Package Dependencies…*):

```swift
.package(url: "https://github.com/idaflatform/fpt-consent-sdk-ios.git", from: "1.0.0")
```

### Bước 2. Khai cấu hình trong Info.plist

```xml
<key>CMPCodeConfig</key><string>cp_xxx::t_yyy</string>
<key>CMPBaseUrl</key><string>https://cmp.biznext.vn</string>
```

| Khoá | Bắt buộc | Ý nghĩa |
|---|---|---|
| `CMPCodeConfig` | Có | Integration key của Collection Point |
| `CMPBaseUrl` | Không | Địa chỉ CMP, không kèm path. Mặc định `ConsentOptions.defaultBaseUrl` (PROD) |

App **không cần viết code khởi tạo**: `ConsentCmp.shared` tự đọc Info.plist ở lần truy cập đầu tiên.
Không cần tenant id hay token, SDK gửi kèm header `X-Consent-Integration: {codeConfig}`.

### Bước 3. Hiện màn hình consent và truyền giá trị người dùng đã nhập

```swift
import ConsentCmp

struct PrivacyScreen: View {
    @StateObject private var model = ConsentFormModel()   // dùng ConsentCmp.shared
    @State private var fullName = ""
    @State private var email = ""

    var body: some View {
        ScrollView {
            // SDK tự hiện nút, tự gọi /sendData và tự gắn `values` vào các trường cần gửi.
            ConsentFormView(model: model, values: [
                "full_name": fullName,
                "email|EMAIL": email,
            ])
            .padding(16)
        }
        // `.task {}` chỉ có từ iOS 15 — dùng onAppear để giữ mức tối thiểu iOS 14.
        .onAppear {
            model.onSubmitted = { state, result in
                print("da luu consent: \(result.consentId ?? "")")
            }
            Task { await model.load() }
        }
    }
}
```

Xong. Phần dưới là chi tiết và các trường hợp khác.

---

## Nâng cấp từ bản cũ

Code cũ **vẫn chạy**, không bắt buộc sửa. Nên chuyển sang cách mới:

| Việc | Trước | Sau |
|---|---|---|
| Khởi tạo | `ConsentCmp(options: ConsentOptions(codeConfig: "…"))` rồi truyền instance qua các màn hình | Khai `CMPCodeConfig` trong Info.plist, dùng `ConsentCmp.shared` / `ConsentFormModel()` |
| Gửi giá trị | `cmp.setValues([...])` rồi `cmp.submit(&state)` | `cmp.submit(&state, values: [...])` |
| Nút của SDK | Không truyền giá trị trực tiếp được, phải `setValues` trước | `ConsentFormView(model:, values: [...])` |
| Đăng xuất | `clear()` **không** xoá nguồn giá trị đã khai | `clear()` xoá luôn nguồn giá trị đã khai |

```swift
// Trước
let cmp = ConsentCmp(options: ConsentOptions(codeConfig: "cp_xxx::t_yyy"))
cmp.setValues(["email|EMAIL": email])
try await cmp.submit(&state)

// Sau
try await ConsentCmp.shared.submit(&state, values: ["email|EMAIL": email])
```

## Khởi tạo — chi tiết

### Cách 1 (khuyến nghị) — Info.plist

- Thiếu `CMPCodeConfig` mà gọi `ConsentCmp.shared` thì app dừng với thông báo rõ ràng, để lỗi cấu hình
  lộ ra ngay khi dev chạy thử. Muốn tự xử lý thì dùng `ConsentOptions.fromBundle()`, hàm này trả `nil`
  khi thiếu khoá.
- Cần options riêng (header, timeout, source…) thì gọi `ConsentCmp.configure(_:)` **trước** lần dùng
  `shared` đầu tiên, thường đặt trong `App.init` hoặc `application(_:didFinishLaunchingWithOptions:)`:

  ```swift
  ConsentCmp.configure(ConsentOptions(codeConfig: "cp_xxx::t_yyy", timeout: 30))
  ```

- **Tách UAT / PROD theo build configuration** để không lỡ đẩy URL UAT lên App Store:

  ```xml
  <!-- Info.plist -->
  <key>CMPBaseUrl</key><string>$(CMP_BASE_URL)</string>
  ```

  ```
  // Release.xcconfig
  CMP_BASE_URL = https:/$()/cmp.biznext.vn
  ```

  Biến chưa được thay (còn nguyên `$(...)`) thì SDK coi như thiếu khoá: `CMPBaseUrl` quay về PROD,
  còn `CMPCodeConfig` thì báo thiếu.
- App extension (widget, notification service…): `Bundle.main` là bundle của extension, nên phải khai
  khoá trong Info.plist của extension.

### Cách 2 — tự tạo instance

Khi cần nhiều instance hoặc chọn môi trường lúc chạy:

```swift
// PROD — không cần khai baseUrl
let cmp = ConsentCmp(options: ConsentOptions(codeConfig: "cp_xxx::t_yyy"))

// Môi trường khác thì ghi đè
let uat = ConsentCmp(options: ConsentOptions(
    codeConfig: "cp_xxx::t_yyy",
    baseUrl: "https://cmp.biznext.vn"  // không kèm path
))

let model = ConsentFormModel(cmp: uat)
```

## Nhúng vào form của app

Khi khối consent nằm trong màn hình đăng ký (app đã có nút submit riêng):

```swift
ConsentFormView(model: model, embeddedInForm: true)   // ẩn nút của SDK

Button("Đăng ký") {
    guard model.validateRequired() else { return }    // còn mục bắt buộc -> lỗi hiện trên form
    Task {
        var state = model.currentState
        let result = try await ConsentCmp.shared.submit(&state, values: [   // gửi consent trước
            "full_name": fullName,
            "email|EMAIL": email,
        ])
        registerAccount(consentId: result.consentId)  // rồi mới tạo tài khoản
    }
}
.disabled(!model.hasAllRequired)
```

Giống bản Android: `embeddedInForm = true` thì **app phải tự gọi `submit`**, nếu quên thì không có bản
ghi consent nào được tạo.

## Gửi kèm giá trị người dùng đã nhập

Trường có `sharedWithSystem = true` cần giá trị thật làm bằng chứng. SDK tự gắn giá trị vào đúng trường,
app không cần biết `id` của trường.

**Quy tắc khoá trong `values`:**

| Khoá | Khớp với |
|---|---|
| `"email"` | Trường có `name = email` |
| `"email\|EMAIL"` | Trường có `name = email` **và** `dataType = EMAIL`, dùng khi có 2 trường trùng tên |

- Không phân biệt hoa thường, bỏ khoảng trắng đầu cuối. `name|dataType` được ưu tiên hơn `name`.
- Giá trị rỗng hoặc chỉ có khoảng trắng thì không gửi.
- Trường không `sharedWithSystem` thì không gửi, kể cả khi có trong `values`.
- Giá trị được gửi **bất kể toggle bật hay tắt**, vì bản ghi phải thể hiện người dùng từ chối dữ liệu nào.

**Ba cách truyền, theo thứ tự khuyến nghị:**

```swift
// 1. Nút của SDK — truyền vào View, luôn là giá trị mới nhất của @State
ConsentFormView(model: model, values: ["full_name": fullName, "email|EMAIL": email])

// 2. App tự gửi — truyền thẳng vào submit
try await ConsentCmp.shared.submit(&state, values: ["full_name": fullName])

// 3. Dữ liệu nằm ngoài View (session, view model là class) — khai nguồn một lần
ConsentCmp.shared.setValueSource { [weak session] field in
    field.name == "email" ? session?.email : nil
}
```

- `values` chỉ dùng cho **đúng lần gửi đó**, không bị giữ lại cho lần sau.
- Có `values` thì SDK dùng `values` và **bỏ qua** nguồn đã khai qua `setValues` / `setValueSource`.
  Không truyền `values` thì SDK dùng nguồn đã khai như trước.
- `cmp.clear()` (đăng xuất) xoá nguồn đã khai, để giá trị của người dùng cũ không lọt vào bản ghi của
  người sau.
- `setValues(_:)` vẫn được giữ để tương thích với app đang dùng.

> ⚠️ **Bẫy trong SwiftUI khi dùng `setValueSource`.** Closure **chụp bản copy của struct View** tại thời
> điểm tạo. Đặt nó trong `onAppear`/`init` rồi đọc `@State` bên trong thì closure sẽ mãi thấy giá trị lúc
> đó (thường là chuỗi rỗng), nên `value` **không được gửi** dù `sharedWithSystem = true`. Đây là ngữ
> nghĩa capture của Swift, không phải lỗi SDK. Dữ liệu nằm trong `@State` thì dùng cách 1 hoặc 2.
> Bản Android không dính bẫy này vì `bindForm(view)` quét cây view sống tại thời điểm submit.

> **Trường ẩn (`display = false`).** `/config` trả về **mọi** trường của form dữ liệu nguồn, nhưng chỉ
> trường được chọn cho mục đích đó trong template mới có `display = true`. Trường `display = false` vẫn
> nằm trong `item.dataFields` để app biết form nguồn thu những gì. SDK **không** dựng UI cho nó,
> **không** bao giờ đặt `isAccept = true` và **không** tính vào ràng buộc bắt buộc, nhưng **vẫn** gửi
> `value` khi `sharedWithSystem = true` (khoá có trong `values` với `isAccept = false`). Tự dựng UI thì
> duyệt `item.visibleDataFields`. Backend cũ không trả khoá này — khi đó SDK coi như `display = true`.

## Đọc lại quyết định

```swift
let cmp = ConsentCmp.shared

if cmp.isGranted(purposeId) {
    Analytics.setEnabled(true)
}

let saved = cmp.savedState()
let emailValue = saved?.fieldValue(purposeId, emailFieldId)
let consentId  = saved?.consentId          // đính kèm khi gọi API nghiệp vụ

cmp.clear()                                 // đăng xuất — visitorId vẫn giữ, nguồn giá trị bị xoá
cmp.invalidateConfigCache()                 // buộc lần fetchConfig sau gọi mạng sạch
```

## Tuỳ biến giao diện

Truyền `ConsentTheme` / `ConsentStrings` riêng thay vì sửa code SDK:

```swift
var theme = ConsentTheme()
theme.primary = Color(red: 0.06, green: 0.38, blue: 0.99)

var strings = ConsentStrings()
strings.submit = "Tôi đồng ý"

ConsentFormView(model: model, theme: theme, strings: strings)
```

Cờ `thirdPartiesOnSharedOnly: true` để chip bên thứ ba chỉ hiện ở trường `sharedWithSystem = true`.

## Hằng số hành vi (đừng tự đổi ở một nền tảng)

- Mục đích tắt ⇒ mọi trường con tắt; bật một trường ⇒ mục đích cha bật.
- Mục đích `required` hoặc chứa trường `required` thì **không tắt được** — về trạng thái tối thiểu.
- Mặc định khi mở: **chỉ** mục/trường `required` bật sẵn.
- `value` gửi kèm bất kể `isAccept`; chỉ khóa có trong `/config` hiện tại được gửi.
- `consentId` sinh mới mỗi lần submit; `visitorId` giữ nguyên kể cả sau `clear()`.
- `source` = tên app + bundle id + version, SDK tự đọc từ `Bundle.main`; ghi đè bằng `ConsentOptions(source:)`.
- `fetchConfig()` luôn gọi mạng (cache chỉ dùng khi mất mạng); request gửi `Cache-Control: no-cache`
  và `URLRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData`.
