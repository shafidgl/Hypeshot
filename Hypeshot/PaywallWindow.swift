import AppKit
import SwiftUI

@MainActor
final class PaywallWindowController {
    static let shared = PaywallWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = PaywallView()
            .environmentObject(ProStore.shared)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Unlock Hypeshot Pro"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

struct PaywallView: View {
    @EnvironmentObject private var pro: ProStore

    private static let features: [(symbol: String, title: String, detail: String)] = [
        ("sparkles.rectangle.stack", "Beautify", "Gradient backgrounds, padding, rounded corners and shadow"),
        ("pin", "Pinned screenshots", "Float any capture above your windows for reference"),
        ("clock.arrow.circlepath", "Capture history", "Every screenshot kept, searchable, one click away"),
        ("text.viewfinder", "Copy text (OCR)", "Grab text out of any screenshot instantly"),
        ("square.and.arrow.up.on.square", "Export presets", "Your formats, scales and filenames, remembered"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: BeautifyBackground.presets[0].colors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Hypeshot Pro")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("One purchase. Yours forever.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.features, id: \.title) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.tint)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title).fontWeight(.semibold)
                            Text(feature.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                if pro.isPro {
                    Label("Pro unlocked — thank you!", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.vertical, 8)
                } else {
                    Button {
                        Task { await pro.purchase() }
                    } label: {
                        Text(purchaseTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pro.purchaseInProgress)

                    if ProStore.isDirectDownload {
                        Text("Pro is sold through the Mac App Store. The App Store version replaces this download.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Button("Restore Purchase") {
                            Task { await pro.restore() }
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                    }
                }

                if let error = pro.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 380)
        .background(.regularMaterial)
    }

    private var purchaseTitle: String {
        if ProStore.isDirectDownload { return "Get Pro on the Mac App Store" }
        if pro.purchaseInProgress { return "Purchasing…" }
        if let product = pro.product { return "Unlock Pro — \(product.displayPrice)" }
        return "Unlock Pro — $7.99"
    }
}
