import AppKit
import SwiftUI

struct AppWindowConfigurator: NSViewRepresentable {
    let defaultSize: CGSize
    let minimumSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window, !WindowConfigurationStore.shared.configuredWindows.contains(window) else {
            return
        }

        WindowConfigurationStore.shared.configuredWindows.add(window)
        window.minSize = minimumSize
        window.title = "LanScope Mac"

        let frame = window.frame
        let isTooSmall = frame.width < minimumSize.width || frame.height < minimumSize.height
        let isTooWideFromPreviousLayout = frame.width > defaultSize.width + 80 || frame.height > defaultSize.height + 80
        guard isTooSmall || isTooWideFromPreviousLayout else {
            return
        }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        let targetWidth = min(defaultSize.width, visibleFrame.width)
        let targetHeight = min(defaultSize.height, visibleFrame.height)
        let targetOrigin = NSPoint(
            x: visibleFrame.midX - targetWidth / 2,
            y: visibleFrame.midY - targetHeight / 2
        )
        window.setFrame(
            NSRect(origin: targetOrigin, size: CGSize(width: targetWidth, height: targetHeight)),
            display: true,
            animate: false
        )
    }
}

private final class WindowConfigurationStore {
    static let shared = WindowConfigurationStore()
    let configuredWindows = NSHashTable<NSWindow>.weakObjects()
}
