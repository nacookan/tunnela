import Foundation
import Combine

// MARK: - SSHManager

class SSHManager: ObservableObject {
    @Published private(set) var tunnels: [ManagedTunnel] = []
    @Published private(set) var activeConfig: TunnelConfig?

    private var askpassPaths: [String] = []
    // ManagedTunnelのstate変化をSSHManagerのobjectWillChangeに転送する
    private var tunnelCancellables = Set<AnyCancellable>()

    var isActive: Bool { activeConfig != nil }
    var runningCount: Int { tunnels.filter { $0.state.isRunning }.count }

    // MARK: 全トンネル起動

    func startAll(for config: TunnelConfig) {
        stopAll()
        activeConfig = config

        switch config.mode {
        case .sideA:
            let t = makeTunnel(
                L10n.format("tunnel.relay.label", config.relayHost),
                args: relayArgs(config),
                env: authEnv(authType: config.relayAuthType,
                             password: config.relayPassword,
                             keyPassphrase: config.relayKeyPassphrase)
            )
            tunnels = [t]
            subscribeAll()
            t.start(reconnect: true)

        case .sideB:
            var all: [ManagedTunnel] = []
            let relay = makeTunnel(
                L10n.format("tunnel.relay.label", config.relayHost),
                args: relayArgs(config),
                env: authEnv(authType: config.relayAuthType,
                             password: config.relayPassword,
                             keyPassphrase: config.relayKeyPassphrase)
            )
            all.append(relay)

            for fwd in config.serviceForwards {
                all.append(makeServiceTunnel(fwd, config: config))
            }
            if config.socks5Enabled {
                all.append(makeSocks5Tunnel(port: config.socks5Port, config: config))
            }

            tunnels = all
            subscribeAll()
            relay.start(reconnect: false)

            let deferred = Array(all.dropFirst())
            if !deferred.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    deferred.forEach { $0.start(reconnect: false) }
                }
            }
        }
    }

    // MARK: サービスポートのホット追加/削除

    func addServiceTunnel(_ forward: ServiceForward, config: TunnelConfig) {
        guard isActive, config.mode == .sideB else { return }
        guard !tunnels.contains(where: { $0.serviceForwardId == forward.id }) else { return }
        let t = makeServiceTunnel(forward, config: config)
        tunnels.append(t)
        subscribeOne(t)
        t.start(reconnect: false)
    }

    func removeServiceTunnel(forwardId: UUID) {
        guard let idx = tunnels.firstIndex(where: { $0.serviceForwardId == forwardId }) else { return }
        tunnels[idx].stop()
        tunnels.remove(at: idx)
    }

    func tunnelState(for forwardId: UUID) -> TunnelState? {
        tunnels.first { $0.serviceForwardId == forwardId }?.state
    }

    // MARK: SOCKS5 ホット追加/削除

    var isSocks5Running: Bool {
        tunnels.contains { $0.isSocks5 }
    }

    var socks5TunnelState: TunnelState? {
        tunnels.first { $0.isSocks5 }?.state
    }

    func startSocks5Tunnel(port: Int, config: TunnelConfig) {
        guard !isSocks5Running else { return }
        let t = makeSocks5Tunnel(port: port, config: config)
        tunnels.append(t)
        subscribeOne(t)
        t.start(reconnect: false)
    }

    func stopSocks5Tunnel() {
        guard let idx = tunnels.firstIndex(where: { $0.isSocks5 }) else { return }
        tunnels[idx].stop()
        tunnels.remove(at: idx)
    }

    // MARK: 全停止

    func stopAll() {
        tunnelCancellables.removeAll()
        tunnels.forEach { $0.stop() }
        tunnels = []
        activeConfig = nil
        cleanupAskpass()
    }

    // MARK: 状態変化の転送

    // 各ManagedTunnelのobjectWillChangeを購読し、state変化をSSHManagerに伝播させる。
    // これがないと、tunnelのstateが変わってもSSHManagerを監視しているビューが更新されない。
    private func subscribeAll() {
        tunnelCancellables.removeAll()
        tunnels.forEach { subscribeOne($0) }
    }

    private func subscribeOne(_ tunnel: ManagedTunnel) {
        tunnel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &tunnelCancellables)
    }

    // MARK: プライベートヘルパー

    private func makeTunnel(_ name: String, args: [String], env: [String: String]) -> ManagedTunnel {
        ManagedTunnel(name: name, args: args, env: env)
    }

    private func makeServiceTunnel(_ fwd: ServiceForward, config: TunnelConfig) -> ManagedTunnel {
        let label = fwd.name.isEmpty ? L10n.text("tunnel.forward.default_name") : fwd.name
        return ManagedTunnel(
            name: L10n.format("tunnel.forward.label", label, fwd.targetPort, fwd.localPort),
            args: serviceArgs(fwd, config: config),
            env: authEnv(authType: config.hostAuthType,
                         password: config.hostPassword,
                         keyPassphrase: config.hostKeyPassphrase),
            serviceForwardId: fwd.id
        )
    }

    private func makeSocks5Tunnel(port: Int, config c: TunnelConfig) -> ManagedTunnel {
        ManagedTunnel(
            name: L10n.format("tunnel.socks5.label", port),
            args: socks5Args(port: port, config: c),
            env: authEnv(authType: c.hostAuthType, password: c.hostPassword, keyPassphrase: c.hostKeyPassphrase),
            isSocks5: true
        )
    }

    private func relayArgs(_ c: TunnelConfig) -> [String] {
        var a: [String] = []
        if c.relayAuthType == .key { a += ["-i", expand(c.relayKeyPath)] }
        a += commonOptions()
        a += ["-N"]
        switch c.mode {
        case .sideA: a += ["-R", "\(c.relayInternalPort):localhost:\(c.hostSSHPort)"]
        case .sideB: a += ["-L", "\(c.localPort):localhost:\(c.relayInternalPort)"]
        }
        if c.relayPort != 22 { a += ["-p", "\(c.relayPort)"] }
        a.append("\(c.relayUsername)@\(c.relayHost)")
        return a
    }

    private func serviceArgs(_ fwd: ServiceForward, config c: TunnelConfig) -> [String] {
        var a: [String] = []
        if c.hostAuthType == .key { a += ["-i", expand(c.hostKeyPath)] }
        a += commonOptions()
        a += ["-p", "\(c.localPort)",
              "-L", "\(fwd.localPort):localhost:\(fwd.targetPort)",
              "-N",
              "\(c.hostUsername)@localhost"]
        return a
    }

    private func socks5Args(port: Int, config c: TunnelConfig) -> [String] {
        // ssh -N -D [port] [user]@localhost -p [localPort]
        var a: [String] = []
        if c.hostAuthType == .key { a += ["-i", expand(c.hostKeyPath)] }
        a += commonOptions()
        a += ["-D", "\(port)",
              "-N",
              "-p", "\(c.localPort)",
              "\(c.hostUsername)@localhost"]
        return a
    }

    private func commonOptions() -> [String] {
        ["-o", "ServerAliveInterval=60",
         "-o", "ServerAliveCountMax=3",
         "-o", "StrictHostKeyChecking=no",
         "-o", "ExitOnForwardFailure=yes",
         // macOS Keychain 統合 — 一度使った鍵をエージェントに登録して再接続でも使えるようにする
         "-o", "UseKeychain=yes",
         "-o", "AddKeysToAgent=yes"]
    }

    // MARK: SSH_ASKPASS（パスワード認証・鍵パスフレーズ共通）
    //
    // SSH はサブプロセスとして起動されるため TTY がない。
    // SSH_ASKPASS + SSH_ASKPASS_REQUIRE=force を使うと
    // SSH はパスワード/パスフレーズを対話入力ではなくスクリプト経由で取得する。
    // DISPLAY=:0 は古い macOS SSH が SSH_ASKPASS を使う条件として必要な場合がある。

    private func authEnv(authType: AuthType, password: String, keyPassphrase: String) -> [String: String] {
        let secret: String
        switch authType {
        case .password: secret = password
        case .key:      secret = keyPassphrase
        }
        guard !secret.isEmpty else { return [:] }
        guard let path = makeAskpass(secret: secret) else { return [:] }
        askpassPaths.append(path)
        return [
            "SSH_ASKPASS":         path,
            "SSH_ASKPASS_REQUIRE": "force",
            "DISPLAY":             ":0"   // 古い macOS 互換フォールバック
        ]
    }

    private func makeAskpass(secret: String) -> String? {
        let path = NSTemporaryDirectory() + "tunnela_\(UUID().uuidString).sh"
        // シングルクォートをエスケープしてシェルインジェクションを防ぐ
        let escaped = secret.replacingOccurrences(of: "'", with: "'\\''")
        let script = "#!/bin/sh\nprintf '%s' '\(escaped)'\n"
        do {
            try script.write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
            return path
        } catch { return nil }
    }

    private func cleanupAskpass() {
        askpassPaths.forEach { try? FileManager.default.removeItem(atPath: $0) }
        askpassPaths = []
    }

    private func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    deinit { cleanupAskpass() }
}
