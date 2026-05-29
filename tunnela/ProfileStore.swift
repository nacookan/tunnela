import Foundation
import Combine

class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    // ピン留め → タイムスタンプ降順、通常 → タイムスタンプ降順
    var sorted: [HistoryEntry] {
        let pinned   = entries.filter(\.isPinned  ).sorted { $0.timestamp > $1.timestamp }
        let unpinned = entries.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        return pinned + unpinned
    }

    private let storageKey = CommandLine.arguments.contains("--demo")
        ? "tunnela.history.v1.demo"
        : "tunnela.history.v1"

    init() { load() }

    // 接続時に呼ぶ。同じ設定がすでにあれば削除してから新規追加（重複排除）
    func recordConnection(_ config: TunnelConfig) {
        let existingName = entries.first { $0.config == config }?.customName
        entries.removeAll { $0.config == config }
        var entry = HistoryEntry(config: config, timestamp: Date())
        entry.customName = existingName
        entries.append(entry)
        persist()
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func togglePin(_ entry: HistoryEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].isPinned.toggle()
        persist()
    }

    func rename(_ entry: HistoryEntry, to name: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].customName = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
