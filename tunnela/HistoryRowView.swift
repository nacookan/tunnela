import SwiftUI

struct HistoryRowView: View {
    let entry: HistoryEntry
    let isLoaded: Bool
    let isCurrentConnection: Bool
    let isRenaming: Bool
    @Binding var renameText: String
    let onTap: () -> Void
    let onStartRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @FocusState private var renameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.config.mode.iconName)
                .foregroundColor(entry.config.mode == .sideA ? .blue : .orange)
                .font(.system(size: 13))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if entry.isPinned && !isRenaming {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    if isRenaming {
                        TextField("", text: $renameText)
                            .font(.system(size: 13, weight: .medium))
                            .textFieldStyle(.plain)
                            .focused($renameFocused)
                            .onSubmit { onCommitRename() }
                            .onExitCommand { onCancelRename() }
                    } else {
                        Text(entry.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                }

                Text(verbatim: entry.briefInfo)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if isCurrentConnection {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(L10n.text("history.connected"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    Text(entry.config.mode.modeName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        // simultaneousGesture は macOS で確実に動作しないため NSClickGestureRecognizer を使用。
        // シングルクリックは即時発火、ダブルクリックも遅延なし。
        .overlay(
            Group {
                if !isRenaming {
                    DoubleClickHandler(onSingleClick: onTap, onDoubleClick: onStartRename)
                }
            }
        )
        .onChange(of: isRenaming) { renaming in
            if renaming {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocused = true }
            } else {
                renameFocused = false
            }
        }
        .contextMenu {
            Button { onStartRename() } label: {
                Label(L10n.text("history.context.rename"), systemImage: "pencil")
            }
            Button { onTogglePin() } label: {
                Label(
                    entry.isPinned
                        ? L10n.text("history.context.unpin")
                        : L10n.text("history.context.pin"),
                    systemImage: entry.isPinned ? "pin.slash" : "pin"
                )
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label(L10n.text("history.context.delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - DoubleClickHandler
// SwiftUI の TapGesture(count: 2) はシングルクリックに遅延が生じるため、
// NSClickGestureRecognizer を使い遅延ゼロでシングル・ダブルクリックを処理する。

import AppKit

struct DoubleClickHandler: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let single = NSClickGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.singleTap))
        single.numberOfClicksRequired = 1
        let double = NSClickGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.doubleTap))
        double.numberOfClicksRequired = 2
        view.addGestureRecognizer(single)
        view.addGestureRecognizer(double)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.onSingleClick = onSingleClick
        context.coordinator.onDoubleClick = onDoubleClick
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var onSingleClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?
        @objc func singleTap() { DispatchQueue.main.async { self.onSingleClick?() } }
        @objc func doubleTap() { DispatchQueue.main.async { self.onDoubleClick?() } }
    }
}
