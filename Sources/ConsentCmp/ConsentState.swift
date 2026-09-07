import Foundation

/// Quyet dinh cua nguoi dung + toan bo quy tac toggle.
///
/// Ban port cua `ConsentState` trong SDK Android va `sdk-js`. Ca ba phai hanh xu giong nhau —
/// kiem chung bang `consent-sdk-spec/fixtures`. Sua hanh vi o day thi phai sua
/// `consent-rules.md` + fixture truoc.
public struct ConsentState {

    /// Ten khoa co dinh trong object cua purpose / truong du lieu.
    public static let keyIsAccept = "isAccept"
    public static let keyValue = "value"

    /// Ket qua ap dung mot thao tac toggle.
    public enum ToggleResult: String {
        case applied = "APPLIED"
        /// Bi chan vi muc/truong bat buoc — trang thai da ve muc toi thieu.
        case blockedRequired = "BLOCKED_REQUIRED"
    }

    /// Quyet dinh cho mot truong du lieu.
    public struct FieldDecision: Equatable {
        public var accepted: Bool
        /// Gia tri nguoi dung nhap; nil khi form cua app khong co truong tuong ung.
        public var value: String?

        public init(accepted: Bool = false, value: String? = nil) {
            self.accepted = accepted
            self.value = value
        }
    }

    /// Mot muc bat buoc con thieu: purpose, hoac mot truong du lieu cua purpose do.
    public struct MissingRequired {
        public let item: ConsentItem
        /// nil khi thieu chinh purpose.
        public let field: ConsentField?
    }

    private var purposes: [String: Bool] = [:]
    private var fields: [String: [String: FieldDecision]] = [:]
    private var extras: [String: Any] = [:]

    public var consentId: String?
    public var configCode: String?
    public var submittedAtMs: Double = 0

    public init() {}

    // MARK: - Dung trang thai

    /// Trang thai mac dinh khi mo man hinh (R5): chi muc/truong `required` bat san;
    /// purpose `defaultChecked` cung bat, nhung truong con van tat.
    public static func defaults(of config: ConsentConfig?) -> ConsentState {
        var state = ConsentState()
        guard let config = config else { return state }
        state.configCode = config.code
        for item in config.items {
            let granted = item.mustBeGranted || item.defaultChecked
            state.setGranted(item.key, granted)
            for field in item.dataFields {
                state.setFieldGranted(item.key, field.key, granted && field.required)
            }
        }
        return state
    }

    /// Dung lai trang thai khop cau hinh hien tai, giu lua chon cu neu con hop le (R13).
    public static func merge(_ config: ConsentConfig?, saved: ConsentState?) -> ConsentState {
        var state = ConsentState.defaults(of: config)
        guard let config = config, let saved = saved else { return state }

        for item in config.items {
            let purposeKey = item.key
            if let savedPurpose = saved.purposes[purposeKey] {
                state.setGranted(purposeKey, savedPurpose || item.mustBeGranted)
            }
            for field in item.dataFields {
                guard let savedField = saved.fields[purposeKey]?[field.key] else { continue }
                // Truong bat buoc: purpose dang bat thi luon bat, khong lay lua chon cu.
                let granted = state.isGranted(purposeKey) && (field.required || savedField.accepted)
                state.setFieldGranted(purposeKey, field.key, granted)
                state.setFieldValue(purposeKey, field.key, savedField.value)
            }
        }
        return state
    }

    /// Bo cac purpose / truong khong con trong cau hinh hien tai (R3); khong them khoa moi.
    public mutating func retainOnly(_ config: ConsentConfig?) {
        guard let config = config else { return }
        var allowed: [String: Set<String>] = [:]
        for item in config.items {
            allowed[item.key] = Set(item.dataFields.map { $0.key })
        }
        purposes = purposes.filter { allowed[$0.key] != nil }
        var kept: [String: [String: FieldDecision]] = [:]
        for (purposeKey, group) in fields {
            guard let allowedFields = allowed[purposeKey] else { continue }
            kept[purposeKey] = group.filter { allowedFields.contains($0.key) }
        }
        fields = kept
    }

    // MARK: - Doc trang thai

    public func isGranted(_ purposeKey: String) -> Bool {
        purposes[purposeKey] == true
    }

    public func isFieldGranted(_ purposeKey: String, _ fieldKey: String) -> Bool {
        fields[purposeKey]?[fieldKey]?.accepted == true
    }

    public func fieldValue(_ purposeKey: String, _ fieldKey: String) -> String? {
        fields[purposeKey]?[fieldKey]?.value
    }

    public var purposeEntries: [String: Bool] { purposes }
    public var fieldEntries: [String: [String: FieldDecision]] { fields }
    public var extraEntries: [String: Any] { extras }

    /// True khi moi purpose va moi truong deu bat — dung cho toggle "Dong y tat ca".
    public var isAllGranted: Bool {
        if purposes.isEmpty { return false }
        if purposes.values.contains(false) { return false }
        for group in fields.values {
            for decision in group.values where !decision.accepted { return false }
        }
        return true
    }

    // MARK: - Set truc tiep (app tu dung state)

    /// Tat purpose thi moi truong con tat theo (R1).
    public mutating func setGranted(_ purposeKey: String, _ granted: Bool) {
        purposes[purposeKey] = granted
        if !granted, var group = fields[purposeKey] {
            for key in Array(group.keys) {
                group[key]?.accepted = false
            }
            fields[purposeKey] = group
        }
    }

