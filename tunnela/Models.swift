import Foundation

// MARK: - Enums

enum SideMode: String, Codable, CaseIterable, Identifiable {
    case sideA = "sideA"
    case sideB = "sideB"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sideA: return L10n.text("mode.host.display")
        case .sideB: return L10n.text("mode.client.display")
        }
    }
    var shortName: String {
        switch self {
        case .sideA: return L10n.text("mode.host.short")
        case .sideB: return L10n.text("mode.client.short")
        }
    }
    // 履歴・バナーなど「モード」付きの表示名（ホストモード / クライアントモード）
    var modeName: String {
        switch self {
        case .sideA: return L10n.text("mode.host.mode_name")
        case .sideB: return L10n.text("mode.client.mode_name")
        }
    }
    var iconName: String { self == .sideA ? "arrow.down.to.line" : "arrow.up.to.line" }
}

enum AuthType: String, Codable, CaseIterable, Identifiable {
    case key      = "SSH鍵"    // rawValue はストレージキーとして固定（変更不可）
    case password = "パスワード"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .key:      return L10n.text("auth.ssh_key")
        case .password: return L10n.text("auth.password")
        }
    }
}

enum TunnelState: Equatable {
    case stopped
    case connecting
    case running
    case failed(String)

    var label: String {
        switch self {
        case .stopped:          return L10n.text("state.stopped")
        case .connecting:       return L10n.text("state.connecting")
        case .running:          return L10n.text("state.running")
        case .failed(let msg):  return L10n.format("state.failed", msg)
        }
    }
    var symbolName: String {
        switch self {
        case .stopped:    return "circle"
        case .connecting: return "arrow.clockwise.circle"
        case .running:    return "circle.fill"
        case .failed:     return "exclamationmark.circle.fill"
        }
    }
    var isRunning: Bool { if case .running = self { return true }; return false }
}

// MARK: - ServiceForward
// Equatable は id を無視して内容だけ比較（履歴の重複排除に使用）

struct ServiceForward: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var targetPort: Int = 0
    var localPort: Int = 0

    static func suggestLocalPort(for target: Int) -> Int {
        if let c = Int("5\(target)"), c >= 1025, c <= 65535 { return c }
        return min(65535, max(1025, 50000 + (target % 10000)))
    }
}

extension ServiceForward: Equatable {
    static func == (lhs: ServiceForward, rhs: ServiceForward) -> Bool {
        lhs.name == rhs.name && lhs.targetPort == rhs.targetPort && lhs.localPort == rhs.localPort
    }
}

// MARK: - TunnelConfig

struct TunnelConfig: Codable, Equatable {
    var mode: SideMode = .sideA

    var relayHost: String = ""
    var relayPort: Int = 22
    var relayUsername: String = ""
    var relayAuthType: AuthType = .key
    var relayPassword: String = ""
    var relayKeyPath: String = "~/.ssh/id_rsa"
    var relayKeyPassphrase: String = ""
    var relayPromptSecret: Bool = false
    var relayInternalPort: Int = 22222
    var hostSSHPort: Int = 22

    // クライアント側のみ
    var hostUsername: String = ""
    var hostAuthType: AuthType = .key
    var hostPassword: String = ""
    var hostKeyPath: String = "~/.ssh/id_rsa"
    var hostKeyPassphrase: String = ""
    var hostPromptSecret: Bool = false
    var localPort: Int = 22222
    var serviceForwards: [ServiceForward] = []

    var socks5Enabled: Bool = false
    var socks5Port: Int = 1080
}

// MARK: - HistoryEntry

struct HistoryEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var config: TunnelConfig
    var timestamp: Date = Date()
    var isPinned: Bool = false
    var customName: String? = nil

    var displayName: String {
        if let name = customName, !name.isEmpty { return name }
        return timestampDisplay
    }

    var timestampDisplay: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "yyyy/M/d HH:mm"
        return fmt.string(from: timestamp)
    }

    var briefInfo: String {
        guard !config.relayHost.isEmpty else { return "未設定" }
        let user = config.relayUsername.isEmpty ? "" : "\(config.relayUsername)@"
        return "\(user)\(config.relayHost):\(config.relayInternalPort)"
    }
}
