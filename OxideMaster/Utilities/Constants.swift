//
//  Constants.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// App-wide constants
enum Constants {

    // MARK: - App Info

    static let appName = "Oxide Master"
    static let appVersion = "1.0.0"
    static let appIdentifier = "com.rajebdev.OxideMaster"

    // MARK: - Default Paths

    static var defaultScanPath: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    static var cachePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches",
            "\(home)/Library/Application Support",
            "/Library/Caches",
            "/System/Library/Caches",
        ]
    }

    // MARK: - Common Cache Folder Names

    static let commonCacheFolders = [
        "Cache",
        "Caches",
        "CachedData",
        "cached-data",
        "GPUCache",
        "DawnCache",
        "Code Cache",
        "ShaderCache",
        "Shader Cache",
        "Cache Storage",
        "CacheStorage",
        "blob_storage",
        "Service Worker",
    ]

    // MARK: - File Size Constants

    static let kilobyte: Int64 = 1024
    static let megabyte: Int64 = 1024 * 1024
    static let gigabyte: Int64 = 1024 * 1024 * 1024
    static let terabyte: Int64 = 1024 * 1024 * 1024 * 1024

    // MARK: - UI Constants

    enum UI {
        static let cornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let iconSize: CGFloat = 20
        static let largeIconSize: CGFloat = 32
        static let buttonHeight: CGFloat = 32
        static let textFieldHeight: CGFloat = 28
        static let minimumWindowWidth: CGFloat = 1200
        static let minimumWindowHeight: CGFloat = 700
        static let sidebarWidth: CGFloat = 200
        static let toolbarHeight: CGFloat = 44
    }

    // MARK: - Colors

    enum Colors {
        // File type colors
        static let imageColor = Color(hex: "#FF6B6B")
        static let videoColor = Color(hex: "#4ECDC4")
        static let audioColor = Color(hex: "#95E1D3")
        static let documentColor = Color(hex: "#F38181")
        static let codeColor = Color(hex: "#AA96DA")
        static let archiveColor = Color(hex: "#FCBAD3")
        static let executableColor = Color(hex: "#FFFFD2")
        static let folderColor = Color(hex: "#A8D8EA")
        static let otherColor = Color(hex: "#D3D3D3")

        // Status colors
        static let successColor = Color.green
        static let errorColor = Color.red
        static let warningColor = Color.orange
        static let infoColor = Color.blue

        // UI colors
        static let primaryColor = Color.orange
        static let secondaryColor = Color.gray
        static let backgroundColor = Color(NSColor.windowBackgroundColor)
        static let cardBackgroundColor = Color(NSColor.controlBackgroundColor)
    }

    // MARK: - Defaults

    enum Defaults {
        static let defaultBackupAgeDays = 7
        static let defaultCacheAgeHours = 168  // 7 days
        static let defaultCleanupIntervalHours = 24
        static let maxHistoryRecords = 100
        static let maxCleanupRecords = 1000
        static let scanBatchSize = 100
    }

    // MARK: - SF Symbols

    enum Icons {
        static let folder = "folder.fill"
        static let file = "doc"
        static let image = "photo.fill"
        static let video = "video.fill"
        static let audio = "music.note"
        static let document = "doc.fill"
        static let code = "chevron.left.forwardslash.chevron.right"
        static let archive = "archivebox.fill"
        static let executable = "app.fill"

        static let trash = "trash"
        static let copy = "doc.on.doc"
        static let move = "arrow.right.doc.on.clipboard"
        static let rename = "pencil"
        static let reveal = "eye"

        static let disk = "externaldrive.fill"
        static let backup = "clock.arrow.circlepath"
        static let sync = "arrow.triangle.2.circlepath"
        static let cache = "tray.fill"

        static let play = "play.fill"
        static let pause = "pause.fill"
        static let stop = "stop.fill"
        static let refresh = "arrow.clockwise"

        static let settings = "gearshape"
        static let info = "info.circle"
        static let warning = "exclamationmark.triangle"
        static let error = "xmark.circle"
        static let success = "checkmark.circle"

        static let list = "list.bullet"
        static let grid = "square.grid.2x2"
        static let chart = "chart.bar.fill"
    }

    // MARK: - Keyboard Shortcuts

    enum KeyboardShortcuts {
        static let copy = "c"
        static let paste = "v"
        static let delete = "⌫"
        static let selectAll = "a"
        static let refresh = "r"
        static let newFolder = "n"
        static let reveal = "⌘R"
    }

    // MARK: - Notification Names

    enum Notifications {
        static let cacheCleanupComplete = "CacheCleanupComplete"
        static let backupComplete = "BackupComplete"
        static let fileOperationComplete = "FileOperationComplete"
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let backupConfig = "backupConfig"
        static let cacheSettings = "cacheSettings"
        static let syncSessions = "syncSessions"
        static let lastScanPath = "lastScanPath"
        static let viewMode = "viewMode"
        static let sortOrder = "sortOrder"
    }
}
