import SwiftUI

/// Native accordion form shared by SwiftUI, UIKit and framework bridges.
/// Required-field validation and consent decisions remain in ConsentState.
@available(iOS 14.0, macOS 11.0, *)
public struct ConsentFormView: View {
    @ObservedObject private var model: ConsentFormModel
    private let themeOverride: ConsentTheme?
    private var theme: ConsentTheme { themeOverride ?? ConsentTheme(appearance: model.appearance) }
    private let strings: ConsentStrings
    private let showSectionTitle: Bool
    private let embeddedInForm: Bool
    private let thirdPartiesOnSharedOnly: Bool
    private let values: [String: String]?
    @State private var measuredWidth: CGFloat = 320
    @State private var embeddedListCollapsed: Bool
    @State private var fullDescriptions: Set<String> = []
    @ScaledMetric(relativeTo: .body) private var fontScale: CGFloat = 1

    public init(model: ConsentFormModel,
                theme: ConsentTheme? = nil,
                strings: ConsentStrings = ConsentStrings(),
                showSectionTitle: Bool = false,
                embeddedInForm: Bool = false,
                thirdPartiesOnSharedOnly: Bool = false,
                values: [String: String]? = nil) {
        self.model = model
        self.themeOverride = theme
        self.strings = strings
        self.showSectionTitle = showSectionTitle
        self.embeddedInForm = embeddedInForm
        self.thirdPartiesOnSharedOnly = thirdPartiesOnSharedOnly
        self.values = values
        _embeddedListCollapsed = State(initialValue: embeddedInForm)
    }

