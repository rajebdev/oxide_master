//
//  BackupService.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation

/// Service for backup operations
class BackupService {
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard

    private let configKey = "backupConfig"
    private let historyKey = "backupHistory"

    /// Load saved backup configuration
    func loadConfig() -> BackupConfig {
        guard let data = userDefaults.data(forKey: configKey),
            let config = try? JSONDecoder().decode(BackupConfig.self, from: data)
        else {
            return BackupConfig()
        }
        return config
    }

    /// Save backup configuration
    func saveConfig(_ config: BackupConfig) {
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: configKey)
        }
    }

    /// Load backup history
    func loadHistory() -> [BackupRecord] {
        guard let data = userDefaults.data(forKey: historyKey),
            let history = try? JSONDecoder().decode([BackupRecord].self, from: data)
        else {
            return []
        }
        return history
    }

    /// Save backup history
    private func saveHistory(_ history: [BackupRecord]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }

    /// Add record to history
    private func addToHistory(_ record: BackupRecord) {
        var history = loadHistory()
        history.insert(record, at: 0)

        // Keep only last 100 records
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        saveHistory(history)
    }

    /// Run backup with current configuration
    func runBackup(
        config: BackupConfig,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> BackupRecord {
        guard config.isValid else {
            throw BackupError.invalidConfiguration
        }

        let startTime = Date()
        progressHandler(0.0, "Starting backup...")

        // Scan source directory
        progressHandler(0.1, "Scanning source directory...")
        let filesToBackup = try await scanFilesForBackup(
            sourcePath: config.sourcePath,
            cutoffDate: config.cutoffDate
        )

        progressHandler(0.3, "Found \(filesToBackup.count) files to backup")

        // Create destination directory if needed
        try fileManager.createDirectory(
            atPath: config.destinationPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Copy files
        var copiedFiles = 0
        var totalSize: Int64 = 0
        var lastError: String?

        for (index, file) in filesToBackup.enumerated() {
            let progress = 0.3 + (0.7 * Double(index) / Double(filesToBackup.count))
            progressHandler(progress, "Backing up \(file.name)...")

            do {
                let destinationPath = try getDestinationPath(
                    for: file,
                    sourcePath: config.sourcePath,
                    destinationPath: config.destinationPath,
                    preserveStructure: config.preserveStructure
                )

                // Create intermediate directories
                let destinationURL = URL(fileURLWithPath: destinationPath)
                let parentURL = destinationURL.deletingLastPathComponent()
                try fileManager.createDirectory(
                    at: parentURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                // Copy file
                if !fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.copyItem(atPath: file.path, toPath: destinationPath)
                    copiedFiles += 1
                    totalSize += file.size
                }
            } catch {
                lastError = error.localizedDescription
                print("Error copying \(file.path): \(error)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        progressHandler(1.0, "Backup complete")

        // Create backup record
        let record = BackupRecord(
            timestamp: Date(),
            sourcePath: config.sourcePath,
            destinationPath: config.destinationPath,
            filesCopied: copiedFiles,
            totalSize: totalSize,
            duration: duration,
            success: lastError == nil,
            errorMessage: lastError
        )

        // Update config with last backup date
        var updatedConfig = config
        updatedConfig.lastBackupDate = Date()
        saveConfig(updatedConfig)

        // Add to history
        addToHistory(record)

        return record
    }

    /// Scan files that match the backup criteria
    private func scanFilesForBackup(sourcePath: String, cutoffDate: Date) async throws -> [FileInfo]
    {
        var matchingFiles: [FileInfo] = []

        let url = URL(fileURLWithPath: sourcePath)
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
            throw BackupError.scanFailed
        }

        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
        for fileURL in allURLs {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                let isDirectory = resourceValues.isDirectory ?? false

                // Skip directories, only backup files
                guard !isDirectory else { continue }

                // Check modification date
                if let modDate = resourceValues.contentModificationDate,
                    modDate >= cutoffDate
                {
                    let info = try FileInfo.from(url: fileURL, includeChildren: false)
                    matchingFiles.append(info)
                }
            } catch {
                print("Error reading \(fileURL.path): \(error)")
            }
        }

        return matchingFiles
    }

    /// Get destination path for file
    private func getDestinationPath(
        for file: FileInfo,
        sourcePath: String,
        destinationPath: String,
        preserveStructure: Bool
    ) throws -> String {
        if preserveStructure {
            // Preserve folder structure
            let relativePath = String(file.path.dropFirst(sourcePath.count))
            return URL(fileURLWithPath: destinationPath)
                .appendingPathComponent(relativePath)
                .path
        } else {
            // Flat structure
            return URL(fileURLWithPath: destinationPath)
                .appendingPathComponent(file.name)
                .path
        }
    }

    /// Clear backup history
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
    }
}

/// Backup errors
enum BackupError: LocalizedError {
    case invalidConfiguration
    case scanFailed
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid backup configuration"
        case .scanFailed:
            return "Failed to scan source directory"
        case .copyFailed(let message):
            return "Copy failed: \(message)"
        }
    }
}
