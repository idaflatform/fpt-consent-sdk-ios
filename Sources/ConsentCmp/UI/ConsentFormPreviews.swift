#if DEBUG
import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
private struct ConsentPreviewScreen: View {
    @StateObject private var model: ConsentFormModel
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
        let model = ConsentFormModel(cmp: ConsentCmp(
            options: ConsentOptions(codeConfig: "cp_demo::t_demo"), storage: MemoryStorage()))
        model.applyLoadedConfig(ConsentParser.parseConfig([
            "code": "cp_demo::t_demo", "status": "active", "config": [
                "title": "Mục đích xử lý dữ liệu",
                "description": "Dữ liệu giả lập phục vụ kiểm thử giao diện.",
                "items": [
                    ["id": "registration", "label": "Đăng ký bảo hiểm và nhận thông tin về dịch vụ liên quan", "required": true,
                     "description": "Nội dung mô tả dài để kiểm tra khả năng xuống dòng trên màn hình hẹp.",
                     "thirdParties": ["Công ty bảo hiểm và dịch vụ tài chính"],
                     "dataFields": [
                        ["id": "email", "name": "Địa chỉ email liên hệ đăng ký bảo hiểm", "required": true],
                        ["id": "phone", "name": "Số điện thoại"]]],
                    ["id": "marketing", "label": "Nhận thông tin giới thiệu sản phẩm", "description": "Mục đích tùy chọn"]
                ]]]))
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ScrollView { ConsentFormView(model: model, embeddedInForm: embedded).padding(16) }
    }
}

@available(iOS 14.0, macOS 11.0, *)
struct ConsentFormPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsentPreviewScreen().previewLayout(.fixed(width: 344, height: 800)).previewDisplayName("312pt form")
            ConsentPreviewScreen().environment(\.sizeCategory, .accessibilityLarge)
                .previewLayout(.fixed(width: 344, height: 800)).previewDisplayName("Large text")
            ConsentPreviewScreen().previewLayout(.fixed(width: 712, height: 900)).previewDisplayName("680pt tablet")
            ConsentPreviewScreen(embedded: true).previewLayout(.fixed(width: 392, height: 800))
                .previewDisplayName("Embedded collapsed")
        }
    }
}
#endif