    private func appearanceFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let unscaled = size / max(0.01, fontScale)
        let role = unscaled >= 16 ? "title" : unscaled <= 12 ? "caption" : weight == .regular ? "body" : "button"
        let resolvedSize = CGFloat(model.appearance.size(role, fallback: Double(unscaled))) * fontScale
        let resolvedWeight = model.appearance.weight(role, fallback: weight == .regular ? 400 : weight == .semibold ? 600 : 700)
        let fontWeight: Font.Weight = resolvedWeight >= 700 ? .bold : resolvedWeight >= 600 ? .semibold : resolvedWeight >= 500 ? .medium : .regular
        if let name = model.appearance.fontName(weight: Int(resolvedWeight)) {
            return Font.custom(name, fixedSize: resolvedSize).weight(fontWeight)
        }
        return Font.system(size: resolvedSize, weight: fontWeight)
    }

    private var layout: ConsentLayout { ConsentLayout(width: measuredWidth) }
    private var items: [ConsentItem] { model.config?.items ?? [] }
    private var hidden: Bool { model.listHidden || (embeddedInForm && embeddedListCollapsed) }
    private var enabled: Bool { model.config?.isActive == true && !model.isLoading && !model.isSubmitting }
    private var canSubmit: Bool { enabled && model.hasAllRequired }
    private var largeText: Bool { fontScale > 1.2 }
    private func size(_ normal: CGFloat, _ compact: CGFloat) -> CGFloat {
        (layout.compact ? compact : normal) * fontScale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showSectionTitle {
                Text(strings.sectionTitle).font(appearanceFont(size: size(13, 12), weight: .bold))
            }
            VStack(alignment: .leading, spacing: 0) {
                if model.isLoading { loading }
                else if let config = model.config, config.isActive { content }
                else if model.config != nil { Text(strings.inactive).padding(24) }
                else if let error = model.errorMessage { failure(error) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.cardRadius).stroke(theme.border, lineWidth: 1))
        }
        .foregroundColor(theme.textPrimary)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: ConsentFormWidthKey.self, value: proxy.size.width)
        })
        .onPreferenceChange(ConsentFormWidthKey.self) { width in
            if width.isFinite && width > 0 && abs(width - measuredWidth) > 0.5 { measuredWidth = width }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !layout.wide || largeText {
                rule
                master.padding(.horizontal, layout.side).padding(.vertical, 8)
            }
            rule
            if !hidden {
                VStack(spacing: 0) {
                    ForEach(items, id: \.key) { item in
                        purpose(item)
                        if item.key != items.last?.key { rule }
                    }
                }.padding(layout.wide ? 12 : 0)
            }
            if (embeddedInForm || model.listHidden) && !items.isEmpty {
                if !hidden { rule }
                listButton
            }
            if let error = model.errorMessage {
                rule
                Text(error).font(appearanceFont(size: size(13, 12))).foregroundColor(theme.error)
                    .fixedSize(horizontal: false, vertical: true).padding(layout.side)
            }
            if !embeddedInForm { rule; actions.padding(layout.side) }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.config?.config?.title ?? strings.listTitle)
                    .font(appearanceFont(size: layout.wide ? 20 * fontScale : size(16, 14), weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let description = model.config?.config?.description, !description.isEmpty {
                    Text(description).font(appearanceFont(size: size(12, 11))).foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if layout.wide && !largeText { master.fixedSize() }
        }.padding(.horizontal, layout.side).padding(.vertical, 14)
    }

    private var master: some View {
        HStack(spacing: 12) {
            Text(strings.acceptAll).font(appearanceFont(size: size(14, 13), weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Toggle(strings.acceptAll, isOn: Binding(
                get: { model.state.isAllGranted },
                set: { model.setAllGranted($0, strings: strings) }
            )).labelsHidden().toggleStyle(SwitchToggleStyle(tint: theme.primary)).fixedSize().disabled(!enabled)
        }.frame(minHeight: 44)
    }

    private func purpose(_ item: ConsentItem) -> some View {
        let open = model.isExpanded(item.key)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { model.toggleExpanded(item.key) } label: {
                    HStack(spacing: 0) {
                        Image(systemName: open ? "chevron.down" : "chevron.right")
                            .font(appearanceFont(size: 12, weight: .semibold))
                            .foregroundColor(open ? theme.primary : theme.textSecondary)
                            .frame(width: layout.compact ? 32 : 40)
                            .opacity(model.hasBody(item) ? 1 : 0).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text((item.label ?? "") + (item.mustBeGranted ? " *" : ""))
                                .font(appearanceFont(size: size(14, 13), weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            if !open, let description = item.description, !description.isEmpty {
                                Text(description).font(appearanceFont(size: size(12, 11)))
                                    .foregroundColor(theme.textSecondary).lineLimit(layout.compact ? 2 : 1)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle()).disabled(!model.hasBody(item) || model.isSubmitting)
                    .accessibilityLabel(item.label ?? "")
                    .accessibilityValue(open ? strings.collapse : strings.expand)
                if layout.wide && open && !item.visibleDataFields.isEmpty {
                    Text("\(selectedFields(item))/\(item.visibleDataFields.count)")
                        .font(appearanceFont(size: size(12, 11), weight: .bold)).foregroundColor(theme.link)
                }
                Toggle(item.label ?? "", isOn: Binding(
                    get: { model.state.isGranted(item.key) },
                    set: { model.setPurpose(item, granted: $0, strings: strings) }
                )).labelsHidden().toggleStyle(SwitchToggleStyle(tint: theme.primary)).fixedSize().disabled(!enabled)
            }.padding(.trailing, layout.side).padding(.vertical, 6)
            if open { purposeBody(item) }
        }
        .background(open && !layout.wide ? theme.surface : theme.background)
        .overlay(RoundedRectangle(cornerRadius: theme.fieldRadius)
            .stroke(layout.wide ? theme.border : Color.clear, lineWidth: 1))
    }

    private func purposeBody(_ item: ConsentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let description = item.description, !description.isEmpty {
                Text(description).font(appearanceFont(size: size(12, 11)))
                    .lineLimit(description.count > 180 && !fullDescriptions.contains(item.key) ? 3 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                if description.count > 180 {
                    Button(fullDescriptions.contains(item.key) ? strings.collapse : strings.showMore) {
                        if fullDescriptions.contains(item.key) { fullDescriptions.remove(item.key) }
                        else { fullDescriptions.insert(item.key) }
                    }.buttonStyle(PlainButtonStyle()).font(appearanceFont(size: size(12, 11), weight: .bold))
                        .foregroundColor(theme.link).frame(minHeight: 32)
                }
            }
            if layout.wide && !largeText {
                HStack(alignment: .top, spacing: 12) {
                    parties(item, availableWidth: max(1, bodyWidth - selectionButtonWidth(item) - 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !item.visibleDataFields.isEmpty { selectAll(item).fixedSize(horizontal: true, vertical: false) }
                }
            } else { parties(item) }
            if !item.visibleDataFields.isEmpty {
                if largeText {
                    VStack(alignment: .leading, spacing: 4) { fieldsCount(item); selectAll(item) }
                } else if !layout.wide {
                    HStack(spacing: 8) {
                        fieldsCount(item)
                        Spacer(minLength: 4)
                        selectAll(item)
                    }
                }
                fields(item)
            }
        }.padding(.leading, layout.bodyInset).padding(.trailing, layout.side).padding(.bottom, 14)
    }

    private func fieldsCount(_ item: ConsentItem) -> some View {
        Text(String(format: strings.fieldsCount, selectedFields(item), item.visibleDataFields.count))
            .font(appearanceFont(size: size(12, 11), weight: .bold)).fixedSize(horizontal: false, vertical: true)
    }
    private func selectAll(_ item: ConsentItem) -> some View {
        let all = selectedFields(item) == item.visibleDataFields.count
        return Button(all ? strings.deselectAll : strings.selectAll) {
            model.setAllFields(item, granted: !all, strings: strings)
        }.buttonStyle(PlainButtonStyle()).font(appearanceFont(size: size(12, 11), weight: .bold))
            .foregroundColor(theme.link).fixedSize(horizontal: false, vertical: true).frame(minHeight: 36).disabled(!enabled)
    }
    private var bodyWidth: CGFloat {
        max(1, measuredWidth - layout.bodyInset - layout.side - (layout.wide ? 24 : 0))
    }

    private func selectionButtonWidth(_ item: ConsentItem) -> CGFloat {
        guard !item.visibleDataFields.isEmpty else { return 0 }
        let all = selectedFields(item) == item.visibleDataFields.count
        return ConsentLayout.textWidth(all ? strings.deselectAll : strings.selectAll, size: size(12, 11), bold: true)
    }

    private func parties(_ item: ConsentItem, availableWidth: CGFloat? = nil) -> some View {
        let names = sharedWith(item)
        let labels = names.isEmpty ? [] : [strings.sharedWith] + names
        let limit = availableWidth ?? bodyWidth
        let fontSize = CGFloat(model.appearance.size("caption", fallback: Double(layout.compact ? 10 : 11))) * fontScale
        let widths = labels.enumerated().map { index, text in
            ConsentLayout.textWidth(text, size: fontSize, fontName: model.appearance.fontName(weight: 400)) + (index == 0 ? 0 : 16)
        }
        return VStack(alignment: .leading, spacing: 6) {
            if !names.isEmpty {
                ForEach(Array(ConsentLayout.rows(widths: widths, availableWidth: limit).enumerated()), id: \.offset) { row in
                    HStack(alignment: .center, spacing: 8) {
                        ForEach(row.element, id: \.self) { index in
                            Text(labels[index]).font(appearanceFont(size: fontSize))
                                .foregroundColor(index == 0 ? theme.textSecondary : theme.chipText)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, index == 0 ? 0 : 8).padding(.vertical, 4)
                                .frame(width: min(widths[index], limit), alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: theme.chipRadius)
                                    .fill(index == 0 ? Color.clear : theme.chipBackground))
                                .overlay(RoundedRectangle(cornerRadius: theme.chipRadius)
                                    .stroke(index == 0 ? Color.clear : theme.chipBorder, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private func fields(_ item: ConsentItem) -> some View {
        let widths = item.visibleDataFields.map { field -> CGFloat in
            let selected = model.state.isFieldGranted(item.key, field.key)
            return ConsentLayout.textWidth(field.displayName + (field.required ? " *" : ""),
                size: size(13, 12), bold: selected) + (layout.compact ? 20 : 28)
                + (selected ? size(13, 12) + 6 : 0)
        }
        return Group {
            if layout.wide {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 2) {
                    ForEach(item.visibleDataFields, id: \.key) { field in fieldButton(item, field, checkbox: true) }
                }.padding(12).background(RoundedRectangle(cornerRadius: theme.fieldRadius).stroke(theme.border))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(ConsentLayout.rows(widths: widths, availableWidth: bodyWidth).enumerated()), id: \.offset) { row in
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(row.element, id: \.self) { index in
                                fieldButton(item, item.visibleDataFields[index], checkbox: false)
                                    .frame(width: min(widths[index], bodyWidth), alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private func fieldButton(_ item: ConsentItem, _ field: ConsentField, checkbox: Bool) -> some View {
        let selected = model.state.isFieldGranted(item.key, field.key)
        return Button { model.setField(item, field, granted: !selected, strings: strings) } label: {
            HStack(spacing: 6) {
                if checkbox || selected {
                    Image(systemName: checkbox ? (selected ? "checkmark.square.fill" : "square") : "checkmark")
                        .font(appearanceFont(size: size(13, 12), weight: .semibold)).accessibilityHidden(true)
                }
                Text(field.displayName + (field.required ? " *" : ""))
                    .font(appearanceFont(size: size(13, 12), weight: selected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            }
            .foregroundColor(selected ? theme.primary : theme.textPrimary)
            .padding(.horizontal, checkbox ? 0 : layout.compact ? 10 : 14).padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(Capsule().fill(checkbox ? Color.clear : selected ? theme.selectedBackground : theme.background))
            .overlay(Capsule().stroke(checkbox ? Color.clear : selected ? theme.selectedBorder : theme.fieldBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(PlainButtonStyle()).disabled(!enabled)
            .accessibilityValue(selected ? strings.selected : strings.notSelected)
    }

    private var listButton: some View {
        Button {
            if model.listHidden { model.listHidden = false; embeddedListCollapsed = false }
            else { embeddedListCollapsed.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(hidden ? String(format: strings.showPurposes, items.count) : strings.collapse)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: hidden ? "chevron.down" : "chevron.up").accessibilityHidden(true)
            }.font(appearanceFont(size: size(13, 12), weight: .bold)).foregroundColor(theme.link)
                .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(PlainButtonStyle()).background(theme.surface).disabled(model.isSubmitting)
    }
    private var summary: some View {
        Text(String(format: strings.selectedSummary, items.filter { model.state.isGranted($0.key) }.count, items.count))
            .font(appearanceFont(size: size(12, 11))).foregroundColor(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
    private var submit: some View {
        Button { model.submit(strings: strings, values: values) } label: {
            HStack(spacing: 8) {
                if model.isSubmitting { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                Text(model.config?.config?.submitLabel ?? strings.submit)
                    .font(appearanceFont(size: size(13, 12), weight: .bold)).fixedSize(horizontal: false, vertical: true)
            }.foregroundColor(.white).padding(.horizontal, 22).padding(.vertical, 12).frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: theme.fieldRadius).fill(canSubmit || model.isSubmitting ? theme.primary : theme.border))
        }.buttonStyle(PlainButtonStyle()).disabled(!canSubmit)
    }
    @ViewBuilder private var actions: some View {
        if layout.compact || largeText { VStack(alignment: .leading, spacing: 12) { summary; submit } }
        else { HStack(spacing: 12) { summary; submit } }
    }
    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(strings.loading).font(appearanceFont(size: size(13, 12))).foregroundColor(theme.textSecondary)
        }.padding(32).frame(maxWidth: .infinity)
    }
    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message).foregroundColor(theme.error).fixedSize(horizontal: false, vertical: true)
            Button(strings.retry) { Task { await model.load() } }.foregroundColor(theme.link).frame(minHeight: 44)
        }.font(appearanceFont(size: size(13, 12))).padding(24).frame(maxWidth: .infinity)
    }
    private var rule: some View { Rectangle().fill(theme.border).frame(height: 1) }
    private func selectedFields(_ item: ConsentItem) -> Int {
        item.visibleDataFields.filter { model.state.isFieldGranted(item.key, $0.key) }.count
    }
    private func sharedWith(_ item: ConsentItem) -> [String] {
        if thirdPartiesOnSharedOnly && !item.visibleDataFields.contains(where: { $0.sharedWithSystem }) { return [] }
        return item.thirdParties.reduce(into: [String]()) { result, value in
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
    }
}

private struct ConsentFormWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
