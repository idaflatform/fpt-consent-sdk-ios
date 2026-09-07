import SwiftUI

/// Khoi UI "Danh sách sự đồng ý": header điều khiển, danh sách mục đích (thu gọn / mở rộng),
/// mỗi mục đích có các trường dữ liệu kèm chip bên thứ ba và toggle riêng.
///
/// View chỉ vẽ; mọi quy tắc nằm trong `ConsentState` nên giống hệt Android và Zalo Mini App.
///
/// Hai chế độ, giống bản Android:
/// - `embeddedInForm = false` (mặc định): hiện nút "Từ chối tất cả" / "Đồng ý", tự gọi `/sendData`.
/// - `embeddedInForm = true`: ẩn nút của SDK, app tự gọi `cmp.submit(&state)` khi bấm nút của mình.
@available(iOS 14.0, macOS 11.0, *)
public struct ConsentFormView: View {

    @ObservedObject private var model: ConsentFormModel
    private let theme: ConsentTheme
    private let strings: ConsentStrings
    private let showSectionTitle: Bool
    private let embeddedInForm: Bool
    /// false (mặc định) = chip bên thứ ba hiện dưới MỌI trường của mục đích, giống portal/web.
    private let thirdPartiesOnSharedOnly: Bool

    public init(model: ConsentFormModel,
                theme: ConsentTheme = ConsentTheme(),
                strings: ConsentStrings = ConsentStrings(),
                showSectionTitle: Bool = true,
                embeddedInForm: Bool = false,
                thirdPartiesOnSharedOnly: Bool = false) {
        self.model = model
        self.theme = theme
        self.strings = strings
        self.showSectionTitle = showSectionTitle
        self.embeddedInForm = embeddedInForm
        self.thirdPartiesOnSharedOnly = thirdPartiesOnSharedOnly
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showSectionTitle {
                Text(strings.sectionTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                header

                if let description = model.config?.config?.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(theme.accent)
                }

                if !model.listHidden {
                    ForEach(model.config?.items ?? [], id: \.key) { item in
                        purposeCard(item)
                    }
                }

                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(theme.error)
                }

                if !embeddedInForm {
                    actions
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.cardRadius)
                    .fill(theme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cardRadius)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(model.config?.config?.title ?? strings.listTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 4)

            Button(model.listHidden ? strings.showList : strings.hideList) {
                model.listHidden.toggle()
            }
            .font(.system(size: 13))
            .foregroundColor(theme.linkAlt)

            Button(model.allCollapsed ? strings.expand : strings.collapse) {
                model.setAllCollapsed(!model.allCollapsed)
            }
            .font(.system(size: 13))
            .foregroundColor(theme.link)

            Text(strings.acceptAll)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)

            Toggle("", isOn: Binding(
                get: { model.state.isAllGranted },
                set: { model.setAllGranted($0, strings: strings) }
            ))
            .labelsHidden()
        }
    }

    // MARK: - Purpose

    private func purposeCard(_ item: ConsentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(item.label ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                if item.required {
                    chip(strings.mandatory)
                }

                Spacer(minLength: 4)

                if !item.dataFields.isEmpty {
                    Button(model.isExpanded(item.key) ? strings.collapse : strings.expand) {
                        model.toggleExpanded(item.key)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(theme.linkAlt)
                }

                Toggle("", isOn: Binding(
                    get: { model.state.isGranted(item.key) },
                    set: { model.setPurpose(item, granted: $0, strings: strings) }
                ))
                .labelsHidden()
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(theme.primary)
            }

            if model.isExpanded(item.key) && !item.dataFields.isEmpty {
                Divider().background(theme.border)
                ForEach(item.dataFields, id: \.key) { field in
                    fieldRow(item, field)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: theme.cardRadius)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cardRadius)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Field

    private func fieldRow(_ item: ConsentItem, _ field: ConsentField) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(field.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    if field.required {
                        chip(strings.mandatory)
                    }
                }

                // Chip bên thứ ba nằm ngay dưới tên trường (giống portal/web).
                if showThirdParties(field: field, item: item) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.thirdParties, id: \.self) { name in
                                chip(name)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Toggle("", isOn: Binding(
                get: { model.state.isFieldGranted(item.key, field.key) },
                set: { model.setField(item, field, granted: $0, strings: strings) }
            ))
            .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: theme.fieldRadius)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.fieldRadius)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }

    private func showThirdParties(field: ConsentField, item: ConsentItem) -> Bool {
        !item.thirdParties.isEmpty && (!thirdPartiesOnSharedOnly || field.sharedWithSystem)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(theme.chipText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: theme.chipRadius)
                    .fill(theme.chipBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.chipRadius)
                            .stroke(theme.chipBorder, lineWidth: 1)
                    )
            )
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(strings.rejectAll) {
                model.rejectAllAndSubmit(strings: strings)
            }
            .font(.system(size: 13))
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.fieldRadius)
                    .stroke(theme.border, lineWidth: 1)
            )
            .disabled(model.isSubmitting)

            Button(model.config?.config?.submitLabel ?? strings.submit) {
                model.submit(strings: strings)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.fieldRadius)
                    .fill(model.isSubmitting ? theme.border : theme.primary)
            )
            .disabled(model.isSubmitting)

            if model.isSubmitting {
                ProgressView()
            }
        }
    }
}
