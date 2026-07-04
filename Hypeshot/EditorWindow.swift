import AppKit
import SwiftUI

@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    static let shared = EditorWindowController()

    private var window: NSWindow?

    func show(screenshot: Screenshot, autoSavedTo savedURL: URL? = nil) {
        let viewModel = EditorViewModel(screenshot: screenshot)
        let view = EditorView(vm: viewModel)
            .environmentObject(ProStore.shared)
        let hosting = NSHostingController(rootView: view)

        let window = self.window ?? makeWindow()
        window.contentViewController = hosting
        sizeToFit(window: window, imageSize: screenshot.pixelSize)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let savedURL {
            viewModel.showToast("Saved to \(savedURL.deletingLastPathComponent().lastPathComponent)")
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero,
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Hypeshot"
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }

    private func sizeToFit(window: NSWindow, imageSize: CGSize) {
        guard let screen = NSScreen.main else { return }
        let chrome = CGSize(width: 260, height: 120) // sidebar + toolbar allowance
        let available = CGSize(width: screen.visibleFrame.width * 0.9 - chrome.width,
                               height: screen.visibleFrame.height * 0.9 - chrome.height)
        // Image points are pixels / 2 on retina; fit within the visible frame.
        let points = CGSize(width: imageSize.width / 2, height: imageSize.height / 2)
        let scale = min(1, available.width / max(points.width, 1), available.height / max(points.height, 1))
        let content = CGSize(width: max(720, points.width * scale + chrome.width),
                             height: max(480, points.height * scale + chrome.height))
        window.setContentSize(content)
        window.center()
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
    }
}

// MARK: - Editor view

struct EditorView: View {
    @ObservedObject var vm: EditorViewModel
    @EnvironmentObject private var pro: ProStore

    var body: some View {
        HSplitView {
            canvasArea
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            BeautifyPanel(vm: vm)
                .frame(width: 230)
        }
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            if let toast = vm.toast {
                Text(toast)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm.toast)
    }

    // MARK: Canvas

