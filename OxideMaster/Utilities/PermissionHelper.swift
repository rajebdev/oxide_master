//
//  PermissionHelper.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import AppKit
import Foundation
import UserNotifications

/// Helper for checking permissions and file access
/// Note: App uses NSOpenPanel for folder selection which provides security-scoped access automatically
class PermissionHelper {

    /// Check if app has Full Disk Access (kept for legacy compatibility)
    /// Note: Not required for this app! File picker provides necessary access.
    static func hasFullDiskAccess() -> Bool {
        // Try to access a protected directory
        let protectedPath = "/Library/Application Support/com.apple.TCC"
        let fileManager = FileManager.default

        return fileManager.isReadableFile(atPath: protectedPath)
    }

    /// Request Full Disk Access (kept for legacy compatibility)
    /// Note: Not needed for this app - uses file picker instead
    static func requestFullDiskAccess() {
        let alert = NSAlert()
        alert.messageText = "Note: No Special Permissions Required"
        alert.informativeText =
            "This app uses file picker dialogs. Simply select folders when prompted, and macOS will grant access automatically. No Full Disk Access needed!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Open System Settings to Privacy & Security
    static func openPrivacySettings() {
        if #available(macOS 13.0, *) {
            // macOS Ventura and later
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // macOS Monterey and earlier
            let prefpaneURL = URL(
                fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
            NSWorkspace.shared.open(prefpaneURL)
        }
    }

    /// Check if we have read access to a path
    static func hasReadAccess(to path: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.isReadableFile(atPath: path)
    }

    /// Check if we have write access to a path
    static func hasWriteAccess(to path: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.isWritableFile(atPath: path)
    }

    /// Show permission error alert
    static func showPermissionError(for path: String) {
        let alert = NSAlert()
        alert.messageText = "Permission Denied"
        alert.informativeText =
            "Cannot access \(path). Please use the file picker dialog to select folders, which automatically grants access."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Request notification permission
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }

            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }

    /// Check notification permission status
    static func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus == .authorized)
        }
    }

    /// Show general error alert
    static func showError(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Show confirmation dialog
    static func showConfirmation(
        title: String, message: String, confirmTitle: String = "Confirm",
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: confirmTitle)
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn)
        }
    }
}
