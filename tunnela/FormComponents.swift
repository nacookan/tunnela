import SwiftUI
import AppKit

// MARK: - FormSection

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 5)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal, 14)
        }
    }
}

// MARK: - FormRow

struct FormRow<Content: View>: View {
    let label: String
    let description: String?
    @ViewBuilder let content: () -> Content

    init(_ label: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.description = description
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13))
                if let desc = description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 160, alignment: .leading)
            .padding(.top, 1)

            VStack(alignment: .leading) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - SmallIntField

struct SmallIntField: View {
    @Binding var value: Int

    var body: some View {
        TextField("", text: Binding(
            get: { String(value) },
            set: { text in
                let digits = text.filter { $0.isNumber }
                if let n = Int(digits), n >= 0, n <= 65535 { value = n }
                else if digits.isEmpty { value = 0 }
            }
        ))
        .textFieldStyle(.plain)
        .frame(width: 80)
        .multilineTextAlignment(.leading)
    }
}

// MARK: - KeyPathField

struct KeyPathField: View {
    @Binding var path: String

    var body: some View {
        HStack(spacing: 6) {
            TextField("~/.ssh/id_rsa", text: $path)
                .textFieldStyle(.plain)
            Button(L10n.text("auth.select")) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.title = L10n.text("relay.key_file")
                panel.directoryURL = URL(fileURLWithPath: ("~/.ssh" as NSString).expandingTildeInPath)
                if panel.runModal() == .OK, let url = panel.url { path = url.path }
            }
            .controlSize(.small)
        }
    }
}

// MARK: - PasswordFormRow

struct PasswordFormRow: View {
    let label: String
    let description: String?
    let placeholder: String
    @Binding var value: String
    @Binding var promptEachTime: Bool
    var disabled: Bool = false

    init(_ label: String, description: String? = nil, placeholder: String,
         value: Binding<String>, promptEachTime: Binding<Bool>, disabled: Bool = false) {
        self.label = label
        self.description = description
        self.placeholder = placeholder
        self._value = value
        self._promptEachTime = promptEachTime
        self.disabled = disabled
    }

    var body: some View {
        FormRow(label, description: description) {
            VStack(alignment: .leading, spacing: 6) {
                SecureField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .disabled(disabled || promptEachTime)
                Toggle(L10n.text("auth.prompt_each"), isOn: $promptEachTime)
                    .toggleStyle(.checkbox)
                    .disabled(disabled)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - ModeSelector

struct ModeSelector: View {
    @Binding var mode: SideMode
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SideMode.allCases) { m in
                Button { mode = m } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.iconName)
                            .foregroundColor(mode == m
                                ? (m == .sideA ? .blue : .orange)
                                : .secondary)
                            .font(.system(size: 13, weight: .medium))
                        Text(m.shortName)
                            .foregroundColor(mode == m ? .primary : .secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(mode == m
                                ? Color(nsColor: .controlAccentColor).opacity(0.15)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(9)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5))
    }
}
