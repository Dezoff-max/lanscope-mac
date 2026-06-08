import AppKit
import SwiftUI

@main
struct LanScopeMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    init() {
        WindowStateMigrator.resetLegacyWindowLayoutIfNeeded()
    }

    var body: some Scene {
        WindowGroup("LanScope Mac") {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.config.theme.colorScheme)
                .frame(minWidth: 1120, idealWidth: 1180, minHeight: 700, idealHeight: 760)
                .background(
                    AppWindowConfigurator(
                        defaultSize: CGSize(width: 1180, height: 760),
                        minimumSize: CGSize(width: 1120, height: 700)
                    )
                )
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LanScope Mac") {
                    AboutWindowController.shared.show()
                }
            }

            CommandMenu("Scanner") {
                Button("Scan") {
                    appState.startScan()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appState.isScanning)

                Button("Stop") {
                    appState.stopScan()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!appState.isScanning)

                Divider()

                Button("Copy Selected Rows") {
                    appState.copySelectedRows()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(appState.exportableSelection.isEmpty)
            }
        }

        Settings {
            SettingsView(config: $appState.config)
                .environmentObject(appState)
                .frame(width: 520)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowStateMigrator.resetLegacyWindowLayoutIfNeeded()
        NSApp.setActivationPolicy(.regular)
        bringMainWindowForward()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.bringMainWindowForward()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.sendAction(#selector(NSApplication.newWindowForTab(_:)), to: nil, from: nil)
        }
        bringMainWindowForward()
        return true
    }

    private func bringMainWindowForward() {
        if NSApp.windows.filter(\.isVisible).isEmpty {
            NSApp.sendAction(#selector(NSApplication.newWindowForTab(_:)), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum WindowStateMigrator {
    static func resetLegacyWindowLayoutIfNeeded() {
        let migrationKey = "LanScopeMac.windowLayoutMigration.20260605.compactTable"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else {
            return
        }

        for key in defaults.dictionaryRepresentation().keys {
            if key.contains("NSWindow Frame") || key.contains("NSSplitView Subview Frames") {
                defaults.removeObject(forKey: key)
            }
        }

        if let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let savedStateURL = libraryURL.appendingPathComponent(
                "Saved Application State/com.lanscope.mac.savedState",
                isDirectory: true
            )
            try? FileManager.default.removeItem(at: savedStateURL)
        }

        defaults.set(true, forKey: migrationKey)
    }
}
