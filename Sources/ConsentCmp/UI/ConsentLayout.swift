import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Use the form width in points, matching Android's dp breakpoints.
struct ConsentLayout {
    let width: CGFloat
    var compact: Bool { width < 360 }
    var wide: Bool { width >= 560 }
    var side: CGFloat { wide ? 20 : compact ? 12 : 16 }
    var bodyInset: CGFloat { wide ? 40 : 16 }

    static func rows(widths: [CGFloat], availableWidth: CGFloat, spacing: CGFloat = 8) -> [[Int]] {
        let limit = max(1, availableWidth)
        var rows: [[Int]] = [], row: [Int] = []
        var used: CGFloat = 0
        for (index, width) in widths.enumerated() {
            let itemWidth = min(max(0, width), limit)
            if !row.isEmpty && used + spacing + itemWidth > limit {
                rows.append(row); row = []; used = 0
            }
            used += (row.isEmpty ? 0 : spacing) + itemWidth
            row.append(index)
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    static func textWidth(_ text: String, size: CGFloat, bold: Bool = false, fontName: String? = nil) -> CGFloat {
        #if canImport(UIKit)
        let font = fontName.flatMap { UIFont(name: $0, size: size) } ?? UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        #elseif canImport(AppKit)
        let font = fontName.flatMap { NSFont(name: $0, size: size) } ?? NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        #endif
        #if canImport(UIKit) || canImport(AppKit)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
        #else
        return CGFloat(text.count) * size
        #endif
    }
}
