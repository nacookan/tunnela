import SwiftUI

// .sheet(item:) 用の Identifiable ラッパー
struct PasswordPromptConfig: Identifiable {
    let id = UUID()
    let config: TunnelConfig
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var historyStore: HistoryStore
    @EnvironmentObject var sshManager: SSHManager

    @State private var config = TunnelConfig()
    @State private var loadedEntryId: UUID?
    @State private var connectedEntryId: UUID?

    // サイドバー表示状態（カスタムアニメーション制御）
    @State private var sidebarVisible = true
    private let sidebarWidth: CGFloat = 230

    // 名前変更（一元管理）
    @State private var renamingId: UUID? = nil
    @State private var renameText: String = ""

    // ダイアログ
    @State private var showReconnectAlert = false
    @State private var showDeleteActiveAlert = false
    @State private var pendingDeleteEntry: HistoryEntry? = nil

    // パスワード入力シート
    // .sheet(isPresented:) は isPresented と data が別 @State なので
    // 初回レンダリング時にデータが nil のまま sheet が描画される場合がある。
    // .sheet(item:) を使うことで show と data を原子的に管理する。
    @State private var pendingAuth: PasswordPromptConfig?

    /// フォームに表示中のエントリが現在接続中のものかどうか
    private var isViewingActiveConnection: Bool {
        sshManager.isActive && connectedEntryId != nil && connectedEntryId == loadedEntryId
    }

    var body: some View {
        // ─────────────────────────────────────────────────────────────
        // カスタム Overlay サイドバー
        //
        // 閉じる: メイン部分が左にスライドしてサイドバーを覆う（美しい）
        // 開く  : その逆再生 — メイン部分が右に引いてサイドバーが下から現れる
        //
        // ZStack でサイドバーを背面に固定し、メインを前面に置く。
        // メインの .padding(.leading) をアニメーションさせることで
        // NavigationSplitView の「横スライド＋ガタつき」を回避する。
        // ─────────────────────────────────────────────────────────────
        ZStack(alignment: .leading) {
            // 背景層: 履歴サイドバー（常に左端に存在）
            historySidebar
                .frame(width: sidebarWidth)
                .frame(maxHeight: .infinity)

            // 前面層: メインコンテンツ（左パディングでサイドバーを表示/隠す）
            HStack(spacing: 0) {
                Divider()
                    .opacity(sidebarVisible ? 1 : 0)
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .padding(.leading, sidebarVisible ? sidebarWidth : 0)
        }
        .animation(.easeInOut(duration: 0.2), value: sidebarVisible)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { sidebarVisible.toggle() } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(L10n.text("sidebar.toggle"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button { newEntry() } label: {
                    Image(systemName: "plus")
                }
                .help("新規作成")
            }
        }
        // 再接続確認
        .alert(L10n.text("alert.reconnect.title"), isPresented: $showReconnectAlert) {
            Button(L10n.text("common.cancel"), role: .cancel) {}
            Button(L10n.text("alert.reconnect.confirm"), role: .destructive) {
                handleDisconnect()
                initiateConnection(with: config)
            }
        } message: {
            Text(L10n.text("alert.reconnect.message"))
        }
        // 接続中エントリ削除確認
        .alert(L10n.text("alert.delete.title"), isPresented: $showDeleteActiveAlert) {
            Button(L10n.text("common.cancel"), role: .cancel) { pendingDeleteEntry = nil }
            Button(L10n.text("alert.delete.confirm"), role: .destructive) {
                handleDisconnect()
                if let entry = pendingDeleteEntry {
                    historyStore.delete(entry)
                    if loadedEntryId == entry.id { loadedEntryId = nil }
                }
                pendingDeleteEntry = nil
            }
        } message: {
            Text(L10n.text("alert.delete.message"))
        }
        // パスワード/パスフレーズ入力シート（.sheet(item:) で確実に非nil状態で表示）
        .sheet(item: $pendingAuth) { pending in
            PasswordPromptSheet(config: pending.config) { runtimeConfig in
                performConnection(runtimeConfig: runtimeConfig)
            } onCancel: {
                pendingAuth = nil
            }
        }
    }

    // MARK: 履歴サイドバー

    private var historySidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text("sidebar.title"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider()

            if historyStore.sorted.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(L10n.text("sidebar.empty"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(historyStore.sorted) { entry in
                            HistoryRowView(
                                entry: entry,
                                isLoaded: loadedEntryId == entry.id,
                                isCurrentConnection: connectedEntryId == entry.id,
                                isRenaming: renamingId == entry.id,
                                renameText: $renameText,
                                onTap: { handleHistoryTap(entry) },
                                onStartRename: { startRenaming(entry) },
                                onCommitRename: { commitRename(entry) },
                                onCancelRename: { renamingId = nil },
                                onTogglePin: { historyStore.togglePin(entry) },
                                onDelete: { handleDelete(entry) }
                            )
                            .listRowBackground(
                                loadedEntryId == entry.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .id(entry.id)
                        }
                    }
                    .listStyle(.sidebar)
                    // 接続したとき（connectedEntryId が設定されたとき）先頭にスクロール
                    .onChange(of: connectedEntryId) { newId in
                        guard newId != nil, let first = historyStore.sorted.first else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    // MARK: メインコンテンツ

    private var mainContent: some View {
        MainConfigView(
            config: $config,
            isViewingActiveConnection: isViewingActiveConnection,
            onConnect: handleConnect,
            onDisconnect: handleDisconnect
        )
    }

    // MARK: イベントハンドラ

    private func newEntry() {
        commitCurrentRename()
        config = TunnelConfig()
        loadedEntryId = nil
    }

    private func handleHistoryTap(_ entry: HistoryEntry) {
        commitCurrentRename()
        guard loadedEntryId != entry.id else { return }
        config = entry.config
        loadedEntryId = entry.id
    }

    private func handleConnect() {
        commitCurrentRename()
        if sshManager.isActive {
            showReconnectAlert = true
        } else {
            initiateConnection(with: config)
        }
    }

    private func handleDisconnect() {
        sshManager.stopAll()
        connectedEntryId = nil
    }

    private func handleDelete(_ entry: HistoryEntry) {
        if connectedEntryId == entry.id {
            pendingDeleteEntry = entry
            showDeleteActiveAlert = true
        } else {
            historyStore.delete(entry)
            if loadedEntryId == entry.id { loadedEntryId = nil }
        }
    }

    // MARK: 名前変更

    private func startRenaming(_ entry: HistoryEntry) {
        renameText = entry.displayName
        renamingId = entry.id
    }

    private func commitRename(_ entry: HistoryEntry) {
        historyStore.rename(entry, to: renameText)
        renamingId = nil
    }

    private func commitCurrentRename() {
        guard let id = renamingId else { return }
        if let entry = historyStore.entries.first(where: { $0.id == id }) {
            historyStore.rename(entry, to: renameText)
        }
        renamingId = nil
    }

    // MARK: 接続フロー

    private func initiateConnection(with cfg: TunnelConfig) {
        let needsPrompt = cfg.relayPromptSecret || (cfg.mode == .sideB && cfg.hostPromptSecret)
        if needsPrompt {
            pendingAuth = PasswordPromptConfig(config: cfg)
        } else {
            performConnection(runtimeConfig: cfg)
        }
    }

    private func performConnection(runtimeConfig: TunnelConfig) {
        pendingAuth = nil
        sshManager.startAll(for: runtimeConfig)
        historyStore.recordConnection(config)
        connectedEntryId = historyStore.sorted.first { $0.config == config }?.id
        loadedEntryId = connectedEntryId
    }
}
