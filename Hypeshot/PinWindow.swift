import AppKit
import SwiftUI

/// Floating always-on-top screenshot (Pro). Each pin is its own borderless
/// panel; drag anywhere to move, double-click or press Escape to dismiss,
/// scroll to resize.
@MainActor
final class PinWindowController {
    private static var pins: [PinPanel] = []

    static func pin(image: CGImage) {
        let panel = PinPanel(image: image) { panel in
            pins.removeAll { $0 === panel }
        }
        pins.append(panel)
        panel.present()
    }
}

final class PinPanel: NSPanel {
    private let onClose: (PinPanel) -> Void

    init(image: CGImage, onClose: @escaping (PinPanel) -> Void) {
        self.onClose = onClose

        // Start at half the pixel size (1x for a retina capture), capped to 45% of the screen.
        var size = CGSize(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
        if let screen = NSScreen.main {
            let cap = min(screen.visibleFrame.width, screen.visibleFrame.height) * 0.45
            let scale = min(1, cap / max(size.width, size.height))
            size = CGSize(width: size.width * scale, height: size.height * scale)
        }

        let origin: CGPoint
        if let screen = NSScreen.main {
            origin = CGPoint(x: screen.visibleFrame.maxX - size.width - 24,
                             y: screen.visibleFrame.maxY - size.height - 24)
        } else {
            origin = CGPoint(x: 100, y: 100)
        }

        super.init(contentRect: CGRect(origin: origin, size: size),
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentAspectRatio = size

        let nsImage = NSImage(cgImage: image, size: size)
        contentView = NSHostingView(rootView: PinView(image: nsImage) { [weak self] in
            self?.dismiss()
        })
    }

    func present() {
        orderFrontRegardless()
    }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    private func dismiss() {
        orderOut(nil)
        onClose(self)
    }
}

private struct PinView: View {
    let image: NSImage
    let onDismiss: () -> Void

    @State private var hovering = false

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.25)))
            .overlay(alignment: .topLeading) {
                if hovering {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .onHover { hovering = $0 }
            .onTapGesture(count: 2) { onDismiss() }
    }
}
