import SwiftUI

// MARK: - 接続中バナー

struct ConnectionStatusBanner: View {
    @ObservedObject var sshManager: SSHManager
    let onDisconnect: () -> Void

    @State private var pulsing = false

    private var statusText: String {
        let total = sshManager.tunnels.count
        let running = sshManager.runningCount
        if running == total {
            return L10n.format("banner.tunnels.all", total)
        }
        return L10n.format("banner.tunnels.partial", running, total)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulsing ? 1.6 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    if let mode = sshManager.activeConfig?.mode {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Text(L10n.text("banner.connected"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(.white.opacity(0.7))
                    Text(sshManager.activeConfig?.mode.modeName ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()

            if let config = sshManager.activeConfig {
                Text(verbatim: "\(config.relayUsername)@\(config.relayHost):\(config.relayInternalPort)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .textSelection(.enabled)
            }

            Button(action: onDisconnect) {
                Text(L10n.text("connect.disconnect"))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.55, blue: 0.2))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.72, blue: 0.35),
                         Color(red: 0.06, green: 0.58, blue: 0.25)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .onAppear { pulsing = true }
    }
}

// MARK: - TunnelRow

struct TunnelRow: View {
    @ObservedObject var tunnel: ManagedTunnel

    private var stateColor: Color {
        switch tunnel.state {
        case .stopped:    return .gray
        case .connecting: return .orange
        case .running:    return .green
        case .failed:     return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: tunnel.state.symbolName)
                    .foregroundColor(stateColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(tunnel.commandLine)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer()

                Text(tunnel.state.label)
                    .font(.caption)
                    .foregroundColor(stateColor)

                if !tunnel.state.isRunning {
                    Button(L10n.text("tunnel.restart")) { tunnel.restart() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            if !tunnel.lastError.isEmpty {
                Text(tunnel.lastError.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red)
                    .textSelection(.enabled)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(stateColor.opacity(0.25), lineWidth: 1))
    }
}
