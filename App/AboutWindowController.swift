import AppKit
import SwiftUI

@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: AboutView())
            let createdWindow = NSWindow(contentViewController: hostingController)
            createdWindow.title = "About LanScope Mac"
            createdWindow.styleMask = [.titled, .closable, .fullSizeContentView]
            createdWindow.titlebarAppearsTransparent = true
            createdWindow.isMovableByWindowBackground = true
            createdWindow.isReleasedWhenClosed = false
            createdWindow.setContentSize(NSSize(width: 520, height: 470))
            createdWindow.minSize = NSSize(width: 520, height: 470)
            createdWindow.maxSize = NSSize(width: 520, height: 470)
            createdWindow.center()
            window = createdWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 82, height: 82)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)

                VStack(spacing: 5) {
                    Text("LanScope Mac")
                        .font(.system(size: 26, weight: .bold))

                    Text("Version \(version) (\(build))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text("A native macOS LAN scanner for authorized local network administration.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
            }
            .padding(.top, 38)
            .padding(.bottom, 24)

            VStack(spacing: 0) {
                aboutRow("Developer", value: "@rootoff")
                Divider()
                aboutRow("Copyright", value: "Copyright © 2026 @rootoff")
                Divider()
                aboutRow("Rights", value: "All rights reserved")
                Divider()
                aboutRow("License", value: "MIT License")
            }
            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 42)

            HStack(spacing: 10) {
                aboutLink("GitHub", url: "https://github.com/Dezoff-max/lanscope-mac", systemImage: "chevron.left.forwardslash.chevron.right")
                aboutLink("Privacy", url: "https://github.com/Dezoff-max/lanscope-mac/blob/main/PRIVACY.md", systemImage: "hand.raised")
                aboutLink("License", url: "https://github.com/Dezoff-max/lanscope-mac/blob/main/LICENSE", systemImage: "doc.text")
            }
            .padding(.top, 18)

            Spacer(minLength: 14)

            Text("Use only on networks you own or are authorized to administer.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
        .frame(width: 520, height: 470)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func aboutRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private func aboutLink(_ title: String, url: String, systemImage: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: systemImage)
                .frame(minWidth: 96)
        }
        .buttonStyle(.bordered)
    }
}
