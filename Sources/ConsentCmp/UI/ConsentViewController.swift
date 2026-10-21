#if canImport(UIKit)
import SwiftUI
import UIKit

/// Màn consent cho app UIKit (và cầu nối Flutter / React Native trên iOS) — app không phải tự viết
/// SwiftUI. Chế độ tự gửi: SDK hiện nút "Lưu lựa chọn" và tự gọi `/sendData`.
///
/// ```swift
/// let vc = ConsentViewController(values: ["email|EMAIL": email]) { state, result in
///     registerAccount(consentId: result.consentId)
/// }
/// present(vc, animated: true)   // gửi xong tự đóng nếu được present
/// ```
@available(iOS 14.0, *)
public final class ConsentViewController: UIHostingController<ConsentScreen> {

    public let model: ConsentFormModel

    public init(cmp: ConsentCmp = .shared,
                values: [String: String]? = nil,
                onError: ((ConsentError) -> Void)? = nil,
                onCompleted: ((ConsentState, SendConsentResult) -> Void)? = nil) {
        let model = ConsentFormModel(cmp: cmp)
        self.model = model
        super.init(rootView: ConsentScreen(model: model, values: values))
        model.onError = onError
        model.onSubmitted = { [weak self] state, result in
            onCompleted?(state, result)
            // Chỉ tự đóng khi được present; push vào navigation thì app tự pop.
            if self?.presentingViewController != nil {
                self?.dismiss(animated: true)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // Luôn lấy bản mới nhất khi mở: cấu hình có thể vừa đổi trên portal.
        Task { await model.load() }
    }
}

/// View gốc của `ConsentViewController`: cuộn được + `ConsentFormView` ở chế độ tự gửi.
@available(iOS 14.0, *)
public struct ConsentScreen: View {

    @ObservedObject var model: ConsentFormModel
    let values: [String: String]?

    public var body: some View {
        ScrollView {
            ConsentFormView(model: model, values: values)
                .padding(16)
        }
    }
}
#endif
