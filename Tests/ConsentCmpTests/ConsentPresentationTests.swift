import XCTest
import Foundation
@testable import ConsentCmp

final class ConsentPresentationTests: XCTestCase {
    func testBreakpointsUseFormWidth() {
        XCTAssertTrue(ConsentLayout(width: 312).compact)
        XCTAssertFalse(ConsentLayout(width: 360).compact)
        XCTAssertFalse(ConsentLayout(width: 559).wide)
        XCTAssertTrue(ConsentLayout(width: 560).wide)
    }

    func testWrappingPreservesOrderAndFitsEveryRow() {
        let widths: [CGFloat] = [90, 110, 400, 55, 95]
        for available: CGFloat in [1, 180, 280, 640] {
            let rows = ConsentLayout.rows(widths: widths, availableWidth: available)
            XCTAssertEqual(rows.flatMap { $0 }, Array(widths.indices))
            for row in rows {
                let total = row.reduce(CGFloat(0)) { $0 + min(widths[$1], available) }
                    + CGFloat(max(0, row.count - 1)) * 8
                XCTAssertLessThanOrEqual(total, available)
            }
        }
        XCTAssertEqual(ConsentLayout.rows(widths: [], availableWidth: 312), [])
    }

    func testAccordionOpensFirstBodyAndKeepsOnlyOneOpen() {
        let model = makeModel()
        model.applyLoadedConfig(config())
        XCTAssertTrue(model.isExpanded("registration"))
        XCTAssertFalse(model.isExpanded("marketing"))
        model.toggleExpanded("marketing")
        XCTAssertFalse(model.isExpanded("registration"))
        XCTAssertTrue(model.isExpanded("marketing"))
        model.toggleExpanded("marketing")
        XCTAssertTrue(model.allCollapsed)
        model.setAllCollapsed(false)
        XCTAssertTrue(model.isExpanded("registration"))
        XCTAssertFalse(model.isExpanded("marketing"))
    }

    func testSelectAllPreservesRequiredFieldsAndIgnoresHiddenFields() {
        let model = makeModel()
        let fixture = config()
        let item = fixture.items[0]
        model.applyLoadedConfig(fixture)
        model.setAllFields(item, granted: true, strings: ConsentStrings())
        XCTAssertTrue(model.state.isFieldGranted(item.key, "email"))
        XCTAssertTrue(model.state.isFieldGranted(item.key, "phone"))
        XCTAssertFalse(model.state.isFieldGranted(item.key, "hidden"))
        model.setAllFields(item, granted: false, strings: ConsentStrings())
        XCTAssertTrue(model.state.isFieldGranted(item.key, "email"))
        XCTAssertFalse(model.state.isFieldGranted(item.key, "phone"))
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.hasAllRequired)
    }

    func testReloadedConfigurationResetsAccordionAndErrors() {
        let model = makeModel()
        model.applyLoadedConfig(config())
        model.toggleExpanded("marketing")
        model.errorMessage = "Old error"
        model.applyLoadedConfig(config())
        XCTAssertTrue(model.isExpanded("registration"))
        XCTAssertNil(model.errorMessage)
        model.applyLoadedConfig(ConsentConfig(code: "empty", name: nil, status: "active", fields: [], config: nil))
        XCTAssertTrue(model.allCollapsed)
        XCTAssertFalse(model.isExpanded("registration"))
    }

    private func makeModel() -> ConsentFormModel {
        ConsentFormModel(cmp: ConsentCmp(options: ConsentOptions(codeConfig: "cp_demo::t_demo"), storage: MemoryStorage()))
    }

    private func config() -> ConsentConfig {
        ConsentParser.parseConfig([
            "code": "cp_demo::t_demo", "status": "active",
            "config": ["items": [
                ["id": "registration", "code": "registration", "label": "Đăng ký tài khoản mẫu", "required": true,
                 "dataFields": [
                    ["id": "email", "name": "Email", "required": true, "display": true],
                    ["id": "phone", "name": "PhoneNumber", "display": true],
                    ["id": "hidden", "name": "Internal", "display": false]
                 ]],
                ["id": "marketing", "code": "marketing", "label": "Giới thiệu sản phẩm", "description": "Tùy chọn"]
            ]]
        ])
    }
}
