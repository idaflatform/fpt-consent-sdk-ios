import Foundation

/// Chay mot fixture cua `consent-sdk-spec` tren core Swift.
///
/// De trong target thu vien (thay vi trong test) de ca `swift run ConsentFixtureRunner` lan XCTest
/// deu dung chung mot doan logic — kiem chung y het runner Java va TypeScript.
public enum FixtureCase {

    /// - Returns: danh sach cho lech; rong nghia la pass.
    public static func run(_ fixture: [String: Any]) -> [String] {
        guard let configJson = fixture["config"] as? [String: Any] else {
            return ["fixture thieu config"]
        }
        let config = ConsentParser.parseConfig(configJson)
        let configAfter = (fixture["configAfter"] as? [String: Any]).map(ConsentParser.parseConfig)

        var state = (fixture["start"] as? String) == "empty"
            ? ConsentState()
            : ConsentState.defaults(of: config)
        var active = config
        var lastResult: ConsentState.ToggleResult?

        for action in (fixture["actions"] as? [[String: Any]]) ?? [] {
            let op = (action["op"] as? String) ?? ""
            let purpose = (action["purpose"] as? String) ?? ""
            let field = (action["field"] as? String) ?? ""
            let value = (action["value"] as? Bool) ?? false

            switch op {
            case "purposeToggle":
                lastResult = state.applyPurposeToggle(active, purpose, value)
            case "fieldToggle":
                lastResult = state.applyFieldToggle(active, purpose, field, value)
            case "acceptAll":
                state.applyAcceptAll(active)
                lastResult = .applied
            case "rejectAll":
                lastResult = state.applyRejectAll(active)
            case "setGranted":
                state.setGranted(purpose, value)
            case "setFieldGranted":
                state.setFieldGranted(purpose, field, value)
            case "setFieldValue":
                state.setFieldValue(purpose, field, action["value"] as? String)
            case "merge":
                guard let next = configFor(action, config, configAfter) else {
                    return ["fixture thieu configAfter"]
                }
                active = next
                state = ConsentState.merge(active, saved: state)
            case "retainOnly":
                guard let next = configFor(action, config, configAfter) else {
                    return ["fixture thieu configAfter"]
                }
                active = next
                state.retainOnly(active)
            default:
                return ["op khong ho tro: \(op)"]
            }
        }

        let expect = (fixture["expect"] as? [String: Any]) ?? [:]
        var problems: [String] = []

        if let wantResult = expect["lastResult"] as? String {
            let got = lastResult?.rawValue ?? "null"
            if wantResult != got {
                problems.append("lastResult: mong \(wantResult), nhan \(got)")
            }
        }

        let missing = state.firstMissing(active)
        if let wantMissing = expect["missing"] as? [String: Any] {
            if let missing = missing {
                let wantPurpose = wantMissing["purpose"] as? String
                let wantField = wantMissing["field"] as? String
                let gotField = missing.field?.key
                if wantPurpose != missing.item.key || wantField != gotField {
                    problems.append("missing: mong \(wantPurpose ?? "nil")/\(wantField ?? "nil"), "
                                    + "nhan \(missing.item.key)/\(gotField ?? "nil")")
                }
            } else {
                problems.append("missing: mong \(wantMissing), nhan nil")
            }
        } else if let missing = missing {
            problems.append("missing: mong null, nhan \(missing.item.key)/\(missing.field?.key ?? "nil")")
        }

        if let wantValues = expect["values"] as? [String: Any] {
            if let diff = diff(expected: wantValues, actual: state.toValues(), path: "values") {
                problems.append(diff)
            }
        }
        return problems
    }

    private static func configFor(_ action: [String: Any], _ config: ConsentConfig,
                                  _ after: ConsentConfig?) -> ConsentConfig? {
        if (action["config"] as? String) == "after" {
            return after
        }
        return config
    }

    /// So sanh theo noi dung, khong theo thu tu khoa; khoa la trong ket qua cung la fail.
    private static func diff(expected: Any, actual: Any?, path: String) -> String? {
        if let expectedObject = expected as? [String: Any] {
            guard let actualObject = actual as? [String: Any] else {
                return "\(path): mong object, nhan \(String(describing: actual))"
            }
            for (key, value) in expectedObject {
                guard actualObject.keys.contains(key) else {
                    return "\(path).\(key): thieu trong ket qua"
                }
                if let problem = diff(expected: value, actual: actualObject[key], path: "\(path).\(key)") {
                    return problem
                }
            }
            for key in actualObject.keys where expectedObject[key] == nil {
                return "\(path).\(key): khoa la trong ket qua (khong co trong expect)"
            }
            return nil
        }
        if let expectedBool = expected as? Bool {
            guard let actualBool = actual as? Bool, actualBool == expectedBool else {
                return "\(path): mong \(expectedBool), nhan \(String(describing: actual))"
            }
            return nil
        }
        if let expectedText = expected as? String {
            guard let actualText = actual as? String, actualText == expectedText else {
                return "\(path): mong \"\(expectedText)\", nhan \(String(describing: actual))"
            }
            return nil
        }
        return "\(path): kieu expect khong ho tro"
    }
}