    private var canvasArea: some View {
        GeometryReader { proxy in
            let fitted = fittedRect(in: proxy.size)
            ZStack {
                CheckerboardBackground()
                EditorCanvas(vm: vm, fitted: fitted)
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: fitted.midX, y: fitted.midY)
            }
        }
        .padding(12)
    }

    private func fittedRect(in available: CGSize) -> CGRect {
        let size = vm.screenshot.pixelSize
        guard size.width > 0, size.height > 0, available.width > 0, available.height > 0 else { return .zero }
        let scale = min(available.width / size.width, available.height / size.height, 0.5)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: (available.width - fitted.width) / 2,
                      y: (available.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Tool", selection: $vm.tool) {
                ForEach(AnnotationTool.allCases) { tool in
                    Image(systemName: tool.symbol).help(tool.help).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            ColorPicker("Color", selection: $vm.color, supportsOpacity: false)
                .labelsHidden()

            Button {
                vm.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help("Undo (⌘Z)")
            .keyboardShortcut("z", modifiers: .command)
            .disabled(vm.annotations.isEmpty)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if pro.isPro {
                Button {
                    copyText()
                } label: {
                    Image(systemName: "text.viewfinder")
                }
                .help("Copy Text (OCR)")

                Button {
                    pin()
                } label: {
                    Image(systemName: "pin")
                }
                .help("Pin as floating screenshot")
            }

            dragOutThumbnail

            Button {
                copyImage()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy (⌘C)")
            .keyboardShortcut("c", modifiers: .command)

            Button {
                save()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save (⌘S)")
            .keyboardShortcut("s", modifiers: .command)
        }
    }

    private var dragOutThumbnail: some View {
        Image(nsImage: Exporter.nsImage(from: vm.screenshot.image))
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
            .help("Drag me into another app")
            .onDrag {
                guard let image = Renderer.render(vm),
                      let url = Exporter.temporaryDragFile(image, preset: .standard, capturedAt: vm.screenshot.capturedAt),
                      let provider = NSItemProvider(contentsOf: url) else {
                    return NSItemProvider()
                }
                return provider
            }
    }

    // MARK: Actions

    private func copyImage() {
        guard let image = Renderer.render(vm) else { return }
        Exporter.copyToPasteboard(image)
        vm.showToast("Copied")
    }

    private func save() {
        guard let image = Renderer.render(vm) else { return }
        let saved = SaveLocationStore.shared.withAccess { folder -> String in
            let url = Exporter.uniqueURL(in: folder,
                                         preferredName: ExportPreset.standard.filename(for: vm.screenshot.capturedAt))
            try Exporter.write(image, to: url, preset: .standard)
            return folder.lastPathComponent
        }
        if let saved {
            vm.showToast("Saved to \(saved)")
        } else {
            // No default folder configured (or it became inaccessible) — ask.
            Exporter.saveWithPanel(image, preset: .standard, capturedAt: vm.screenshot.capturedAt,
                                   in: NSApp.keyWindow)
        }
    }

    private func copyText() {
        let source = vm.screenshot.image
        Task {
            do {
                let text = try await OCRService.recognizeText(in: source)
                if text.isEmpty {
                    vm.showToast("No text found")
                } else {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    vm.showToast("Text copied")
                }
            } catch {
                vm.showToast("Couldn't read text")
            }
        }
    }

    private func pin() {
        guard let image = Renderer.render(vm) else { return }
        PinWindowController.pin(image: image)
        vm.showToast("Pinned")
    }
}

// MARK: - Drawing canvas

/// Displays the screenshot with live annotations and handles drawing gestures.
/// All annotation coordinates are image pixels; `scale` maps them to view points.
private struct EditorCanvas: View {
    @ObservedObject var vm: EditorViewModel
    let fitted: CGRect

    @FocusState private var textFieldFocused: Bool

    private var scale: CGFloat {
        let size = vm.screenshot.pixelSize
        return size.width > 0 ? fitted.width / size.width : 1
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(decorative: vm.screenshot.image, scale: 1)
                .resizable()
                .interpolation(.high)

            AnnotationOverlay(vm: vm, scale: scale)

            if let pending = vm.pendingText {
                TextField("Text", text: $vm.pendingTextValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: pending.fontSize * scale, weight: .semibold))
                    .foregroundStyle(vm.color)
                    .frame(width: max(120, fitted.width - pending.start.x * scale - 8))
                    .offset(x: pending.start.x * scale, y: pending.start.y * scale)
                    .focused($textFieldFocused)
                    .onSubmit { vm.commitPendingText() }
                    .onAppear { textFieldFocused = true }
            }
        }
        .clipped()
        .gesture(drawGesture)
        .onChange(of: vm.tool) {
            vm.commitPendingText()
        }
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = imagePoint(value.startLocation)
                let current = imagePoint(value.location)
                if vm.tool == .text { return }
                if vm.draft == nil {
                    vm.commitPendingText()
                    vm.draft = Annotation(tool: vm.tool, start: start, end: current,
                                          color: vm.color, lineWidth: vm.lineWidth)
                } else {
                    vm.draft?.end = current
                }
            }
            .onEnded { value in
                if vm.tool == .text {
                    vm.commitPendingText()
                    vm.pendingText = Annotation(tool: .text, start: imagePoint(value.location),
                                                end: imagePoint(value.location),
                                                color: vm.color, lineWidth: vm.lineWidth)
                    return
                }
                defer { vm.draft = nil }
                guard var draft = vm.draft else { return }
                draft.end = imagePoint(value.location)
                let minSize = draft.tool == .arrow ? 6.0 : 4.0
                if draft.rect.width > minSize || draft.rect.height > minSize {
                    vm.annotations.append(draft)
                }
            }
    }

    private func imagePoint(_ viewPoint: CGPoint) -> CGPoint {
        let size = vm.screenshot.pixelSize
        return CGPoint(x: min(max(viewPoint.x / scale, 0), size.width),
                       y: min(max(viewPoint.y / scale, 0), size.height))
    }
}

