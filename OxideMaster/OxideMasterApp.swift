//
//  OxideMasterApp.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

@main
struct OxideMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: Constants.UI.minimumWindowWidth,
                    minHeight: Constants.UI.minimumWindowHeight)
        }
        .commands {
            // File menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    openNewWindow()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            // View menu commands
            CommandMenu("View") {
                Button("Disk Analyzer") {
                    // Switch to analyzer tab
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Backup Manager") {
                    // Switch to backup tab
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("File Sync") {
                    // Switch to sync tab
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Cache Manager") {
                    // Switch to cache tab
                }
                .keyboardShortcut("4", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func openNewWindow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.contentView = NSHostingView(rootView: ContentView())
        newWindow.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        PermissionHelper.requestNotificationPermission()

        // Request notification permission for cache cleanup alerts
        PermissionHelper.requestNotificationPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
