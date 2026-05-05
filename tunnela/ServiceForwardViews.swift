import SwiftUI

// MARK: - ServiceForwardCard

struct ServiceForwardCard: View {
    @Binding var forward: ServiceForward
    let tunnelState: TunnelState?
    let onDelete: () -> Void

    private var isTracked: Bool { tunnelState != nil }

    private var stateColor: Color {
        switch tunnelState {
        case .running:    return .green
        case .connecting: return .orange
        case .failed:     return .red
        case .stopped, nil: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(L10n.text("forward.name.placeholder"), text: $forward.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .disabled(isTracked)

                Spacer()

                if let state = tunnelState {
                    HStack(spacing: 4) {
                        Image(systemName: state.symbolName)
                            .foregroundColor(stateColor)
                        Text(state.label)
                            .font(.caption)
                            .foregroundColor(stateColor)
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help(isTracked ? L10n.text("forward.delete.tip") : L10n.text("forward.delete"))
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("forward.host_port"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SmallIntField(value: $forward.targetPort)
                        .disabled(isTracked)
                        .onChange(of: forward.targetPort) { newVal in
                            if !isTracked {
                                forward.localPort = ServiceForward.suggestLocalPort(for: newVal)
                            }
                        }
                        .frame(width: 80)
                }

                Text("←")
                    .foregroundColor(.secondary)
                    .padding(.top, 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("forward.local_port"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SmallIntField(value: $forward.localPort)
                        .disabled(isTracked)
                        .frame(width: 80)
                }

                Spacer()
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(stateColor.opacity(isTracked ? 0.5 : 0.2), lineWidth: 1))
        .opacity(isTracked && tunnelState == .stopped ? 0.6 : 1.0)
    }
}

// MARK: - ServiceForwardDraftCard

struct ServiceForwardDraftCard: View {
    @Binding var forward: ServiceForward
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L10n.text("forward.name.placeholder"), text: $forward.name)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("forward.host_port"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SmallIntField(value: $forward.targetPort)
                        .onChange(of: forward.targetPort) { newVal in
                            forward.localPort = ServiceForward.suggestLocalPort(for: newVal)
                        }
                        .frame(width: 80)
                }

                Text("←")
                    .foregroundColor(.secondary)
                    .padding(.top, 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("forward.local_port"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SmallIntField(value: $forward.localPort)
                        .frame(width: 80)
                }

                Spacer()
            }

            HStack {
                Spacer()
                Button(L10n.text("forward.draft.cancel"), action: onCancel)
                    .buttonStyle(.bordered)
                Button(L10n.text("forward.draft.confirm"), action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
        )
    }
}