/// Draws committed annotations plus the in-flight draft, scaled to view points.
private struct AnnotationOverlay: View {
    @ObservedObject var vm: EditorViewModel
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            for annotation in vm.annotations + (vm.draft.map { [$0] } ?? []) {
                draw(annotation, in: &context, canvasSize: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ annotation: Annotation, in context: inout GraphicsContext, canvasSize: CGSize) {
        let rect = CGRect(x: annotation.rect.minX * scale, y: annotation.rect.minY * scale,
                          width: annotation.rect.width * scale, height: annotation.rect.height * scale)
        let lineWidth = max(annotation.lineWidth * scale, 1)

        switch annotation.tool {
        case .arrow:
            drawArrow(annotation, in: &context, lineWidth: lineWidth)
        case .rect:
            context.stroke(Path(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)),
                           with: .color(annotation.color), lineWidth: lineWidth)
        case .ellipse:
            context.stroke(Path(ellipseIn: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)),
                           with: .color(annotation.color), lineWidth: lineWidth)
        case .highlight:
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.45)))
        case .blur:
            if let pixellated = vm.pixellated {
                var clipped = context
                clipped.clip(to: Path(rect))
                clipped.draw(Image(decorative: pixellated, scale: 1),
                             in: CGRect(origin: .zero, size: canvasSize))
            }
        case .text:
            let position = CGPoint(x: annotation.start.x * scale, y: annotation.start.y * scale)
            context.draw(
                Text(annotation.text)
                    .font(.system(size: annotation.fontSize * scale, weight: .semibold))
                    .foregroundStyle(annotation.color),
                at: position, anchor: .topLeading
            )
        }
    }

    private func drawArrow(_ annotation: Annotation, in context: inout GraphicsContext, lineWidth: CGFloat) {
        let from = CGPoint(x: annotation.start.x * scale, y: annotation.start.y * scale)
        let to = CGPoint(x: annotation.end.x * scale, y: annotation.end.y * scale)
        let dx = to.x - from.x, dy = to.y - from.y
        guard sqrt(dx * dx + dy * dy) > 2 else { return }
        let angle = atan2(dy, dx)
        let headLength = max(lineWidth * 3.5, 9)
        let headAngle: CGFloat = .pi / 7

        var line = Path()
        line.move(to: from)
        line.addLine(to: CGPoint(x: to.x - cos(angle) * headLength * 0.6,
                                 y: to.y - sin(angle) * headLength * 0.6))
        context.stroke(line, with: .color(annotation.color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

        var head = Path()
        head.move(to: to)
        head.addLine(to: CGPoint(x: to.x - cos(angle - headAngle) * headLength,
                                 y: to.y - sin(angle - headAngle) * headLength))
        head.addLine(to: CGPoint(x: to.x - cos(angle + headAngle) * headLength,
                                 y: to.y - sin(angle + headAngle) * headLength))
        head.closeSubpath()
        context.fill(head, with: .color(annotation.color))
    }
}

// MARK: - Beautify panel (Pro)

private struct BeautifyPanel: View {
    @ObservedObject var vm: EditorViewModel
    @EnvironmentObject private var pro: ProStore

    var body: some View {
        Form {
            Section {
                Toggle("Beautify", isOn: beautifyBinding)
                    .toggleStyle(.switch)
            } footer: {
                if !pro.isPro {
                    Label("Pro feature", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if vm.beautify.enabled {
                Section("Background") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                        ForEach(BeautifyBackground.presets) { preset in
                            Circle()
                                .fill(LinearGradient(colors: preset.colors,
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if vm.beautify.background == preset {
                                        Circle().strokeBorder(.white, lineWidth: 2)
                                            .shadow(radius: 1)
                                    }
                                }
                                .onTapGesture { vm.beautify.background = preset }
                        }
                    }
                }

                Section {
                    LabeledContent("Padding") {
                        Slider(value: $vm.beautify.padding, in: 16...160)
                    }
                    LabeledContent("Corners") {
                        Slider(value: $vm.beautify.cornerRadius, in: 0...40)
                    }
                    Toggle("Shadow", isOn: $vm.beautify.shadow)
                }
            }

            Section("Line width") {
                Slider(value: $vm.lineWidth, in: 2...16)
            }
        }
        .formStyle(.grouped)
    }

    private var beautifyBinding: Binding<Bool> {
        Binding {
            vm.beautify.enabled
        } set: { newValue in
            if newValue && !pro.isPro {
                PaywallWindowController.shared.show()
            } else {
                vm.beautify.enabled = newValue
            }
        }
    }
}

// MARK: - Checkerboard

private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 12
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(nsColor: .underPageBackgroundColor)))
            for row in 0...Int(size.height / cell) {
                for col in 0...Int(size.width / cell) where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(.primary.opacity(0.03)))
                }
            }
        }
    }
}
