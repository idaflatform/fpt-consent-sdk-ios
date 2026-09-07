import Foundation
import Combine

/// State holder cho `ConsentFormView`.
///
/// Moi thao tac cua nguoi dung deu di qua `ConsentState` (core dung chung voi Android / Zalo Mini App);
/// model nay chi giu trang thai hien thi (dang mo rong hay khong, dang gui hay khong) va thong bao loi.
@available(iOS 14.0, macOS 11.0, *)
public final class ConsentFormModel: ObservableObject {

    @Published public private(set) var config: ConsentConfig?
    @Published public private(set) var state = ConsentState()
    @Published public var errorMessage: String?
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSubmitting = false
    @Published public var listHidden = false
    @Published public private(set) var allCollapsed = false

    /// Goi khi SDK tu gui xong (che do khong nam trong form cua app).
    public var onSubmitted: ((ConsentState, SendConsentResult) -> Void)?
    /// Goi khi tai cau hinh hoac gui that bai.
    public var onError: ((ConsentError) -> Void)?

    private let cmp: ConsentCmp
    private var collapsed: Set<String> = []

    public init(cmp: ConsentCmp) {
        self.cmp = cmp
    }

    /// Trang thai hien tai — app dung khi tu gui (`embeddedInForm = true`).
    public var currentState: ConsentState { state }

    /// Muc bat buoc dau tien con thieu; nil khi duoc phep submit.
    public var missingRequired: ConsentState.MissingRequired? {
        state.firstMissing(config)
    }

    /// True khi moi muc dich VA truong du lieu bat buoc da duoc dong y.
    public var hasAllRequired: Bool { missingRequired == nil }

    /// Thong bao cho muc bat buoc con thieu; nil khi du dieu kien submit.
    /// Tuong duong `ConsentFormView.requiredMessage()` ben Android.
    public func requiredMessage(_ strings: ConsentStrings = ConsentStrings()) -> String? {
        missingRequired.map { strings.requiredMessage($0) }
    }

    /// Ban tien loi cho SwiftUI (`if let hint = model.requiredHint`).
    public var requiredHint: String? { requiredMessage() }

    // MARK: - Tai cau hinh

    /// Tai `/config` (luon goi mang) roi dung trang thai ban dau.
    @MainActor
    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let config = try await cmp.fetchConfig()
            self.config = config
            self.state = cmp.initialState(config)
        } catch let error as ConsentError {
            errorMessage = error.message
            onError?(error)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Thao tac cua nguoi dung

    public func setPurpose(_ item: ConsentItem, granted: Bool, strings: ConsentStrings) {
        let result = state.applyPurposeToggle(config, item.key, granted)
        showBlockedMessage(result, item: item, field: item.required ? nil : item.firstRequiredField,
                           strings: strings)
    }

    public func setField(_ item: ConsentItem, _ field: ConsentField, granted: Bool,
                         strings: ConsentStrings) {
        let result = state.applyFieldToggle(config, item.key, field.key, granted)
        showBlockedMessage(result, item: item, field: field, strings: strings)
    }

    public func setAllGranted(_ granted: Bool, strings: ConsentStrings) {
        if granted {
            state.applyAcceptAll(config)
            errorMessage = nil
        } else {
            let result = state.applyRejectAll(config)
            errorMessage = result == .blockedRequired ? lockedNotice(strings) : nil
        }
    }

    public func isExpanded(_ purposeKey: String) -> Bool {
        !collapsed.contains(purposeKey)
    }

    public func toggleExpanded(_ purposeKey: String) {
        if collapsed.contains(purposeKey) {
            collapsed.remove(purposeKey)
        } else {
            collapsed.insert(purposeKey)
        }
        objectWillChange.send()
    }

    public func setAllCollapsed(_ value: Bool) {
        allCollapsed = value
        collapsed = value ? Set((config?.items ?? []).map { $0.key }) : []
    }

    // MARK: - Gui

    /// Kiem tra muc bat buoc va hien loi ngay tren form neu thieu.
    @discardableResult
    public func validateRequired(strings: ConsentStrings = ConsentStrings()) -> Bool {
        if let missing = missingRequired {
            errorMessage = strings.requiredMessage(missing)
            return false
        }
        errorMessage = nil
        return true
    }

    /// SDK tu gui — dung o che do khoi consent dung doc lap.
    public func submit(strings: ConsentStrings) {
        guard validateRequired(strings: strings) else { return }
        Task { @MainActor in
            isSubmitting = true
            do {
                var working = state
                let result = try await cmp.submit(&working)
                state = working
                errorMessage = nil
                onSubmitted?(working, result)
            } catch let error as ConsentError {
                errorMessage = error.message
                onError?(error)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// "Tu choi tat ca" cung la mot quyet dinh -> van ghi nhan bang chung.
    public func rejectAllAndSubmit(strings: ConsentStrings) {
        setAllGranted(false, strings: strings)
        submit(strings: strings)
    }

    // MARK: - Noi bo

    private func showBlockedMessage(_ result: ConsentState.ToggleResult, item: ConsentItem,
                                    field: ConsentField?, strings: ConsentStrings) {
        guard result == .blockedRequired else {
            errorMessage = nil
            return
        }
        errorMessage = strings.requiredMessage(
            ConsentState.MissingRequired(item: item, field: field))
    }

    /// Thong bao ve muc bat buoc khong the tu choi.
    private func lockedNotice(_ strings: ConsentStrings) -> String? {
        for item in config?.items ?? [] {
            if item.required {
                return strings.requiredMessage(ConsentState.MissingRequired(item: item, field: nil))
            }
            if let field = item.firstRequiredField {
                return strings.requiredMessage(ConsentState.MissingRequired(item: item, field: field))
            }
        }
        return nil
    }
}