    /// Bat truong thi purpose cha bat theo (R2).
    public mutating func setFieldGranted(_ purposeKey: String, _ fieldKey: String, _ granted: Bool) {
        var group = fields[purposeKey] ?? [:]
        var decision = group[fieldKey] ?? FieldDecision()
        decision.accepted = granted
        group[fieldKey] = decision
        fields[purposeKey] = group
        if granted { purposes[purposeKey] = true }
    }

    /// Gia tri nguoi dung nhap; nil = khong gui khoa `value`.
    public mutating func setFieldValue(_ purposeKey: String, _ fieldKey: String, _ value: String?) {
        var group = fields[purposeKey] ?? [:]
        var decision = group[fieldKey] ?? FieldDecision()
        decision.value = value
        group[fieldKey] = decision
        fields[purposeKey] = group
    }

    /// Gia tri bo sung o cap ngoai cung cua `values`.
    public mutating func putExtra(_ key: String, _ value: Any) {
        extras[key] = value
    }

    // MARK: - Thao tac cua nguoi dung

    /// Nguoi dung bat/tat mot purpose (R6, R10).
    @discardableResult
    public mutating func applyPurposeToggle(_ config: ConsentConfig?, _ purposeKey: String,
                                            _ granted: Bool) -> ToggleResult {
        guard let item = config?.item(forKey: purposeKey) else {
            setGranted(purposeKey, granted)
            return .applied
        }
        if !granted && item.mustBeGranted {
            setMinimumRequired(config, purposeKey)
            return .blockedRequired
        }
        setGranted(purposeKey, granted)
        if granted {
            for field in item.dataFields {
                setFieldGranted(purposeKey, field.key, true)
            }
        }
        return .applied
    }

    /// Nguoi dung bat/tat mot truong du lieu (R7, R11).
    @discardableResult
    public mutating func applyFieldToggle(_ config: ConsentConfig?, _ purposeKey: String,
                                          _ fieldKey: String, _ granted: Bool) -> ToggleResult {
        let item = config?.item(forKey: purposeKey)
        let field = item?.field(forKey: fieldKey)

        if !granted, field?.required == true, isGranted(purposeKey) {
            setFieldGranted(purposeKey, fieldKey, true)
            return .blockedRequired
        }
        setFieldGranted(purposeKey, fieldKey, granted)
        if !granted, let item = item, !item.mustBeGranted, !anyFieldGranted(item) {
            setGranted(purposeKey, false)
        }
        return .applied
    }

    /// "Dong y tat ca" (R12).
    public mutating func applyAcceptAll(_ config: ConsentConfig?) {
        guard let config = config else { return }
        for item in config.items {
            setGranted(item.key, true)
            for field in item.dataFields {
                setFieldGranted(item.key, field.key, true)
            }
        }
    }

    /// "Tu choi tat ca" — muc khong the tat ve trang thai toi thieu (R8).
    @discardableResult
    public mutating func applyRejectAll(_ config: ConsentConfig?) -> ToggleResult {
        guard let config = config else { return .applied }
        var result = ToggleResult.applied
        for item in config.items {
            if item.mustBeGranted {
                setMinimumRequired(config, item.key)
                result = .blockedRequired
            } else {
                setGranted(item.key, false)
            }
        }
        return result
    }

    /// Trang thai toi thieu: purpose bat, chi truong bat buoc bat.
    public mutating func setMinimumRequired(_ config: ConsentConfig?, _ purposeKey: String) {
        guard let item = config?.item(forKey: purposeKey) else { return }
        setGranted(purposeKey, true)
        for field in item.dataFields {
            setFieldGranted(purposeKey, field.key, field.required)
        }
    }

    // MARK: - Validate + payload

    /// Muc bat buoc dau tien chua thoa (R9); nil khi duoc phep submit.
    public func firstMissing(_ config: ConsentConfig?) -> MissingRequired? {
        guard let config = config else { return nil }
        for item in config.items {
            if !isGranted(item.key) {
                if item.required { return MissingRequired(item: item, field: nil) }
                if let requiredField = item.firstRequiredField {
                    return MissingRequired(item: item, field: requiredField)
                }
                continue
            }
            for field in item.dataFields where field.required && !isFieldGranted(item.key, field.key) {
                return MissingRequired(item: item, field: field)
            }
        }
        return nil
    }

    /// Object `values` gui len `POST /sendData`.
    public func toValues() -> [String: Any] {
        var values: [String: Any] = extras

        for (purposeKey, purposeAccepted) in purposes {
            var node: [String: Any] = [ConsentState.keyIsAccept: purposeAccepted]
            for (fieldKey, decision) in fields[purposeKey] ?? [:] {
                var fieldNode: [String: Any] = [:]
                // Gia tri luon duoc gui du toggle bat hay tat (R4)...
                if let value = decision.value {
                    fieldNode[ConsentState.keyValue] = value
                }
                // ...con isAccept thi purpose tat la khong the true (R1).
                fieldNode[ConsentState.keyIsAccept] = purposeAccepted && decision.accepted
                node[fieldKey] = fieldNode
            }
            values[purposeKey] = node
        }
        return values
    }

    // MARK: - Noi bo

    private func anyFieldGranted(_ item: ConsentItem) -> Bool {
        item.dataFields.contains { isFieldGranted(item.key, $0.key) }
    }
}
