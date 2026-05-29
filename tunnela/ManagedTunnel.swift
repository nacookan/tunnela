import Foundation
import Combine

class ManagedTunnel: ObservableObject, Identifiable {
    let id = UUID()
    let displayName: String
    let commandLine: String
    let serviceForwardId: UUID?
    let isSocks5: Bool

    @Published private(set) var state: TunnelState = .stopped
    @Published private(set) var lastError: String = ""

    private let args: [String]
    private let envOverrides: [String: String]
    private var process: Process?
    private var shouldReconnect = false
    private var reconnectWork: DispatchWorkItem?
    private var stderrPipe: Pipe?

    init(name: String, args: [String], env: [String: String] = [:],
         serviceForwardId: UUID? = nil, isSocks5: Bool = false) {
        self.displayName = name
        self.args = args
        self.envOverrides = env
        self.serviceForwardId = serviceForwardId
        self.isSocks5 = isSocks5
        self.commandLine = (["ssh"] + args).joined(separator: " ")
    }

    func start(reconnect: Bool = false) {
        shouldReconnect = reconnect
        launch()
    }

    func stop() {
        shouldReconnect = false
        reconnectWork?.cancel()
        reconnectWork = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe = nil
        process?.terminate()
        process = nil
        state = .stopped
    }

    func restart() {
        process?.terminate()
        process = nil
        launch()
    }

    private func launch() {
        lastError = ""

        if CommandLine.arguments.contains("--demo") {
            state = .running
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = args

        var env = ProcessInfo.processInfo.environment
        envOverrides.forEach { env[$0] = $1 }
        proc.environment = env
        proc.standardOutput = FileHandle.nullDevice

        let pipe = Pipe()
        proc.standardError = pipe
        stderrPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            if let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { self?.lastError += str }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                guard let self else { return }
                self.stderrPipe = nil
                self.process = nil
                if self.shouldReconnect {
                    self.state = .connecting
                    let work = DispatchWorkItem { [weak self] in self?.launch() }
                    self.reconnectWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
                } else {
                    self.state = .stopped
                }
            }
        }

        do {
            try proc.run()
            process = proc
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
