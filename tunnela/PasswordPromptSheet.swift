import SwiftUI

struct PasswordPromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    let config: TunnelConfig
    let onConnect: (TunnelConfig) -> Void
    let onCancel: () -> Void

    @State private var relaySecret = ""
    @State private var hostSecret = ""

    private var needsRelaySecret: Bool { config.relayPromptSecret }
    private var needsHostSecret: Bool { config.mode == .sideB && config.hostPromptSecret }

    private var relayLabel: String {
        switch config.relayAuthType {
        case .password:
            return L10n.format("prompt.relay.password.label", config.relayUsername, config.relayHost)
        case .key:
            let name = URL(fileURLWithPath: config.relayKeyPath).lastPathComponent
            return L10n.format("prompt.relay.passphrase.label", name)
        }
    }

    private var hostLabel: String {
        switch config.hostAuthType {
        case .password:
            return L10n.format("prompt.host.password.label", config.hostUsername)
        case .key:
            let name = URL(fileURLWithPath: config.hostKeyPath).lastPathComponent
            return L10n.format("prompt.host.passphrase.label", name)
        }
    }

    private var canConnect: Bool {
        (!needsRelaySecret || !relaySecret.isEmpty) &&
        (!needsHostSecret  || !hostSecret.isEmpty)
    }

    private func doConnect() {
        guard canConnect else { return }
        var c = config
        if needsRelaySecret {
            switch config.relayAuthType {
            case .password: c.relayPassword      = relaySecret
            case .key:      c.relayKeyPassphrase = relaySecret
            }
        }
        if needsHostSecret {
            switch config.hostAuthType {
            case .password: c.hostPassword      = hostSecret
            case .key:      c.hostKeyPassphrase = hostSecret
            }
        }
        onConnect(c)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("prompt.title"))
                        .font(.headline)
                    Text(L10n.text("prompt.subtitle"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                if needsRelaySecret {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("prompt.section.relay"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        SecureField(relayLabel, text: $relaySecret)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { doConnect() }
                    }
                }
                if needsHostSecret {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("prompt.section.host"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        SecureField(hostLabel, text: $hostSecret)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { doConnect() }
                    }
                }
            }
            .padding(24)

            Divider()

            HStack {
                Button(L10n.text("common.cancel")) { onCancel() }
                Spacer()
                Button(L10n.text("prompt.connect")) { doConnect() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConnect)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 400)
    }
}
