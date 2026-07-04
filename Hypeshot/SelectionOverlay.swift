import AppKit
import SwiftUI
import ScreenCaptureKit

enum SelectionMode {
    case area
    case window([SCWindow])
}

enum SelectionResult {
    case cancelled
    /// Rect in the display's top-left-origin point space.
    case area(CGRect)
    case window(SCWindow)
}

/// Full-screen borderless panel used for area selection and window picking.
final class SelectionPanel: NSPanel {
    private let onFinish: (SelectionResult) -> Void

    init(screen: NSScreen, mode: SelectionMode, onFinish: @escaping (SelectionResult) -> Void) {
        self.onFinish = onFinish
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false

        let view: AnyView
        switch mode {
        case .area:
            view = AnyView(AreaSelectionView(screenHeight: screen.frame.height) { [weak self] rect in
                self?.finish(rect.map { .area($0) } ?? .cancelled)
            })
        case .window(let windows):
            let pickables = windows.map { PickableWindow(scWindow: $0, viewFrame: Self.viewFrame(of: $0, on: screen)) }
            view = AnyView(WindowPickView(windows: pickables) { [weak self] picked in
                self?.finish(picked.map { .window($0.scWindow) } ?? .cancelled)
            })
        }
        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { true }

    func present() {
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }

    private func finish(_ result: SelectionResult) {
        NSCursor.arrow.set()
        onFinish(result)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            finish(.cancelled)
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        finish(.cancelled)
    }

    /// Converts an SCWindow's global CG frame (top-left origin) into this
    /// overlay view's local top-left-origin coordinates on `screen`.
    private static func viewFrame(of window: SCWindow, on screen: NSScreen) -> CGRect {
        let cg = window.frame
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height ?? 0
        // CG global (y down from top of primary) -> Cocoa global (y up from bottom of primary)
        let cocoaBottom = primaryHeight - cg.maxY
        let globalCocoa = CGRect(x: cg.minX, y: cocoaBottom, width: cg.width, height: cg.height)
        // Cocoa global -> view local, top-left origin
        return CGRect(x: globalCocoa.minX - screen.frame.minX,
                      y: screen.frame.maxY - globalCocoa.maxY,
                      width: cg.width,
                      height: cg.height)
    }
}

// MARK: - Area selection

private struct AreaSelectionView: View {
    let screenHeight: CGFloat
    let onDone: (CGRect?) -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    private var selection: CGRect? {
        guard let a = dragStart, let b = dragCurrent else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Canvas { context, size in
                    var dimmed = Path(CGRect(origin: .zero, size: size))
                    if let sel = selection {
                        dimmed.addPath(Path(sel))
                        context.fill(dimmed, with: .color(.black.opacity(0.35)), style: FillStyle(eoFill: true))
                        context.stroke(Path(sel), with: .color(.white), lineWidth: 1)
                        let label = "\(Int(sel.width)) × \(Int(sel.height))"
                        context.draw(
                            Text(label).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.white),
                            at: CGPoint(x: sel.midX, y: max(sel.minY - 14, 10))
                        )
                    } else {
                        context.fill(dimmed, with: .color(.black.opacity(0.35)))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                        dragCurrent = value.location
                    }
                    .onEnded { _ in
                        if let sel = selection, sel.width > 4, sel.height > 4 {
                            onDone(sel) // already top-left origin, screen-local points
                        } else {
                            onDone(nil)
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Window picking

struct PickableWindow: Identifiable {
    let id = UUID()
    let scWindow: SCWindow
    let viewFrame: CGRect
}

private struct WindowPickView: View {
    let windows: [PickableWindow]
    let onDone: (PickableWindow?) -> Void

    @State private var hovered: PickableWindow?

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            if let hovered {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    )
                    .frame(width: hovered.viewFrame.width, height: hovered.viewFrame.height)
                    .position(x: hovered.viewFrame.midX, y: hovered.viewFrame.midY)
            }
            Text(hovered?.scWindow.title?.isEmpty == false ? hovered!.scWindow.title! : "Click a window to capture")
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 40)
        }
        .contentShape(Rectangle())
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point):
                hovered = windows.first { $0.viewFrame.contains(point) }
            case .ended:
                hovered = nil
            }
        }
        .onTapGesture {
            onDone(hovered)
        }
        .ignoresSafeArea()
    }
}
