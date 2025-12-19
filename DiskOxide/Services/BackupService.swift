//
//  BackupService.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Combine
import Foundation

/// Selectable item for preview
class SelectableItem: Identifiable, ObservableObject {
    let id: UUID
    let fileInfo: FileInfo
    let isRepo: Bool
    @Published var isSelected: Bool

    init(fileInfo: FileInfo, isRepo: Bool, isSelected: Bool = true) {
        self.id = fileInfo.id
        self.fileInfo = fileInfo
        self.isRepo = isRepo
        self.isSelected = isSelected
    }
}

/// Preview result for backup operation
class BackupPreviewResult: ObservableObject {
    @Published var repoItems: [SelectableItem]
    @Published var fileItems: [SelectableItem]
    private var cancellables = Set<AnyCancellable>()

    init(repos: [FileInfo], files: [FileInfo]) {
        self.repoItems = repos.map { SelectableItem(fileInfo: $0, isRepo: true) }
        self.fileItems = files.map { SelectableItem(fileInfo: $0, isRepo: false) }

        // Subscribe to changes in each item to trigger UI updates
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        for item in repoItems + fileItems {
            item.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
        }
    }

    var selectedRepos: [FileInfo] {
        repoItems.filter { $0.isSelected }.map { $0.fileInfo }
    }

    var selectedFiles: [FileInfo] {
        fileItems.filter { $0.isSelected }.map { $0.fileInfo }
    }

    var totalSize: Int64 {
        let reposSize = selectedRepos.reduce(0) { $0 + $1.size }
        let filesSize = selectedFiles.reduce(0) { $0 + $1.size }
        return reposSize + filesSize
    }

    var totalCount: Int {
        selectedRepos.count + selectedFiles.count
    }

