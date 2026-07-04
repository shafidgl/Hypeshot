import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = HistoryView()
            .environmentObject(HistoryStore.shared)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Capture History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView("No captures yet",
                                       systemImage: "camera.viewfinder",
                                       description: Text("Screenshots you take will show up here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(history.entries) { entry in
                            HistoryCell(entry: entry)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Clear All") { history.clear() }
                    .disabled(history.entries.isEmpty)
            }
        }
    }
}

private struct HistoryCell: View {
    @EnvironmentObject private var history: HistoryStore
    let entry: HistoryStore.Entry

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(height: 120)
            .onDrag { NSItemProvider(contentsOf: entry.url) ?? NSItemProvider() }

            Text(entry.capturedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Edit") { openInEditor() }
            Button("Copy") { copy() }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            }
            Divider()
            Button("Delete", role: .destructive) { history.delete(entry) }
        }
        .onTapGesture(count: 2) { openInEditor() }
        .task {
            thumbnail = entry.loadImage()
        }
    }

    private func openInEditor() {
        guard let image = entry.loadImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        EditorWindowController.shared.show(screenshot: Screenshot(image: cgImage, capturedAt: entry.capturedAt))
    }

    private func copy() {
        guard let image = entry.loadImage() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}
