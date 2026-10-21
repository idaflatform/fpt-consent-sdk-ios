import Foundation
import SwiftUI

/// Bang mau + khoang cach cua khoi consent. App doi giao dien bang cach truyen theme rieng vao
/// `ConsentFormView(theme:)` thay vi sua code SDK.
public struct ConsentTheme {

    public var background = Color.white
    public var surface = Color.cmpHex(0xF7F9FB)
    public var border = Color.cmpHex(0xE3E8EF)

    public var textPrimary = Color.cmpHex(0x1D2433)
    public var textSecondary = Color.cmpHex(0x5B6674)

    public var primary = Color.cmpHex(0x146052)
    public var link = Color.cmpHex(0x146052)
    public var linkAlt = Color.cmpHex(0x146052)
    public var accent = Color.cmpHex(0x1D2433)
    public var error = Color.cmpHex(0xD92D20)
    public var selectedBackground = Color.cmpHex(0xE3F2EF)
    public var selectedBorder = Color.cmpHex(0x7FB5A8)
    public var fieldBorder = Color.cmpHex(0xD5DCE5)

    public var chipBackground = Color.cmpHex(0xEEF1F5)
    public var chipBorder = Color.cmpHex(0xEEF1F5)
    public var chipText = Color.cmpHex(0x1D2433)

    public var cardRadius: CGFloat = 12
    public var fieldRadius: CGFloat = 8
    public var chipRadius: CGFloat = 4

    public init() {}
}

private extension Color {
    static func cmpHex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 255) / 255,
              green: Double((value >> 8) & 255) / 255,
              blue: Double(value & 255) / 255)
    }
}

/// Chuoi hien thi — app dich sang ngon ngu khac bang cach truyen ban rieng.
public struct ConsentStrings {

    public var sectionTitle = "Đồng ý xử lý dữ liệu"
    public var listTitle = "Nội dung chia sẻ dữ liệu"
    public var hideList = "Ẩn danh sách"
    public var showList = "Hiện danh sách"
    public var collapse = "Thu gọn"
    public var expand = "Mở rộng"
    public var acceptAll = "Đồng ý tất cả"
    public var rejectAll = "Từ chối tất cả"
    public var submit = "Lưu lựa chọn"
    public var mandatory = "Bắt buộc"
    public var loading = "Đang tải cấu hình…"
    public var retry = "Thử lại"
    public var showPurposes = "Xem %d mục đích"
    public var showMore = "Xem thêm"
    public var sharedWith = "Chia sẻ với:"
    public var fieldsCount = "Trường dữ liệu · %d/%d"
    public var selectAll = "Chọn tất cả"
    public var deselectAll = "Bỏ chọn tất cả"
    public var selectedSummary = "%d / %d mục đích đã chọn"
    public var inactive = "Collection Point không hoạt động"
    public var selected = "Đã chọn"
    public var notSelected = "Chưa chọn"

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
