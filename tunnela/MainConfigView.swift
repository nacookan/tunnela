import SwiftUI

// MARK: - MainConfigView

struct MainConfigView: View {
    @EnvironmentObject var sshManager: SSHManager
    @Binding var config: TunnelConfig
    let isViewingActiveConnection: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    @State private var draftForward: ServiceForward? = nil

    var isConnected: Bool { sshManager.isActive }
    var canConnect: Bool {
        !config.relayHost.trimmingCharacters(in: .whitespaces).isEmpty &&
        !config.relayUsername.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if isViewingActiveConnection {
                ConnectionStatusBanner(sshManager: sshManager, onDisconnect: onDisconnect)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    roleSection
                    relaySection
                    if config.mode == .sideB {
                        hostCredentialsSection
                        serviceForwardsSection
                        socks5Section
                    }
                    if isViewingActiveConnection {
                        activeTunnelsSection
                    }
                    Spacer(minLength: 24)
                }
            }

            connectFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: 役割選択

    private var roleSection: some View {
        FormSection(L10n.text("section.role")) {
            FormRow(L10n.text("role.this_mac")) {
                VStack(alignment: .leading, spacing: 8) {
                    ModeSelector(mode: $config.mode, disabled: isConnected)
                    Text(config.mode == .sideA
                         ? L10n.text("role.host.desc")
                         : L10n.text("role.client.desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: 中継サーバー

    private var relaySection: some View {
        FormSection(L10n.text("section.relay")) {
            FormRow(L10n.text("relay.address")) {
                TextField("relay.example.com", text: $config.relayHost)
                    .textFieldStyle(.plain)
                    .disabled(isConnected)
            }
            Divider()
            FormRow(L10n.text("relay.ssh_port"), description: L10n.text("relay.ssh_port.desc")) {
                SmallIntField(value: $config.relayPort)
                    .disabled(isConnected)
            }
            Divider()
            FormRow(L10n.text("relay.username")) {
                TextField("user", text: $config.relayUsername)
                    .textFieldStyle(.plain)
                    .disabled(isConnected)
            }
            Divider()
            FormRow(L10n.text("relay.auth_method")) {
                Picker("", selection: $config.relayAuthType) {
                    ForEach(AuthType.allCases) { t in Text(t.displayName).tag(t) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .disabled(isConnected)
            }
            Divider()
            if config.relayAuthType == .key {
                FormRow(L10n.text("relay.key_file"), description: L10n.text("relay.key_file.desc")) {
                    KeyPathField(path: $config.relayKeyPath)
                        .disabled(isConnected)
                }
                Divider()
                PasswordFormRow(L10n.text("relay.passphrase"),
                                description: L10n.text("relay.passphrase.desc"),
                                placeholder: L10n.text("auth.passphrase.placeholder"),
                                value: $config.relayKeyPassphrase,
                                promptEachTime: $config.relayPromptSecret,
                                disabled: isConnected)
            } else {
                PasswordFormRow(L10n.text("relay.password_field"),
                                placeholder: L10n.text("auth.password.placeholder"),
                                value: $config.relayPassword,
                                promptEachTime: $config.relayPromptSecret,
                                disabled: isConnected)
            }
            Divider()
            FormRow(L10n.text("relay.internal_port"),
                    description: L10n.text("relay.internal_port.desc")) {
                SmallIntField(value: $config.relayInternalPort)
                    .disabled(isConnected)
            }
            if config.mode == .sideA {
                Divider()
                FormRow(L10n.text("relay.host_ssh_port"),
                        description: L10n.text("relay.ssh_port.desc")) {
                    SmallIntField(value: $config.hostSSHPort)
                        .disabled(isConnected)
                }
            }
        }
    }

    // MARK: ホストへの接続（クライアントのみ）

    private var hostCredentialsSection: some View {
        FormSection(L10n.text("section.host_conn")) {
            FormRow(L10n.text("host.username"),
                    description: L10n.text("host.username.desc")) {
                TextField("user", text: $config.hostUsername)
                    .textFieldStyle(.plain)
                    .disabled(isConnected)
            }
            Divider()
            FormRow(L10n.text("relay.auth_method")) {
                Picker("", selection: $config.hostAuthType) {
                    ForEach(AuthType.allCases) { t in Text(t.displayName).tag(t) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .disabled(isConnected)
            }
            Divider()
            if config.hostAuthType == .key {
                FormRow(L10n.text("host.key_file"),
                        description: L10n.text("host.key_file.desc")) {
                    KeyPathField(path: $config.hostKeyPath)
                        .disabled(isConnected)
                }
                Divider()
                PasswordFormRow(L10n.text("relay.passphrase"),
                                description: L10n.text("relay.passphrase.desc"),
                                placeholder: L10n.text("auth.passphrase.placeholder"),
                                value: $config.hostKeyPassphrase,
                                promptEachTime: $config.hostPromptSecret,
                                disabled: isConnected)
            } else {
                PasswordFormRow(L10n.text("relay.password_field"),
                                placeholder: L10n.text("auth.password.placeholder"),
                                value: $config.hostPassword,
                                promptEachTime: $config.hostPromptSecret,
                                disabled: isConnected)
            }
            Divider()
            FormRow(L10n.text("host.local_port"),
                    description: L10n.text("host.local_port.desc")) {
                SmallIntField(value: $config.localPort)
                    .disabled(isConnected)
            }
        }
    }

    // MARK: サービス転送（クライアントのみ）

    private var serviceForwardsSection: some View {
        let viewingActive = isViewingActiveConnection

        return FormSection(L10n.text("section.forwards")) {
            if config.serviceForwards.isEmpty && draftForward == nil {
                HStack {
                    Text(isConnected
                         ? L10n.text("forward.empty.active")
                         : L10n.text("forward.empty.idle"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(config.serviceForwards) { fwd in
                        ServiceForwardCard(
                            forward: bindingFor(fwd),
                            tunnelState: viewingActive ? sshManager.tunnelState(for: fwd.id) : nil,
                            onDelete: { removeServiceForward(id: fwd.id) }
                        )
                    }
                    if let _ = draftForward, viewingActive {
                        ServiceForwardDraftCard(
                            forward: Binding(
                                get: { draftForward ?? ServiceForward() },
                                set: { draftForward = $0 }
                            ),
                            onAdd: commitDraft,
                            onCancel: { draftForward = nil }
                        )
                    }
                }
                .disabled(isConnected && !viewingActive)
                .padding(8)
            }

            Divider()

            Button {
                if isConnected && viewingActive {
                    draftForward = ServiceForward()
                } else if !isConnected {
                    addServiceForward()
                }
            } label: {
                Label(L10n.text("forward.add"), systemImage: "plus.circle.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .disabled(draftForward != nil || (isConnected && !viewingActive))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: SOCKS5 プロキシ（クライアントのみ）

    private var socks5Section: some View {
        let viewingActive = isViewingActiveConnection
        let socks5State = sshManager.socks5TunnelState

        return FormSection(L10n.text("section.socks5")) {
            FormRow(L10n.text("socks5.enable"),
                    description: L10n.text("socks5.desc")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $config.socks5Enabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(isConnected && !viewingActive)
                            .onChange(of: config.socks5Enabled) { enabled in
                                guard viewingActive, isConnected else { return }
                                if enabled {
                                    if let activeConfig = sshManager.activeConfig {
                                        sshManager.startSocks5Tunnel(port: config.socks5Port, config: activeConfig)
                                    }
                                } else {
                                    sshManager.stopSocks5Tunnel()
                                }
                            }

                        if viewingActive, let state = socks5State {
                            HStack(spacing: 4) {
                                Image(systemName: state.symbolName)
                                Text(state.label)
                                    .font(.caption)
                            }
                            .foregroundColor({
                                switch state {
                                case .running: return Color.green
                                case .connecting: return Color.orange
                                case .failed: return Color.red
                                default: return Color.secondary
                                }
                            }())
                        }
                    }

                    if config.socks5Enabled {
                        HStack(spacing: 8) {
                            Text(L10n.text("socks5.port_label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SmallIntField(value: $config.socks5Port)
                                .disabled(sshManager.isSocks5Running || (isConnected && !viewingActive))
                                .frame(width: 80)
                        }
                    }
                }
            }
        }
    }

    // MARK: 稼働中トンネル一覧

    private var activeTunnelsSection: some View {
        FormSection(L10n.text("section.active_tunnels")) {
            VStack(spacing: 4) {
                ForEach(sshManager.tunnels) { tunnel in
                    TunnelRow(tunnel: tunnel)
                }
            }
            .padding(8)
        }
    }

    // MARK: フッター

    private var connectFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button(action: onConnect) {
                    Label(
                        isViewingActiveConnection
                            ? L10n.text("connect.reconnect")
                            : L10n.text("connect.start"),
                        systemImage: isViewingActiveConnection
                            ? "arrow.triangle.2.circlepath"
                            : "bolt.fill"
                    )
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(isViewingActiveConnection ? .orange : .accentColor)
                .disabled(!canConnect)
                .padding()
                Spacer()
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: サービスポート追加/削除

    private func addServiceForward() {
        config.serviceForwards.append(ServiceForward())
    }

    private func commitDraft() {
        guard let fwd = draftForward else { return }
        config.serviceForwards.append(fwd)
        if isViewingActiveConnection, let activeConfig = sshManager.activeConfig {
            sshManager.addServiceTunnel(fwd, config: activeConfig)
        }
        draftForward = nil
    }

    private func removeServiceForward(id: UUID) {
        config.serviceForwards.removeAll { $0.id == id }
        if isViewingActiveConnection {
            sshManager.removeServiceTunnel(forwardId: id)
        }
    }

    private func bindingFor(_ fwd: ServiceForward) -> Binding<ServiceForward> {
        Binding(
            get: { config.serviceForwards.first { $0.id == fwd.id } ?? fwd },
            set: { newVal in
                if let idx = config.serviceForwards.firstIndex(where: { $0.id == fwd.id }) {
                    config.serviceForwards[idx] = newVal
                }
            }
        )
    }
}