    var allCount: Int {
        repoItems.count + fileItems.count
    }
}

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

    /// Scan and preview files to be moved
    func scanPreview(
        config: BackupConfig,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> BackupPreviewResult {
        guard config.isValid else {
            throw BackupError.invalidConfiguration
        }

        progressHandler(0.0, "Starting scan...")

        // Scan source directory for git repos and files
        progressHandler(0.3, "Scanning source directory...")
        let scanResult = try await scanForBackup(
            sourcePath: config.sourcePath,
            cutoffDate: config.cutoffDate
        )

        progressHandler(1.0, "Scan complete")

        let result = BackupPreviewResult(repos: scanResult.repos, files: scanResult.files)
        return result
    }

    /// Run backup with current configuration
    func runBackup(
        config: BackupConfig,
        previewResult: BackupPreviewResult? = nil,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> BackupRecord {
        guard config.isValid else {
            throw BackupError.invalidConfiguration
        }

        let startTime = Date()
        progressHandler(0.0, "Starting move...")

        // Use preview result if available, otherwise scan
        let scanResult: ScanResult
        if let preview = previewResult {
            progressHandler(0.1, "Using selected items...")
            // Only move selected items
            scanResult = ScanResult(repos: preview.selectedRepos, files: preview.selectedFiles)
        } else {
            progressHandler(0.1, "Scanning source directory...")
            scanResult = try await scanForBackup(
                sourcePath: config.sourcePath,
                cutoffDate: config.cutoffDate
            )
        }

        progressHandler(
            0.3, "Found \(scanResult.repos.count) repos and \(scanResult.files.count) files to move"
        )

        // Create destination directory if needed
        try fileManager.createDirectory(
            atPath: config.destinationPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Move items
        var movedFiles = 0
        var movedRepos = 0
        var totalSize: Int64 = 0
        var lastError: String?

        let totalItems = scanResult.repos.count + scanResult.files.count
        var processedItems = 0

        // Move git repos first
        for repo in scanResult.repos {
            let progress = 0.3 + (0.7 * Double(processedItems) / Double(totalItems))
            progressHandler(progress, "Moving repo \(repo.name)...")

            do {
                let destinationPath = getExactDestinationPath(
                    sourcePath: repo.path,
                    sourceRoot: config.sourcePath,
                    destinationRoot: config.destinationPath
                )

                // Create parent directory
                let destinationURL = URL(fileURLWithPath: destinationPath)
                let parentURL = destinationURL.deletingLastPathComponent()
                try fileManager.createDirectory(
                    at: parentURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                // Move entire repo folder (handle cross-volume)
                // If destination exists, remove it first (replace)
                if fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.removeItem(atPath: destinationPath)
                }

                try moveItemCrossVolume(from: repo.path, to: destinationPath)
                movedRepos += 1
                totalSize += repo.size
            } catch {
                lastError = error.localizedDescription
                print("Error moving repo \(repo.path): \(error)")
            }

            processedItems += 1
        }

        // Move individual files
        for file in scanResult.files {
            let progress = 0.3 + (0.7 * Double(processedItems) / Double(totalItems))
            progressHandler(progress, "Moving \(file.name)...")

            do {
                let destinationPath = getExactDestinationPath(
                    sourcePath: file.path,
                    sourceRoot: config.sourcePath,
                    destinationRoot: config.destinationPath
                )

                // Create parent directory
                let destinationURL = URL(fileURLWithPath: destinationPath)
                let parentURL = destinationURL.deletingLastPathComponent()
                try fileManager.createDirectory(
                    at: parentURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                // Move file (handle cross-volume)
                // If destination exists, remove it first (replace)
                if fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.removeItem(atPath: destinationPath)
                }

                try moveItemCrossVolume(from: file.path, to: destinationPath)
                movedFiles += 1
                totalSize += file.size
            } catch {
                lastError = error.localizedDescription
                print("Error moving \(file.path): \(error)")
            }

            processedItems += 1
        }

        let duration = Date().timeIntervalSince(startTime)
        progressHandler(1.0, "Move complete")

        // Create backup record
        let record = BackupRecord(
            timestamp: Date(),
            sourcePath: config.sourcePath,
            destinationPath: config.destinationPath,
            filesMoved: movedFiles,
            reposMoved: movedRepos,
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

    /// Result of scanning source directory
    private struct ScanResult {
        let repos: [FileInfo]
        let files: [FileInfo]
    }

    /// Scan for git repos and files to backup
    private func scanForBackup(sourcePath: String, cutoffDate: Date) async throws -> ScanResult {
        var gitRepos: [FileInfo] = []
        var individualFiles: [FileInfo] = []
        var processedRepoPaths: Set<String> = []

        let sourceURL = URL(fileURLWithPath: sourcePath)

        // First pass: Find project repositories (git or vscode)
        try await findProjectRepositories(
            in: sourceURL,
            cutoffDate: cutoffDate,
            repos: &gitRepos,
            processedPaths: &processedRepoPaths
        )

        // Second pass: Find individual files not in project repos
        try await findIndividualFiles(
            in: sourceURL,
            cutoffDate: cutoffDate,
            excludePaths: processedRepoPaths,
            files: &individualFiles
        )

        return ScanResult(repos: gitRepos, files: individualFiles)
    }

    /// Find project repositories (git or vscode) and check their last modified date
    private func findProjectRepositories(
        in directory: URL,
        cutoffDate: Date,
        repos: inout [FileInfo],
        processedPaths: inout Set<String>
    ) async throws {
        let resourceKeys: Set<URLResourceKey> = [.nameKey, .isDirectoryKey]

        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants]
            )
        else {
            throw BackupError.scanFailed
        }

        // Convert to array and sort by path length (shortest first)
        // This ensures parent repos are processed before nested repos
        let allURLs = enumerator.allObjects
            .compactMap { $0 as? URL }
            .sorted { $0.path.count < $1.path.count }

        // Track both processed and skipped repos
        var allCheckedPaths = Set<String>()

        for fileURL in allURLs {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            let isDirectory = resourceValues.isDirectory ?? false

            if isDirectory
                && (fileURL.lastPathComponent == ".git" || fileURL.lastPathComponent == ".vscode")
            {
                // Found a project marker, check parent directory
                let projectURL = fileURL.deletingLastPathComponent()
                let projectPath = projectURL.path

                // Check if already checked (either processed or skipped)
                if allCheckedPaths.contains(projectPath) {
                    continue
                }

                // Check if this repo is inside another repo already checked (nested repos)
                var isNestedRepo = false
                for parentPath in allCheckedPaths {
                    if projectPath.hasPrefix(parentPath + "/") {
                        isNestedRepo = true
                        break
                    }
                }

                // Skip nested repos - only keep parent repo
                if isNestedRepo {
                    continue
                }

                // Mark as checked regardless of result
                allCheckedPaths.insert(projectPath)

                // Check if project has any files modified within date range
                let hasRecentFiles = try hasFilesModifiedAfter(projectURL, cutoffDate: cutoffDate)

                if hasRecentFiles {
                    // Project is eligible for move
                    let info = try FileInfo.from(url: projectURL, includeChildren: false)
                    repos.append(info)
                    processedPaths.insert(projectPath)
                }
            }
        }
    }

    /// Find individual files not in git repos
    private func findIndividualFiles(
        in directory: URL,
        cutoffDate: Date,
        excludePaths: Set<String>,
        files: inout [FileInfo]
    ) async throws {
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]

        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        else {
            throw BackupError.scanFailed
        }

        // Convert to array to avoid async iteration warning
        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }

        // Track folders we've checked - if parent is new, skip all children
        var checkedFolders: [String: Bool] = [:]  // path -> isOld

        for fileURL in allURLs {
            // Check if file is inside an excluded repo path
            let filePath = fileURL.path
            var isInExcludedPath = false

            for excludePath in excludePaths {
                if filePath.hasPrefix(excludePath + "/") || filePath == excludePath {
                    isInExcludedPath = true
                    break
                }
            }

            if isInExcludedPath {
                continue
            }

            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            let isDirectory = resourceValues.isDirectory ?? false

            // Only process files, not directories
            if !isDirectory {
                // Check if ANY parent folder in the path is new (modified recently)
                var currentURL = fileURL.deletingLastPathComponent()
                let sourcePath = directory.path
                var skipFile = false

                // Check all parent folders from file up to source root
                while currentURL.path.hasPrefix(sourcePath) && currentURL.path != sourcePath {
                    let currentPath = currentURL.path

                    // Check cached result first
                    if let isOld = checkedFolders[currentPath] {
                        if !isOld {
                            skipFile = true
                            break
                        }
                    } else {
                        // Check folder modification date
                        let folderResources = try currentURL.resourceValues(forKeys: [
                            .contentModificationDateKey
                        ])
                        if let folderModDate = folderResources.contentModificationDate {
                            let isOld = folderModDate < cutoffDate
                            checkedFolders[currentPath] = isOld

                            if !isOld {
                                skipFile = true
                                break
                            }
                        }
                    }

                    // Move up to parent folder
                    currentURL = currentURL.deletingLastPathComponent()
                }

                if skipFile {
                    continue
                }

                // All parent folders are old, now check file itself
                if let modDate = resourceValues.contentModificationDate,
                    modDate < cutoffDate
                {
                    let info = try FileInfo.from(url: fileURL, includeChildren: false)
                    files.append(info)
                }
            }
        }
    }

    /// Check if directory should be moved (all content is old, nothing modified recently)
    private func hasFilesModifiedAfter(_ directory: URL, cutoffDate: Date) throws -> Bool {
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey]

        // First check the parent folder itself - if new, skip immediately (don't check inside)
        let parentResources = try directory.resourceValues(forKeys: resourceKeys)
        if let parentModDate = parentResources.contentModificationDate {
            if parentModDate >= cutoffDate {
                return false  // Parent folder is new, don't check children
            }
        }

        // Parent is old, now check all children (both folders and files)
        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            )
        else {
            return false
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)

                // Check modification date for both files and folders
                if let modDate = resourceValues.contentModificationDate {
                    if modDate >= cutoffDate {
                        return false  // Found something new, skip this repo
                    }
                }
            } catch {
                // Skip items we can't read
                continue
            }
        }

        return true  // Everything is old, include this repo
    }

    /// Get exact destination path preserving source structure
    private func getExactDestinationPath(
        sourcePath: String,
        sourceRoot: String,
        destinationRoot: String
    ) -> String {
        // Get relative path from source root
        let relativePath = String(sourcePath.dropFirst(sourceRoot.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Append to destination root
        return URL(fileURLWithPath: destinationRoot)
            .appendingPathComponent(relativePath)
            .path
    }

    /// Move item supporting cross-volume (different drives/external SSD)
    private func moveItemCrossVolume(from sourcePath: String, to destinationPath: String) throws {
        // Try direct move first (works for same volume)
        do {
            try fileManager.moveItem(atPath: sourcePath, toPath: destinationPath)
        } catch let error as NSError {
            // Check if error is due to cross-device move (EXDEV error code 18)
            if error.domain == NSPOSIXErrorDomain && error.code == 18 {
                // Copy then delete for cross-volume move
                try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                try fileManager.removeItem(atPath: sourcePath)
            } else {
                // Re-throw other errors
                throw error
            }
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
