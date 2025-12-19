//
//  CacheCleanerService.swift
//  OxideMaster
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

    /// Scan for cache items (preview mode)
    func scanCacheItems(
        settings: CacheSettings,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> [CacheItem] {
        var cacheItems: [CacheItem] = []
        progressHandler(0.0, "Scanning cache folders...")

        // Scan regular cache folders
        for (index, parentFolder) in settings.parentFolders.enumerated() {
            let progress = Double(index) / Double(settings.parentFolders.count) * 0.5
            progressHandler(progress, "Scanning \(parentFolder)...")

            guard fileManager.fileExists(atPath: parentFolder) else { continue }

            let parentURL = URL(fileURLWithPath: parentFolder)

            for cacheFolderName in settings.cacheFolderNames {
                let cacheURL = parentURL.appendingPathComponent(cacheFolderName)

                if fileManager.fileExists(atPath: cacheURL.path) {
                    if let size = try? await getFolderSize(at: cacheURL.path) {
                        let item = CacheItem(
                            path: cacheURL.path,
                            name: cacheFolderName,
                            sizeBytes: size,
                            type: "System Cache"
                        )
                        cacheItems.append(item)
                    }
                }
            }
        }

        progressHandler(0.5, "Scanning project caches...")

        // Scan project cache folders if enabled
        if settings.projectCacheEnabled {
            let projectCaches = try await scanProjectCacheItems(
                settings: settings,
                progressHandler: { prog, msg in
                    progressHandler(0.5 + (prog * 0.3), msg)
                }
            )
            cacheItems.append(contentsOf: projectCaches)
        }

        progressHandler(0.8, "Scanning application caches...")

        // Scan application cache folders if enabled
        if settings.applicationCacheEnabled {
            let appCaches = try await scanApplicationCacheItems(
                settings: settings,
                progressHandler: { prog, msg in
                    progressHandler(0.8 + (prog * 0.2), msg)
                }
            )
            cacheItems.append(contentsOf: appCaches)
        }

        progressHandler(1.0, "Scan complete")
        return cacheItems
    }

    /// Scan for application cache items
    private func scanApplicationCacheItems(
        settings: CacheSettings,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> [CacheItem] {
        var appCaches: [CacheItem] = []
        let totalTypes = settings.enabledApplicationCacheTypes.count

        for (index, cacheType) in settings.enabledApplicationCacheTypes.enumerated() {
            let progress = Double(index) / Double(totalTypes)
            progressHandler(progress, "Scanning \(cacheType.displayName)...")

            // Scan each cache path for this type
            for cachePath in cacheType.cachePaths {
                // Handle wildcard patterns
                if cachePath.contains("*") {
                    let caches = try await scanWildcardPath(cachePath)
                    appCaches.append(
                        contentsOf: caches.map { path, size in
                            CacheItem(
                                path: path,
                                name: (path as NSString).lastPathComponent,
                                sizeBytes: size,
                                type: "App: \(cacheType.displayName)"
                            )
                        })
                } else {
                    // Expand tilde
                    let expandedPath = (cachePath as NSString).expandingTildeInPath

                    if fileManager.fileExists(atPath: expandedPath) {
                        if let size = try? await getFolderSize(at: expandedPath) {
                            let item = CacheItem(
                                path: expandedPath,
                                name: (expandedPath as NSString).lastPathComponent,
                                sizeBytes: size,
                                type: "App: \(cacheType.displayName)"
                            )
                            appCaches.append(item)
                        }
                    }
                }
            }
        }

        // Scan installed apps if enabled
        if settings.scanInstalledApps {
            progressHandler(0.9, "Scanning installed applications...")
            let installedAppCaches = try await scanInstalledApplications(settings: settings)
            appCaches.append(contentsOf: installedAppCaches)
        }

        progressHandler(1.0, "Application cache scan complete")
        return appCaches
    }

    /// Scan for cache from installed applications
    private func scanInstalledApplications(settings: CacheSettings) async throws -> [CacheItem] {
        var appCaches: [CacheItem] = []
        let applicationsPath = "/Applications"
        let home = fileManager.homeDirectoryForCurrentUser.path
        let userCachePath = "\(home)/Library/Caches"

        guard let apps = try? fileManager.contentsOfDirectory(atPath: applicationsPath) else {
            return []
        }

        // Get all app bundle identifiers
        var appBundleIds: [String: String] = [:]  // [bundleId: appName]

        for app in apps where app.hasSuffix(".app") {
            let appPath = "\(applicationsPath)/\(app)"
            let infoPlistPath = "\(appPath)/Contents/Info.plist"

            if fileManager.fileExists(atPath: infoPlistPath),
                let plistData = fileManager.contents(atPath: infoPlistPath),
                let plist = try? PropertyListSerialization.propertyList(
                    from: plistData,
                    options: [],
                    format: nil
                ) as? [String: Any],
                let bundleId = plist["CFBundleIdentifier"] as? String
            {
                let appName = (app as NSString).deletingPathExtension
                appBundleIds[bundleId] = appName
            }
        }

        // Find caches for each app
        for (bundleId, appName) in appBundleIds {
            let cachePath = "\(userCachePath)/\(bundleId)"

            if fileManager.fileExists(atPath: cachePath) {
                if let size = try? await getFolderSize(at: cachePath), size > 0 {
                    let item = CacheItem(
                        path: cachePath,
                        name: "\(appName) Cache",
                        sizeBytes: size,
                        type: "App: \(appName)"
                    )
                    appCaches.append(item)
                }
            }
        }

        return appCaches
    }

    /// Scan paths with wildcards
    private func scanWildcardPath(_ pattern: String) async throws -> [(path: String, size: Int64)] {
        var results: [(String, Int64)] = []
        let expandedPattern = (pattern as NSString).expandingTildeInPath
        let components = expandedPattern.components(separatedBy: "*")

        guard components.count == 2 else { return [] }

        let basePath = components[0].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = components[1]

        let baseURL = URL(fileURLWithPath: basePath)

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        for itemURL in contents {
            let itemPath = itemURL.path
            if suffix.isEmpty || itemPath.hasSuffix(suffix) {
                if fileManager.fileExists(atPath: itemPath) {
                    if let size = try? await getFolderSize(at: itemPath), size > 0 {
                        results.append((itemPath, size))
                    }
                }
            }
        }

        return results
    }

    /// Scan for project cache items
    private func scanProjectCacheItems(
        settings: CacheSettings,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> [CacheItem] {
        var projectCaches: [CacheItem] = []
        var addedPaths: Set<String> = []
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        let projectLocations = [
            "\(homeDir)/Documents",
            "\(homeDir)/Projects",
            "\(homeDir)/Developer",
            "\(homeDir)/workspace",
            "\(homeDir)/code",
        ]

        for (index, location) in projectLocations.enumerated() {
            let progress = Double(index) / Double(projectLocations.count)
            progressHandler(progress, "Scanning \(location)...")

            guard fileManager.fileExists(atPath: location) else { continue }

            let caches = try await scanDirectoryForProjectCacheItems(
                at: location,
                depth: 0,
                maxDepth: settings.projectScanDepth,
                enabledTypes: settings.enabledProjectCacheTypes,
                addedPaths: &addedPaths
            )
            projectCaches.append(contentsOf: caches)
        }

        return projectCaches
    }

    /// Recursively scan directory for project cache items
    private func scanDirectoryForProjectCacheItems(
        at path: String,
        depth: Int,
        maxDepth: Int,
        enabledTypes: [ProjectCacheType],
        addedPaths: inout Set<String>
    ) async throws -> [CacheItem] {
        guard depth < maxDepth else { return [] }

        // Check if current path is already inside an added parent
        let currentPath = path
        for addedPath in addedPaths {
            if currentPath.hasPrefix(addedPath + "/") || currentPath == addedPath {
                // This path is inside an already added parent, skip it
                return []
            }
        }

        var foundCaches: [CacheItem] = []
        let url = URL(fileURLWithPath: path)

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        for itemURL in contents {
            let isDirectory =
                (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }

            let itemPath = itemURL.path

            // Check if this path is already inside an added parent
            var isInsideAddedPath = false
            for addedPath in addedPaths {
                if itemPath.hasPrefix(addedPath + "/") || itemPath == addedPath {
                    isInsideAddedPath = true
                    break
                }
            }

            if isInsideAddedPath {
                // Skip this path as it's inside an already added parent
                continue
            }

            let folderName = itemURL.lastPathComponent

            // Check if this is a project cache folder
            var foundMatch = false
            for cacheType in enabledTypes {
                if folderName == cacheType.folderName {
                    // Validate it's actually a project folder
                    if isValidProjectCache(cacheFolder: itemPath, type: cacheType) {
                        // Get size and last modified date
                        if let size = try? await getFolderSize(at: itemPath) {
                            let lastModified = getLastModifiedDate(at: itemPath)
                            let item = CacheItem(
                                path: itemPath,
                                name: folderName,
                                sizeBytes: size,
                                type: cacheType.displayName,
                                lastModified: lastModified
                            )
                            foundCaches.append(item)
                            addedPaths.insert(itemPath)
                            foundMatch = true
                            break  // Only add once per folder
                        }
                    }
                }
            }

            if foundMatch {
                // Don't recurse into cache folders
                continue
            }

            // Recurse into subdirectories
            let subCaches = try await scanDirectoryForProjectCacheItems(
                at: itemPath,
                depth: depth + 1,
                maxDepth: maxDepth,
                enabledTypes: enabledTypes,
                addedPaths: &addedPaths
            )
            foundCaches.append(contentsOf: subCaches)
        }

        return foundCaches
    }

    /// Get folder size using du command
    private func getFolderSize(at path: String) async throws -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return 0
        }

        // Parse output: "12345\t/path/to/folder"
        let components = output.components(separatedBy: "\t")
        guard let sizeStr = components.first,
            let sizeKB = Int64(sizeStr.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return 0
        }

        return sizeKB * 1024  // Convert KB to bytes
    }

    /// Get last modified date of a folder
    private func getLastModifiedDate(at path: String) -> Date? {
        // Get the most recent modification date from the folder and all its contents
        return getMostRecentModificationDate(at: path)
    }

    /// Get the most recent modification date from a folder and all its contents recursively
    private func getMostRecentModificationDate(at path: String) -> Date? {
        let url = URL(fileURLWithPath: path)

        // Get the folder's own modification date
        guard let folderAttributes = try? fileManager.attributesOfItem(atPath: path),
            var mostRecentDate = folderAttributes[.modificationDate] as? Date
        else {
            return nil
        }

        // Create an enumerator to traverse all contents
        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return mostRecentDate
        }

        // Check all files and folders inside
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [
                .contentModificationDateKey
            ]),
                let modDate = resourceValues.contentModificationDate
            {
                // Update if this date is more recent
                if modDate > mostRecentDate {
                    mostRecentDate = modDate
                }
            }
        }

        return mostRecentDate
    }

    /// Run cache cleanup with selected items
    func runCleanup(
        items: [CacheItem],
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> CleanupSummary {
        let startTime = Date()
        let selectedItems = items.filter { $0.isSelected }

        guard !selectedItems.isEmpty else {
            throw CacheCleanupError.noItemsSelected
        }

        progressHandler(0.0, "Starting cleanup...")

        // Delete items
        var records: [CleanupRecord] = []
        var totalSize: Int64 = 0

        for (index, item) in selectedItems.enumerated() {
            let progress = Double(index) / Double(selectedItems.count)
            progressHandler(progress, "Deleting \(item.name)...")

            do {
                let url = URL(fileURLWithPath: item.path)

                // Determine cleanup behavior based on category
                switch item.category {
                case .applicationCache, .projectCache:
                    // Delete entire folder for app and project cache
                    try fileManager.trashItem(at: url, resultingItemURL: nil)

                case .systemCache:
                    // Delete only contents for system cache (safer)
                    try deleteDirectoryContents(at: item.path)
                }

                let record = CleanupRecord(
                    filePath: item.path,
                    sizeBytes: item.sizeBytes,
                    deletedSuccessfully: true
                )
                records.append(record)
                totalSize += item.sizeBytes
            } catch {
                let record = CleanupRecord(
                    filePath: item.path,
                    sizeBytes: item.sizeBytes,
                    deletedSuccessfully: false
                )
                records.append(record)
                print("Error deleting \(item.path): \(error)")
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
        var settings = loadSettings()
        settings.lastCleanupDate = Date()
        saveSettings(settings)

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

        // Regular cache folders
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

        // Project cache folders (with validation)
        if settings.projectCacheEnabled {
            let projectCaches = try await scanProjectCaches(settings: settings)
            cacheFiles.append(contentsOf: projectCaches)
        }

        return cacheFiles
    }

    /// Scan for project cache folders with validation
    private func scanProjectCaches(settings: CacheSettings) async throws -> [FileInfo] {
        var projectCaches: [FileInfo] = []
        var addedPaths: Set<String> = []
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // Start from common project locations
        let projectLocations = [
            "\(homeDir)/Documents",
            "\(homeDir)/Projects",
            "\(homeDir)/Developer",
            "\(homeDir)/workspace",
            "\(homeDir)/code",
        ]

        for location in projectLocations {
            guard fileManager.fileExists(atPath: location) else { continue }

            let caches = try await scanDirectoryForProjectCaches(
                at: location,
                depth: 0,
                maxDepth: settings.projectScanDepth,
                enabledTypes: settings.enabledProjectCacheTypes,
                addedPaths: &addedPaths
            )
            projectCaches.append(contentsOf: caches)
        }

        return projectCaches
    }

    /// Recursively scan directory for project caches
    private func scanDirectoryForProjectCaches(
        at path: String,
        depth: Int,
        maxDepth: Int,
        enabledTypes: [ProjectCacheType],
        addedPaths: inout Set<String>
    ) async throws -> [FileInfo] {
        guard depth < maxDepth else { return [] }

        // Check if current path is already inside an added parent
        let currentPath = path
        for addedPath in addedPaths {
            if currentPath.hasPrefix(addedPath + "/") || currentPath == addedPath {
                // This path is inside an already added parent, skip it
                return []
            }
        }

        var foundCaches: [FileInfo] = []
        let url = URL(fileURLWithPath: path)

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        for itemURL in contents {
            let isDirectory =
                (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }

            let itemPath = itemURL.path

            // Check if this path is already inside an added parent
            var isInsideAddedPath = false
            for addedPath in addedPaths {
                if itemPath.hasPrefix(addedPath + "/") || itemPath == addedPath {
                    isInsideAddedPath = true
                    break
                }
            }

            if isInsideAddedPath {
                // Skip this path as it's inside an already added parent
                continue
            }

            let folderName = itemURL.lastPathComponent

            // Check if this is a project cache folder
            var foundMatch = false
            for cacheType in enabledTypes {
                if folderName == cacheType.folderName {
                    // Validate it's actually a project folder
                    if isValidProjectCache(cacheFolder: itemPath, type: cacheType) {
                        // Add the entire folder as a cache item
                        if let cacheInfo = try? FileInfo.from(url: itemURL, includeChildren: false)
                        {
                            foundCaches.append(cacheInfo)
                            addedPaths.insert(itemPath)
                            foundMatch = true
                            break  // Only add once per folder
                        }
                    }
                }
            }

            if foundMatch {
                // Don't recurse into cache folders
                continue
            }

            // Recurse into subdirectories
            let subCaches = try await scanDirectoryForProjectCaches(
                at: itemPath,
                depth: depth + 1,
                maxDepth: maxDepth,
                enabledTypes: enabledTypes,
                addedPaths: &addedPaths
            )
            foundCaches.append(contentsOf: subCaches)
        }

        return foundCaches
    }

    /// Validate that a cache folder is actually part of a project
    private func isValidProjectCache(cacheFolder: String, type: ProjectCacheType) -> Bool {
        let cacheFolderURL = URL(fileURLWithPath: cacheFolder)
        let parentURL = cacheFolderURL.deletingLastPathComponent()

        // Check for validation files in parent directory
        for validationPattern in type.validationFiles {
            if validationPattern.contains("*") {
                // Handle wildcard patterns (e.g., "*.py", "*.csproj")
                let ext = validationPattern.replacingOccurrences(of: "*", with: "")
                if hasFilesWithExtension(ext, in: parentURL.path) {
                    return true
                }
            } else {
                // Check for specific file
                let validationURL = parentURL.appendingPathComponent(validationPattern)
                if fileManager.fileExists(atPath: validationURL.path) {
                    return true
                }
            }
        }

        // Special validations for ambiguous folder names
        switch type {
        case .rustTarget, .cargoTarget:
            let cargoToml = parentURL.appendingPathComponent("Cargo.toml")
            return fileManager.fileExists(atPath: cargoToml.path)

        case .javaTarget:
            let hasPom = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("pom.xml").path)
            let hasGradle = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("build.gradle").path)
            return hasPom || hasGradle

        case .scalaTarget:
            let hasSbt = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("build.sbt").path)
            let hasSc = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("build.sc").path)
            return hasSbt || hasSc

        case .goVendor:
            // Go vendor folder
            let hasGoMod = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("go.mod").path)
            let hasGopkg = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("Gopkg.toml").path)
            return hasGoMod || hasGopkg

        case .phpVendor:
            // PHP Composer vendor folder
            let hasComposer = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("composer.json").path)
            return hasComposer

        case .rubyVendor:
            // Ruby bundler vendor/bundle
            let hasGemfile = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("Gemfile").path)
            return hasGemfile

        case .derivedData:
            // Xcode DerivedData - check parent for .xcodeproj or .xcworkspace
            return hasFilesWithExtension(".xcodeproj", in: parentURL.path)
                || hasFilesWithExtension(".xcworkspace", in: parentURL.path)

        case .gradleBuild, .kotlinBuild:
            let hasGradle =
                fileManager.fileExists(
                    atPath: parentURL.appendingPathComponent("build.gradle").path)
                || fileManager.fileExists(
                    atPath: parentURL.appendingPathComponent("build.gradle.kts").path)
            return hasGradle

        case .flutterBuild:
            let hasPubspec = fileManager.fileExists(
                atPath: parentURL.appendingPathComponent("pubspec.yaml").path)
            return hasPubspec

        case .dotnetObj, .dotnetBin:
            return hasFilesWithExtension(".csproj", in: parentURL.path)
                || hasFilesWithExtension(".fsproj", in: parentURL.path)
                || hasFilesWithExtension(".vbproj", in: parentURL.path)

        default:
            break
        }

        return false
    }

    /// Check if directory has files with specific extension
    private func hasFilesWithExtension(_ ext: String, in directory: String) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return false
        }

        return contents.contains { $0.hasSuffix(ext) }
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

    /// Delete only the contents of a directory, keeping the directory itself
    private func deleteDirectoryContents(at path: String) throws {
        let url = URL(fileURLWithPath: path)

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )
        else {
            return
        }

        for itemURL in contents {
            try fileManager.trashItem(at: itemURL, resultingItemURL: nil)
        }
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
    case noItemsSelected

    var errorDescription: String? {
        switch self {
        case .cleanupDisabled:
            return "Cache cleanup is disabled"
        case .scanFailed:
            return "Failed to scan cache folders"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .noItemsSelected:
            return "No items selected for cleanup"
        }
    }
}
