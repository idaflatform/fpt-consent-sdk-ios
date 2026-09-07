import Foundation
import SwiftUI

/// Bang mau + khoang cach cua khoi consent. App doi giao dien bang cach truyen theme rieng vao
/// `ConsentFormView(theme:)` thay vi sua code SDK.
public struct ConsentTheme {

    public var background = Color.white
    public var surface = Color(red: 0.97, green: 0.97, blue: 0.98)
    public var border = Color(red: 0.90, green: 0.91, blue: 0.95)

    public var textPrimary = Color(red: 0.09, green: 0.14, blue: 0.24)
    public var textSecondary = Color(red: 0.42, green: 0.46, blue: 0.56)

    public var primary = Color(red: 0.18, green: 0.44, blue: 0.93)
    public var link = Color(red: 0.18, green: 0.44, blue: 0.93)
    public var linkAlt = Color(red: 0.07, green: 0.63, blue: 0.31)
    public var accent = Color(red: 0.92, green: 0.48, blue: 0.17)
    public var error = Color(red: 0.85, green: 0.18, blue: 0.13)

    public var chipBackground = Color(red: 0.93, green: 0.95, blue: 1.0)
    public var chipBorder = Color(red: 0.84, green: 0.87, blue: 1.0)
    public var chipText = Color(red: 0.26, green: 0.34, blue: 0.70)

    public var cardRadius: CGFloat = 12
    public var fieldRadius: CGFloat = 10
    public var chipRadius: CGFloat = 6

    public init() {}
}

/// Chuoi hien thi — app dich sang ngon ngu khac bang cach truyen ban rieng.
public struct ConsentStrings {

    public var sectionTitle = "Đồng ý xử lý dữ liệu"
    public var listTitle = "Danh sách sự đồng ý"
    public var hideList = "Ẩn danh sách"
    public var showList = "Hiện danh sách"
    public var collapse = "Thu gọn"
    public var expand = "Mở rộng"
    public var acceptAll = "Đồng ý tất cả"
    public var rejectAll = "Từ chối tất cả"
    public var submit = "Đồng ý"
    public var mandatory = "Bắt buộc"
    public var loading = "Đang tải cấu hình…"
    public var retry = "Thử lại"

    /// %@ = tên mục đích.
    public var errorRequiredPurpose = "Vui lòng đồng ý mục đích bắt buộc: %@"
    /// %1$@ = tên mục đích, %2$@ = tên trường.
    public var errorRequiredField = "Trường bắt buộc của \"%1$@\": %2$@"

    public init() {}

    func requiredMessage(_ missing: ConsentState.MissingRequired) -> String {
        let itemLabel = missing.item.label ?? ""
        guard let field = missing.field else {
            return String(format: errorRequiredPurpose, itemLabel)
        }
        return String(format: errorRequiredField, itemLabel, field.displayName)
    }
}
