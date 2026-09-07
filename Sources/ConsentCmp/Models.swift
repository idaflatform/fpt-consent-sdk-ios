import Foundation

/// Model cua `GET /config` — map 1-1 voi `ConsentConfigResponse` phia backend (fis-cmp).
///
/// Quy tac hanh vi nam o `ConsentState`; file nay chi lo hinh dang du lieu.
/// Xem `consent-sdk-spec/consent-rules.md`.

public struct ConsentField: Equatable {
    public let id: String?
    /// Ten ky thuat — dung doi chieu voi form cua app.
    public let name: String?
    public let title: String?
    public let dataType: String?
    public let required: Bool
    public let sensitive: Bool
    /// True khi truong duoc chia se cho he thong / ben thu ba.
    public let sharedWithSystem: Bool

    public init(id: String?, name: String?, title: String?, dataType: String?,
                required: Bool, sensitive: Bool, sharedWithSystem: Bool) {
        self.id = id
        self.name = name
        self.title = title
        self.dataType = dataType
        self.required = required
        self.sensitive = sensitive
        self.sharedWithSystem = sharedWithSystem
    }

    /// Khoa gui len `values` — uu tien `id`, fallback `name`.
    public var key: String { id ?? name ?? "" }

    /// Nhan hien thi: uu tien `title`, fallback `name`.
    public var displayName: String {
        if let title = title, !title.isEmpty { return title }
        return name ?? ""
    }
}

public struct ConsentItem: Equatable {
    public let id: String?
    public let code: String?
    public let label: String?
    public let description: String?
    public let required: Bool
    public let defaultChecked: Bool
    public let version: String?
    public let legalBasis: String?
    public let dataFields: [ConsentField]
    public let thirdParties: [String]

    public init(id: String?, code: String?, label: String?, description: String?,
                required: Bool, defaultChecked: Bool, version: String?, legalBasis: String?,
                dataFields: [ConsentField], thirdParties: [String]) {
        self.id = id
        self.code = code ?? id
        self.label = label
        self.description = description
        self.required = required
        // Purpose bat buoc thi luon coi nhu duoc tick san (giong ban Java/TS).
        self.defaultChecked = defaultChecked || required
        self.version = version
        self.legalBasis = legalBasis
        self.dataFields = dataFields
        self.thirdParties = thirdParties
    }

    /// Khoa purpose gui len `values` — uu tien `code`, fallback `id`.
    public var key: String { code ?? id ?? "" }

    /// Truong du lieu bat buoc dau tien; nil neu khong co.
    public var firstRequiredField: ConsentField? {
        dataFields.first { $0.required }
    }

    public var hasRequiredField: Bool { firstRequiredField != nil }

    /// True khi purpose khong the tat: chinh no `required`, hoac chua truong `required` (R6).
    public var mustBeGranted: Bool { required || hasRequiredField }

    public func field(forKey key: String) -> ConsentField? {
        dataFields.first { $0.key == key }
    }
}

public struct ConsentUiConfig: Equatable {
    public let title: String?
    public let description: String?
    public let submitLabel: String?
    public let items: [ConsentItem]

    public init(title: String?, description: String?, submitLabel: String?, items: [ConsentItem]) {
        self.title = title
        self.description = description
        self.submitLabel = submitLabel
        self.items = items
    }
}

public struct FormField: Equatable {
    public let key: String?
    public let label: String?
    public let resourceUse: String?
    public let typeInput: String?
}

public struct ConsentConfig: Equatable {
    public let code: String?
    public let name: String?
    public let status: String?
    public let fields: [FormField]
    public let config: ConsentUiConfig?

    public init(code: String?, name: String?, status: String?,
                fields: [FormField], config: ConsentUiConfig?) {
        self.code = code
        self.name = name
        self.status = status
        self.fields = fields
        self.config = config
    }

    /// Danh sach purpose hien thi; khong bao gio nil.
    public var items: [ConsentItem] { config?.items ?? [] }

    /// True khi form dang active — chi khi do moi nen hien UI consent.
    public var isActive: Bool {
        guard let status = status else { return true }
        return status.lowercased() == "active"
    }

    public func item(forKey key: String) -> ConsentItem? {
        items.first { $0.key == key }
    }
}

public struct SendConsentResult: Equatable {
    public let ok: Bool
    /// Khoa dinh danh ban ghi consent — dung de doi soat / DSAR.
    public let consentId: String?
    public let code: String?
    public let dateCreated: String?
}

// MARK: - Parse tu JSON cua /config

public enum ConsentParser {

    /// Boc lop `BaseResponse` (`{code, message, data}`) neu co.
    public static func unwrap(_ root: [String: Any]) -> [String: Any] {
        (root["data"] as? [String: Any]) ?? root
    }

    public static func parseConfig(_ root: [String: Any]) -> ConsentConfig {
        let node = unwrap(root)
        let ui = node["config"] as? [String: Any]
        return ConsentConfig(
            code: text(node, "code"),
            name: text(node, "name"),
            status: text(node, "status"),
            fields: array(node, "fields").map { field in
                FormField(key: text(field, "key"),
                          label: text(field, "label"),
                          resourceUse: text(field, "resourceUse"),
                          typeInput: text(field, "typeInput"))
            },
            config: ui.map { ui in
                ConsentUiConfig(title: text(ui, "title"),
                                description: text(ui, "description"),
                                submitLabel: text(ui, "submitLabel"),
                                items: array(ui, "items").map(parseItem))
            }
        )
    }

    public static func parseSendResult(_ root: [String: Any]) -> SendConsentResult {
        let node = unwrap(root)
        return SendConsentResult(ok: (node["ok"] as? Bool) ?? true,
                                 consentId: text(node, "consentId"),
                                 code: text(node, "code"),
                                 dateCreated: text(node, "dateCreated"))
    }

    private static func parseItem(_ node: [String: Any]) -> ConsentItem {
        ConsentItem(
            id: text(node, "id"),
            code: text(node, "code"),
            label: text(node, "label"),
            description: text(node, "description"),
            required: bool(node, "required"),
            defaultChecked: bool(node, "defaultChecked"),
            version: text(node, "version"),
            legalBasis: text(node, "legalBasis"),
            dataFields: array(node, "dataFields").map(parseField),
            thirdParties: (node["thirdParties"] as? [Any] ?? [])
                .compactMap { $0 as? String }
                .filter { !$0.isEmpty }
        )
    }

    private static func parseField(_ node: [String: Any]) -> ConsentField {
        ConsentField(id: text(node, "id"),
                     name: text(node, "name"),
                     title: text(node, "title"),
                     dataType: text(node, "dataType"),
                     required: bool(node, "required"),
                     sensitive: bool(node, "sensitive"),
                     sharedWithSystem: bool(node, "sharedWithSystem"))
    }

    private static func text(_ node: [String: Any], _ key: String) -> String? {
        guard let value = node[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    private static func bool(_ node: [String: Any], _ key: String) -> Bool {
        (node[key] as? Bool) ?? false
    }

    private static func array(_ node: [String: Any], _ key: String) -> [[String: Any]] {
        (node[key] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
    }
}
