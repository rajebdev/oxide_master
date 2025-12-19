import AppKit
import Foundation

class AppUninstallerService: ObservableObject {
    static let shared = AppUninstallerService()

    private let fileManager = FileManager.default
    private let systemApps = [
        "Finder", "Safari", "Mail", "Messages", "FaceTime", "Photos", "Music", "TV", "Podcasts",
        "Books", "App Store", "System Settings", "Terminal",
    ]

    // MARK: - Scan Applications

    func scanApplications(progress: @escaping (String) -> Void) async throws -> [AppInfo] {
        var apps: [AppInfo] = []
        var seenBundleIds = Set<String>()

        let applicationPaths = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory() + "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/Library/PreferencePanes"),
            URL(fileURLWithPath: NSHomeDirectory() + "/Library/PreferencePanes"),
            URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL"),
            URL(fileURLWithPath: "/opt/homebrew/Caskroom"),
            URL(fileURLWithPath: "/usr/local/Caskroom"),
        ]

        // Homebrew Cellar paths (for formulas like python, go, node, etc)
        let homebrewCellarPaths = [
            URL(fileURLWithPath: "/opt/homebrew/Cellar"),
            URL(fileURLWithPath: "/usr/local/Cellar"),
        ]

        // Extensions to scan for
        let validExtensions = ["app", "prefPane", "driver", "plugin", "bundle"]

        for appPath in applicationPaths {
            guard fileManager.fileExists(atPath: appPath.path) else { continue }

            // For Homebrew Caskroom, need to scan subdirectories
            if appPath.path.contains("Caskroom") {
                guard
                    let casks = try? fileManager.contentsOfDirectory(
                        at: appPath,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                else { continue }

                for cask in casks {
                    guard
                        let versions = try? fileManager.contentsOfDirectory(
                            at: cask,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        )
                    else { continue }

                    for version in versions {
                        let appFiles =
                            (try? fileManager.contentsOfDirectory(
                                at: version,
                                includingPropertiesForKeys: [.isDirectoryKey],
                                options: [.skipsHiddenFiles]
                            )) ?? []

                        for item in appFiles where validExtensions.contains(item.pathExtension) {
                            progress("Scanning \(item.lastPathComponent)...")

                            if let appInfo = try? await scanApplication(at: item),
                                !seenBundleIds.contains(appInfo.bundleIdentifier)
                            {
                                apps.append(appInfo)
                                seenBundleIds.insert(appInfo.bundleIdentifier)
                            }
                        }
                    }
                }
            } else {
                let contents = try fileManager.contentsOfDirectory(
                    at: appPath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for item in contents where validExtensions.contains(item.pathExtension) {
                    progress("Scanning \(item.lastPathComponent)...")

                    if let appInfo = try? await scanApplication(at: item),
                        !seenBundleIds.contains(appInfo.bundleIdentifier)
                    {
                        apps.append(appInfo)
                        seenBundleIds.insert(appInfo.bundleIdentifier)
                    }
                }
            }
        }

        // Scan Homebrew Cellar for formulas (python, go, node, etc)
        for cellarPath in homebrewCellarPaths {
            guard fileManager.fileExists(atPath: cellarPath.path) else { continue }

            guard
                let formulas = try? fileManager.contentsOfDirectory(
                    at: cellarPath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            for formula in formulas {
                progress("Scanning \(formula.lastPathComponent)...")

                // Get versions
                guard
                    let versions = try? fileManager.contentsOfDirectory(
                        at: formula,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    ).sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
                else { continue }

                // Use latest version
                if let latestVersion = versions.first {
                    let formulaName = formula.lastPathComponent
                    let version = latestVersion.lastPathComponent
                    let size = (try? getDirectorySize(url: formula)) ?? 0

                    // Create AppInfo for Homebrew formula
                    let appInfo = AppInfo(
                        name: formulaName,
                        bundleIdentifier: "org.homebrew.formula.\(formulaName)",
                        version: version,
                        appPath: formula,
                        appSize: size,
                        icon: NSImage(
                            systemSymbolName: "terminal.fill", accessibilityDescription: nil),
                        isSystemApp: false,
                        source: .homebrew,
                        installType: .homebrewFormula
                    )

                    if !seenBundleIds.contains(appInfo.bundleIdentifier) {
                        apps.append(appInfo)
                        seenBundleIds.insert(appInfo.bundleIdentifier)
                    }
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    private func scanApplication(at url: URL) async throws -> AppInfo? {
        let infoPlistPath = url.appendingPathComponent("Contents/Info.plist")

        guard let plistData = try? Data(contentsOf: infoPlistPath),
            let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil)
                as? [String: Any]
        else {
            return nil
        }

        let name =
            (plist["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let bundleIdentifier = plist["CFBundleIdentifier"] as? String ?? ""
        let version = plist["CFBundleShortVersionString"] as? String ?? "Unknown"

        let appSize = try? getDirectorySize(url: url)
        let icon = NSWorkspace.shared.icon(forFile: url.path)

        // Check if system app
        let isSystemApp = systemApps.contains(name) || url.path.hasPrefix("/System/")

        // Determine app source and install type
        let source: AppInfo.AppSource
        let installType: AppInfo.InstallType

        if url.path.hasPrefix("/System/") || systemApps.contains(name) {
            source = .system
            installType = .regular
        } else if url.path.contains("Caskroom") {
            source = .homebrew
            installType = .homebrewCask
        } else if plist["AppStoreReceiptURL"] != nil {
            source = .appStore
            installType = .regular
        } else if url.pathExtension == "prefPane" {
            source = .user
            installType = .prefPane
        } else if url.pathExtension == "driver" {
            source = .user
            installType = .driver
        } else {
            source = .user
            installType = .regular
        }

        var appInfo = AppInfo(
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            appPath: url,
            appSize: appSize ?? 0,
            icon: icon,
            isSystemApp: isSystemApp,
            source: source,
            installType: installType
        )

        // Scan related files in background
        appInfo.relatedFiles = await scanRelatedFiles(
            bundleIdentifier: bundleIdentifier, appName: name)
        appInfo.loginItems = await scanLoginItems(bundleIdentifier: bundleIdentifier, appName: name)
        appInfo.lastUsedDate = getLastUsedDate(for: url)

        return appInfo
    }

    // MARK: - Scan Related Files

    func scanRelatedFiles(bundleIdentifier: String, appName: String) async -> [RelatedFile] {
        var relatedFiles: [RelatedFile] = []

        let homeDir = NSHomeDirectory()
        let searchPaths: [(path: String, category: RelatedFile.FileCategory)] = [
            ("\(homeDir)/Library/Application Support/\(appName)", .applicationSupport),
            ("\(homeDir)/Library/Preferences/\(bundleIdentifier).plist", .preferences),
            ("\(homeDir)/Library/Caches/\(bundleIdentifier)", .caches),
            ("\(homeDir)/Library/Caches/\(appName)", .caches),
            ("\(homeDir)/Library/Logs/\(appName)", .logs),
            ("\(homeDir)/Library/Containers/\(bundleIdentifier)", .containers),
            (
                "\(homeDir)/Library/Saved Application State/\(bundleIdentifier).savedState",
                .savedState
            ),
            ("\(homeDir)/Library/LaunchAgents/\(bundleIdentifier).plist", .launchAgents),
            ("/Library/LaunchDaemons/\(bundleIdentifier).plist", .launchDaemons),
        ]

        for (path, category) in searchPaths {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                let size = (try? getDirectorySize(url: url)) ?? 0
                relatedFiles.append(RelatedFile(path: url, category: category, size: size))
            }
        }

        // Search in Application Support for variations
        await searchInDirectory(
            path: "\(homeDir)/Library/Application Support",
            pattern: appName,
            category: .applicationSupport,
            results: &relatedFiles
        )

        // Search in Preferences for variations
        await searchInDirectory(
            path: "\(homeDir)/Library/Preferences",
            pattern: bundleIdentifier,
            category: .preferences,
            results: &relatedFiles
        )

        return relatedFiles
    }

    private func searchInDirectory(
        path: String,
        pattern: String,
        category: RelatedFile.FileCategory,
        results: inout [RelatedFile]
    ) async {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return }

        for item in contents {
            if item.localizedCaseInsensitiveContains(pattern) {
                let url = URL(fileURLWithPath: path).appendingPathComponent(item)
                let size = (try? getDirectorySize(url: url)) ?? 0

                // Avoid duplicates
                if !results.contains(where: { $0.path == url }) {
                    results.append(RelatedFile(path: url, category: category, size: size))
                }
            }
        }
    }

    // MARK: - Scan Login Items

    func scanLoginItems(bundleIdentifier: String, appName: String) async -> [LoginItem] {
        var loginItems: [LoginItem] = []

        let homeDir = NSHomeDirectory()
        let launchPaths: [(path: String, type: LoginItem.LoginItemType)] = [
            ("\(homeDir)/Library/LaunchAgents/\(bundleIdentifier).plist", .launchAgent),
            ("/Library/LaunchDaemons/\(bundleIdentifier).plist", .launchDaemon),
        ]

        for (path, type) in launchPaths {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                loginItems.append(LoginItem(path: url, type: type, isEnabled: true))
            }
        }

        // Search for variations
        if let userAgents = try? fileManager.contentsOfDirectory(
            atPath: "\(homeDir)/Library/LaunchAgents")
        {
            for item in userAgents where item.contains(bundleIdentifier) || item.contains(appName) {
                let url = URL(fileURLWithPath: "\(homeDir)/Library/LaunchAgents")
                    .appendingPathComponent(item)
                if !loginItems.contains(where: { $0.path == url }) {
                    loginItems.append(LoginItem(path: url, type: .launchAgent, isEnabled: true))
                }
            }
        }

        return loginItems
    }

    // MARK: - Scan Orphaned Files

    func scanOrphanedFiles(installedApps: [AppInfo], progress: @escaping (String) -> Void)
        async throws -> [OrphanedFiles]
    {
        var orphaned: [String: [RelatedFile]] = [:]

        let homeDir = NSHomeDirectory()
        let searchDirs = [
            "\(homeDir)/Library/Application Support",
            "\(homeDir)/Library/Preferences",
            "\(homeDir)/Library/Caches",
            "\(homeDir)/Library/Logs",
            "\(homeDir)/Library/Containers",
            "\(homeDir)/Library/Saved Application State",
            "\(homeDir)/Library/LaunchAgents",
        ]

        let installedBundleIds = Set(installedApps.map { $0.bundleIdentifier })
        let installedNames = Set(installedApps.map { $0.name })

        for dir in searchDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }

            for item in contents {
                progress("Scanning \(item)...")

                let itemPath = URL(fileURLWithPath: dir).appendingPathComponent(item)

                // Check if this belongs to an installed app
                let belongsToInstalled =
                    installedBundleIds.contains { item.contains($0) }
                    || installedNames.contains { item.contains($0) }

                if !belongsToInstalled {
                    // Try to extract bundle identifier or app name
                    if let bundleId = extractBundleIdentifier(from: item) {
                        let size = (try? getDirectorySize(url: itemPath)) ?? 0
                        let category = categoryForPath(dir)
                        let relatedFile = RelatedFile(
                            path: itemPath, category: category, size: size)

                        orphaned[bundleId, default: []].append(relatedFile)
                    }
                }
            }
        }

        return orphaned.map { bundleId, files in
            OrphanedFiles(
                bundleIdentifier: bundleId,
                appName: extractAppName(from: bundleId),
                files: files
            )
        }.sorted { $0.totalSize > $1.totalSize }
    }

    // MARK: - Uninstall

    func uninstallApp(
        _ app: AppInfo,
        removeAppBundle: Bool = true,
        removeRelatedFiles: Bool = true,
        removeLoginItems: Bool = true,
        moveToTrash: Bool = true
    ) async throws {
        var itemsToDelete: [URL] = []
        var errors: [String] = []

        // Handle Homebrew packages differently
        if app.installType == .homebrewFormula || app.installType == .homebrewCask {
            try await uninstallHomebrewPackage(
                app,
                removeAppBundle: removeAppBundle,
                removeRelatedFiles: removeRelatedFiles
            )
            return
        }

        // Add app bundle
        if removeAppBundle {
            itemsToDelete.append(app.appPath)
        }

        // Add related files
        if removeRelatedFiles {
            itemsToDelete.append(contentsOf: app.relatedFiles.map { $0.path })
        }

        // Disable and remove login items
        if removeLoginItems {
            for loginItem in app.loginItems {
                do {
                    try await disableLoginItem(loginItem)
                } catch {
                    print("Failed to disable login item: \(loginItem.path.path) - \(error)")
                }
                itemsToDelete.append(loginItem.path)
            }
        }

        // Separate items by permission requirements
        var protectedItems: [URL] = []

        // Try to delete items normally first
        for item in itemsToDelete {
            guard fileManager.fileExists(atPath: item.path) else {
                continue
            }

            do {
                if moveToTrash {
                    var resultURL: NSURL?
                    try fileManager.trashItem(at: item, resultingItemURL: &resultURL)
                    print("✅ Moved to trash: \(item.path)")
                } else {
                    try fileManager.removeItem(at: item)
                    print("✅ Deleted: \(item.path)")
                }
            } catch {
                // Failed, needs admin privileges
                protectedItems.append(item)
            }
        }

        // Delete all protected items with ONE password prompt
        if !protectedItems.isEmpty {
            print("⚠️ \(protectedItems.count) items need admin privileges...")

            do {
                try await deleteMultipleWithAdminPrivileges(
                    protectedItems, moveToTrash: moveToTrash)
                print("✅ All protected items deleted")
            } catch {
                let itemNames = protectedItems.map { $0.lastPathComponent }.joined(separator: ", ")
                let errorMsg = """
                    Failed to delete protected items: \(itemNames)
                    Error: \(error.localizedDescription)

                    These files are protected by macOS. To remove them manually:
                    1. Open Finder and navigate to each file
                    2. Right-click and select "Move to Trash"
                    3. Enter your password when prompted
                    """
                errors.append(errorMsg)
                print("❌ \(errorMsg)")
            }
        }

        // Throw error if any deletions failed
        if !errors.isEmpty {
            throw NSError(
                domain: "AppUninstaller",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: "\n")]
            )
        }
    }

    private func deleteMultipleWithAdminPrivileges(_ urls: [URL], moveToTrash: Bool) async throws {
        // Build a single command to delete all items at once (only ask password ONCE)
        let command: String

        if moveToTrash {
            // Move to trash using command line (no Finder popup!)
            let trashPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".Trash").path
            let moveCommands = urls.map { url in
                let fileName = url.lastPathComponent
                let destination = "\(trashPath)/\(fileName)"
                return "mv '\(url.path)' '\(destination)' 2>/dev/null || rm -rf '\(url.path)'"
            }.joined(separator: "; ")
            command = moveCommands
        } else {
            // Direct delete with rm
            let paths = urls.map { "'\($0.path)'" }.joined(separator: " ")
            command = "rm -rf \(paths)"
        }

        let script = """
            do shell script "\(command)" with administrator privileges
            """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                throw NSError(
                    domain: "AppUninstaller",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to delete with admin privileges: \(error)"
                    ]
                )
            }
        } else {
            throw NSError(
                domain: "AppUninstaller",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create AppleScript"]
            )
        }
    }

    private func uninstallHomebrewPackage(
        _ app: AppInfo,
        removeAppBundle: Bool = true,
        removeRelatedFiles: Bool = true
    ) async throws {
        let packageName = app.name

        // Build uninstall command based on options
        var commands: [String] = []

        // Option 1: Remove the package itself (app bundle)
        if removeAppBundle {
            if app.installType == .homebrewFormula {
                commands.append("brew uninstall '\(packageName)'")
            } else {
                // For casks, use --zap if we want complete removal
                if removeRelatedFiles {
                    commands.append("brew uninstall --cask --zap '\(packageName)'")
                } else {
                    // Just remove app without related files
                    commands.append("brew uninstall --cask '\(packageName)'")
                }
            }
        }

        // Option 2: Remove cache and related files
        if removeRelatedFiles {
            let homeDir = NSHomeDirectory()

            // Cleanup Homebrew cache
            commands.append("brew cleanup '\(packageName)' 2>/dev/null || true")

            // Remove package-specific cache and logs
            commands.append(
                "rm -rf '\(homeDir)/Library/Caches/Homebrew/\(packageName)' 2>/dev/null || true")
            commands.append(
                "rm -rf '\(homeDir)/Library/Logs/Homebrew/\(packageName)' 2>/dev/null || true")

            // Also remove related files if they exist
            if !app.relatedFiles.isEmpty {
                let paths = app.relatedFiles.map { "'\($0.path.path)'" }.joined(separator: " ")
                commands.append("rm -rf \(paths) 2>/dev/null || true")
            }
        }

        guard !commands.isEmpty else {
            print("⚠️ No uninstall operations selected")
            return
        }

        let combinedCommand = commands.joined(separator: "; ")

        print("🍺 Uninstalling Homebrew package: \(combinedCommand)")

        let script = """
            do shell script "\(combinedCommand)" with administrator privileges
            """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)

            if let error = error {
                throw NSError(
                    domain: "AppUninstaller",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to uninstall Homebrew package: \(error)"
                    ]
                )
            }

            print("✅ Successfully uninstalled: \(packageName)")
            print("Result: \(result.stringValue ?? "")")
        } else {
            throw NSError(
                domain: "AppUninstaller",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create uninstall script"]
            )
        }
    }

    func cleanOrphanedFiles(_ orphaned: OrphanedFiles, moveToTrash: Bool = true) async throws {
        for file in orphaned.files {
            if moveToTrash {
                try? fileManager.trashItem(at: file.path, resultingItemURL: nil)
            } else {
                try? fileManager.removeItem(at: file.path)
            }
        }
    }

    // MARK: - Helper Methods

    private func disableLoginItem(_ item: LoginItem) async throws {
        // For LaunchAgents/Daemons, we need to unload them first
        if item.type == .launchAgent || item.type == .launchDaemon {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", item.path.path]
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func getDirectorySize(url: URL) throws -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }

        if isDirectory.boolValue {
            var totalSize: Int64 = 0
            let enumerator = fileManager.enumerator(
                at: url, includingPropertiesForKeys: [.fileSizeKey])

            while let fileURL = enumerator?.nextObject() as? URL {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }

            return totalSize
        } else {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return Int64(attributes[.size] as? UInt64 ?? 0)
        }
    }

    private func getLastUsedDate(for url: URL) -> Date? {
        var dates: [Date] = []

        // Check content access date
        if let accessDate = try? url.resourceValues(forKeys: [.contentAccessDateKey])
            .contentAccessDate
        {
            dates.append(accessDate)
        }

        // Check content modification date
        if let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        {
            dates.append(modDate)
        }

        // Check attribute modification date
        if let attrModDate = try? url.resourceValues(forKeys: [.attributeModificationDateKey])
            .attributeModificationDate
        {
            dates.append(attrModDate)
        }

        // For .app bundles, check the executable and recent files
        if url.pathExtension == "app" {
            let executablePath = url.appendingPathComponent("Contents/MacOS")
            if let contents = try? fileManager.contentsOfDirectory(
                at: executablePath,
                includingPropertiesForKeys: [.contentAccessDateKey, .contentModificationDateKey],
                options: [])
            {
                for file in contents {
                    if let fileAccessDate = try? file.resourceValues(forKeys: [
                        .contentAccessDateKey
                    ]).contentAccessDate {
                        dates.append(fileAccessDate)
                    }
                    if let fileModDate = try? file.resourceValues(forKeys: [
                        .contentModificationDateKey
                    ]).contentModificationDate {
                        dates.append(fileModDate)
                    }
                }
            }

            // Check Preferences and Caches for recent activity
            if let bundleId = Bundle(url: url)?.bundleIdentifier {
                let homeDir = NSHomeDirectory()
                let activityPaths = [
                    "\(homeDir)/Library/Preferences/\(bundleId).plist",
                    "\(homeDir)/Library/Caches/\(bundleId)",
                    "\(homeDir)/Library/Saved Application State/\(bundleId).savedState",
                ]

                for path in activityPaths {
                    let activityURL = URL(fileURLWithPath: path)
                    if fileManager.fileExists(atPath: activityURL.path) {
                        if let modDate = try? activityURL.resourceValues(forKeys: [
                            .contentModificationDateKey
                        ]).contentModificationDate {
                            dates.append(modDate)
                        }
                    }
                }
            }
        }

        // Return the most recent date
        return dates.max()
    }

    private func extractBundleIdentifier(from name: String) -> String? {
        // Try to extract bundle identifier pattern (com.company.app)
        if name.contains(".")
            && (name.hasPrefix("com.") || name.hasPrefix("org.") || name.hasPrefix("net."))
        {
            return name.components(separatedBy: ".plist").first?
                .components(separatedBy: ".savedState").first
        }
        return name
    }

    private func extractAppName(from bundleId: String) -> String {
        bundleId.components(separatedBy: ".").last?.capitalized ?? bundleId
    }

    private func categoryForPath(_ path: String) -> RelatedFile.FileCategory {
        if path.contains("Application Support") { return .applicationSupport }
        if path.contains("Preferences") { return .preferences }
        if path.contains("Caches") { return .caches }
        if path.contains("Logs") { return .logs }
        if path.contains("Containers") { return .containers }
        if path.contains("Saved Application State") { return .savedState }
        if path.contains("LaunchAgents") { return .launchAgents }
        if path.contains("LaunchDaemons") { return .launchDaemons }
        return .applicationSupport
    }
}
