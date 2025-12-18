//
//  CacheCleanerService.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import UserNotifications

/// Service for cache cleanup operations
class CacheCleanerService {
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard

    private let settingsKey = "cacheSettings"
    private let historyKey = "cleanupHistory"

    /// Load cache settings
    func loadSettings() -> CacheSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
            let settings = try? JSONDecoder().decode(CacheSettings.self, from: data)
        else {
            return CacheSettings()
        }
        return settings
    }

    /// Save cache settings
    func saveSettings(_ settings: CacheSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    /// Load cleanup history
    func loadHistory() -> [CleanupRecord] {
        guard let data = userDefaults.data(forKey: historyKey),
            let history = try? JSONDecoder().decode([CleanupRecord].self, from: data)
        else {
            return []
        }
        return history
    }

    /// Save cleanup history
    private func saveHistory(_ history: [CleanupRecord]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }

    /// Run cache cleanup
    func runCleanup(
        settings: CacheSettings,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> CleanupSummary {
        guard settings.enabled else {
            throw CacheCleanupError.cleanupDisabled
        }

        let startTime = Date()
        progressHandler(0.0, "Scanning cache folders...")

        // Find cache files to delete
        let cacheFiles = try await scanCacheFiles(settings: settings)

        progressHandler(0.3, "Found \(cacheFiles.count) cache files")

        // Delete files
        var records: [CleanupRecord] = []
        var totalSize: Int64 = 0

        for (index, file) in cacheFiles.enumerated() {
            let progress = 0.3 + (0.7 * Double(index) / Double(cacheFiles.count))
            progressHandler(progress, "Deleting \(file.name)...")

            do {
                let size = file.size
                try fileManager.removeItem(atPath: file.path)

                let record = CleanupRecord(
                    filePath: file.path,
                    sizeBytes: size,
                    deletedSuccessfully: true
                )
                records.append(record)
                totalSize += size
            } catch {
                let record = CleanupRecord(
                    filePath: file.path,
                    sizeBytes: file.size,
                    deletedSuccessfully: false
                )
                records.append(record)
                print("Error deleting \(file.path): \(error)")
            }
        }

        // Update history
        var history = loadHistory()
        history.insert(contentsOf: records, at: 0)

        // Keep only last 1000 records
        if history.count > 1000 {
            history = Array(history.prefix(1000))
        }
        saveHistory(history)

        // Update last cleanup date
        var updatedSettings = settings
        updatedSettings.lastCleanupDate = Date()
        saveSettings(updatedSettings)

        let duration = Date().timeIntervalSince(startTime)
        progressHandler(1.0, "Cleanup complete")

        // Send notification
        sendNotification(totalDeleted: records.count, totalSize: totalSize)

        return CleanupSummary(
            totalDeleted: records.count,
            totalSizeFreed: totalSize,
            duration: duration,
            records: records
        )
    }

    /// Scan for cache files to delete
    private func scanCacheFiles(settings: CacheSettings) async throws -> [FileInfo] {
        var cacheFiles: [FileInfo] = []

        for parentFolder in settings.parentFolders {
            guard fileManager.fileExists(atPath: parentFolder) else { continue }

            let parentURL = URL(fileURLWithPath: parentFolder)

            // Look for cache folders
            for cacheFolderName in settings.cacheFolderNames {
                let cacheURL = parentURL.appendingPathComponent(cacheFolderName)

                if fileManager.fileExists(atPath: cacheURL.path) {
                    let files = try await scanCacheFolder(
                        at: cacheURL.path,
                        cutoffDate: settings.cutoffDate
                    )
                    cacheFiles.append(contentsOf: files)
                }
            }

            // Also search recursively in subdirectories
            if let enumerator = fileManager.enumerator(
                at: parentURL,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
                for url in allURLs {
                    let name = url.lastPathComponent

                    if settings.cacheFolderNames.contains(name) {
                        let files = try await scanCacheFolder(
                            at: url.path,
                            cutoffDate: settings.cutoffDate
                        )
                        cacheFiles.append(contentsOf: files)
                        enumerator.skipDescendants()
                    }
                }
            }
        }

        return cacheFiles
    }

    /// Scan a cache folder for old files
    private func scanCacheFolder(at path: String, cutoffDate: Date) async throws -> [FileInfo] {
        var oldFiles: [FileInfo] = []

        let url = URL(fileURLWithPath: path)
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]

        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
        for fileURL in allURLs {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                let isDirectory = resourceValues.isDirectory ?? false

                // Skip directories
                guard !isDirectory else { continue }

                // Check modification date
                if let modDate = resourceValues.contentModificationDate,
                    modDate < cutoffDate
                {
                    let info = try FileInfo.from(url: fileURL, includeChildren: false)
                    oldFiles.append(info)
                }
            } catch {
                print("Error reading \(fileURL.path): \(error)")
            }
        }

        return oldFiles
    }

    /// Send notification about cleanup
    private func sendNotification(totalDeleted: Int, totalSize: Int64) {
        let content = UNMutableNotificationContent()
        content.title = "Cache Cleanup Complete"
        content.body =
            "Deleted \(totalDeleted) files, freed \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }

    /// Clear cleanup history
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
    }
}

/// Cache cleanup errors
enum CacheCleanupError: LocalizedError {
    case cleanupDisabled
    case scanFailed
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .cleanupDisabled:
            return "Cache cleanup is disabled"
        case .scanFailed:
            return "Failed to scan cache folders"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        }
    }
}
