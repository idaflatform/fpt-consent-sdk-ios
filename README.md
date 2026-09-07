# ConsentCmp — CMP Data Consent SDK cho iOS (Swift)

Swift Package: core + UI SwiftUI cho luồng Data Consent của CMP.```

## Yêu cầu

- iOS 14+ / macOS 11+, Swift 5.9+
- Không có dependency ngoài nào

## Cài đặt

Swift Package Manager, thêm vào `Package.swift` của app:

```swift
.package(url: "https://github.com/idaflatform/fpt-consent-sdk-ios.git", from: "1.0.0")
```

## Khởi tạo

Chỉ cần **`codeConfig`** (integration key của Collection Point). `baseUrl` đã có mặc định trong SDK
(`ConsentOptions.defaultBaseUrl` = `https://cmp.biznext.vn` — môi trường PROD):

```swift
import ConsentCmp

// PROD — không cần khai baseUrl
let cmp = ConsentCmp(options: ConsentOptions(codeConfig: "cp_xxx::t_yyy"))

// Môi trường khác thì ghi đè
let uat = ConsentCmp(options: ConsentOptions(
    codeConfig: "cp_xxx::t_yyy",
    baseUrl: "https://cmp.biznext.vn"      // không kèm path
))
```

Không cần tenant id, không cần token — SDK gửi kèm header `X-Consent-Integration: {codeConfig}`.

## Hiện màn hình consent (SwiftUI)

```swift
struct PrivacyScreen: View {
    @StateObject private var model: ConsentFormModel

    init(cmp: ConsentCmp) {
        _model = StateObject(wrappedValue: ConsentFormModel(cmp: cmp))
    }

    var body: some View {
        ScrollView {
            ConsentFormView(model: model)          // SDK tự hiện nút và tự gọi /sendData
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

### Nhúng vào form của app

Khi khối consent nằm trong màn hình đăng ký (app đã có nút submit riêng):

```swift
ConsentFormView(model: model, embeddedInForm: true)   // ẩn nút của SDK

Button("Đăng ký") {
    guard model.validateRequired() else { return }    // còn mục bắt buộc -> lỗi hiện trên form
    Task {
        var state = model.currentState
        let result = try await cmp.submit(&state)     // gửi consent trước
        registerAccount(consentId: result.consentId)  // rồi mới tạo tài khoản
    }
}
.disabled(!model.hasAllRequired)
```

Giống bản Android: `embeddedInForm = true` thì **app phải tự gọi `submit`**, nếu quên thì không có bản
ghi consent nào được tạo.

## Gửi kèm giá trị người dùng đã nhập

Trường có `sharedWithSystem = true` cần giá trị thật làm bằng chứng. Đối chiếu theo `name`
(+ `dataType` khi cần phân biệt trường trùng tên), app không cần biết `id` của trường.

**Cách khuyến nghị — snapshot ngay trước khi submit:**

```swift
cmp.setValues([
    "full_name": fullName,
    "email|EMAIL": email,      // "name|dataType" khi can phan biet
])
try await cmp.submit(&state)
```

> ⚠️ **Bẫy hay gặp nhất trong SwiftUI.** `setValueSource { … }` nhận một closure, mà closure **chụp bản
> copy của struct View** tại thời điểm tạo. Đặt nó trong `onAppear`/`init` rồi đọc `@State` bên trong thì
> closure sẽ mãi thấy giá trị lúc đó — thường là chuỗi rỗng — nên `value` **không được gửi** dù
> `sharedWithSystem = true`. Đây không phải lỗi SDK mà là ngữ nghĩa capture của Swift.
>
> Dùng `setValues(_:)` (snapshot), hoặc gọi lại `setValueSource` ngay trước mỗi lần `submit`.
> Bản Android không dính bẫy này vì `bindForm(view)` quét cây view sống tại thời điểm submit.

Closure vẫn dùng được khi dữ liệu nằm ngoài View (session, view model là `class`):

```swift
cmp.setValueSource { [weak session] field in
    field.name == "email" ? session?.email : nil
}
```

Giá trị được gửi **bất kể toggle bật hay tắt** — bản ghi phải thể hiện người dùng từ chối dữ liệu nào.

## Đọc lại quyết định

```swift
if cmp.isGranted(purposeId) {
    Analytics.setEnabled(true)
}

let saved = cmp.savedState()
let emailValue = saved?.fieldValue(purposeId, emailFieldId)
let consentId  = saved?.consentId          // đính kèm khi gọi API nghiệp vụ

cmp.clear()                                 // đăng xuất — visitorId vẫn giữ
cmp.invalidateConfigCache()                 // buộc lần fetchConfig sau gọi mạng sạch
```

`FixtureTests` có sẵn `testRunnerCatchesWrongExpectation` — nếu bộ fixture chạy rỗng thì test này đỏ.

## Tuỳ biến giao diện

Truyền `ConsentTheme` / `ConsentStrings` riêng thay vì sửa code SDK:

```swift
var theme = ConsentTheme()
theme.primary = Color(red: 0.06, green: 0.38, blue: 0.99)

var strings = ConsentStrings()
strings.submit = "Tôi đồng ý"

ConsentFormView(model: model, theme: theme, strings: strings)
```

Cờ `thirdPartiesOnSharedOnly: true` để chip bên thứ ba chỉ hiện ở trường `sharedWithSystem = true`

## Hằng số hành vi (đừng tự đổi ở một nền tảng)

- Mục đích tắt ⇒ mọi trường con tắt; bật một trường ⇒ mục đích cha bật.
- Mục đích `required` hoặc chứa trường `required` thì **không tắt được** — về trạng thái tối thiểu.
- Mặc định khi mở: **chỉ** mục/trường `required` bật sẵn.
- `value` gửi kèm bất kể `isAccept`; chỉ khóa có trong `/config` hiện tại được gửi.
- `consentId` sinh mới mỗi lần submit; `visitorId` giữ nguyên kể cả sau `clear()`.
- `source` = tên app + bundle id + version, SDK tự đọc từ `Bundle.main`; ghi đè bằng `ConsentOptions(source:)`.
- `fetchConfig()` luôn gọi mạng (cache chỉ dùng khi mất mạng); request gửi `Cache-Control: no-cache`
  và `URLRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData`.
