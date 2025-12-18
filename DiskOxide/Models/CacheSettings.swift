//
//  CacheSettings.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation

/// Application cache type for macOS applications
enum ApplicationCacheType: String, Codable, CaseIterable {
    case browsers = "Web Browsers"
    case developerTools = "Developer Tools"
    case messaging = "Messaging Apps"
    case media = "Media Apps"
    case productivity = "Productivity Apps"
    case systemCache = "System Cache"

    var displayName: String {
        return rawValue
    }

    /// Get cache paths for this category
    var cachePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        switch self {
        case .browsers:
            return [
                "\(home)/Library/Caches/Google/Chrome",
                "\(home)/Library/Caches/Firefox",
                "\(home)/Library/Caches/com.apple.Safari",
                "\(home)/Library/Caches/com.microsoft.edgemac",
                "\(home)/Library/Caches/com.brave.Browser",
                "\(home)/Library/Application Support/Google/Chrome/Default/Cache",
                "\(home)/Library/Application Support/Firefox/Profiles/*/cache2",
            ]
        case .developerTools:
            return [
                "\(home)/Library/Developer/Xcode/DerivedData",
                "\(home)/Library/Caches/CocoaPods",
                "\(home)/Library/Caches/com.apple.dt.Xcode",
                "\(home)/Library/Caches/JetBrains",
                "\(home)/Library/Caches/Android Studio",
                "\(home)/Library/Application Support/Code/Cache",
                "\(home)/Library/Application Support/Code/CachedData",
            ]
        case .messaging:
            return [
                "\(home)/Library/Caches/com.tinyspeck.slackmacgap",
                "\(home)/Library/Application Support/Slack/Cache",
                "\(home)/Library/Application Support/discord/Cache",
                "\(home)/Library/Caches/com.hnc.Discord",
                "\(home)/Library/Caches/com.microsoft.teams2",
                "\(home)/Library/Application Support/Microsoft Teams/Cache",
            ]
        case .media:
            return [
                "\(home)/Library/Caches/com.spotify.client",
                "\(home)/Library/Caches/org.videolan.vlc",
                "\(home)/Library/Caches/com.apple.Music",
                "\(home)/Library/Caches/com.apple.TV",
            ]
        case .productivity:
            return [
                "\(home)/Library/Caches/com.notion.id",
                "\(home)/Library/Caches/com.adobe.*",
                "\(home)/Library/Caches/com.microsoft.Word",
                "\(home)/Library/Caches/com.microsoft.Excel",
                "\(home)/Library/Caches/com.microsoft.Powerpoint",
            ]
        case .systemCache:
            return [
                "\(home)/Library/Caches/com.apple.bird",  // iCloud
                "\(home)/Library/Logs",
                "\(home)/Library/Saved Application State",
                "/Library/Caches",
            ]
        }
    }

    /// Get bundle identifiers for apps in this category
    var bundleIdentifiers: [String] {
        switch self {
        case .browsers:
            return [
                "com.google.Chrome",
                "org.mozilla.firefox",
                "com.apple.Safari",
                "com.microsoft.edgemac",
                "com.brave.Browser",
            ]
        case .developerTools:
            return [
                "com.apple.dt.Xcode",
                "com.microsoft.VSCode",
                "com.jetbrains.intellij",
                "com.jetbrains.pycharm",
                "com.google.android.studio",
            ]
        case .messaging:
            return [
                "com.tinyspeck.slackmacgap",
                "com.hnc.Discord",
                "com.microsoft.teams2",
            ]
        case .media:
            return [
                "com.spotify.client",
                "org.videolan.vlc",
                "com.apple.Music",
            ]
        case .productivity:
            return [
                "com.notion.id",
                "com.adobe.*.photoshop",
                "com.microsoft.Word",
            ]
        case .systemCache:
            return []
        }
    }
}

/// Project cache type for safe detection
enum ProjectCacheType: String, Codable, CaseIterable {
    case nodeModules = "node_modules (Node.js)"
    case pythonCache = "__pycache__ (Python)"
    case javaTarget = "target (Java/Maven)"
    case rustTarget = "target (Rust)"
    case gradleBuild = "build (Gradle)"
    case dotNext = ".next (Next.js)"
    case coverage = "coverage"
    case dist = "dist"
    case buildOutput = "out/build"

    // New project types
    case goVendor = "vendor (Go)"
    case goModCache = "pkg/mod (Go Modules)"
    case phpVendor = "vendor (PHP/Composer)"
    case swiftBuild = ".build (Swift)"
    case derivedData = "DerivedData (Xcode)"
    case dartTool = ".dart_tool (Dart/Flutter)"
    case flutterBuild = "build (Flutter)"
    case elixirBuild = "_build (Elixir)"
    case elixirDeps = "deps (Elixir)"
    case rubyVendor = "vendor/bundle (Ruby)"
    case cargoTarget = "target (Cargo)"
    case dotnetObj = "obj (C#/.NET)"
    case dotnetBin = "bin (C#/.NET)"
    case kotlinBuild = "build (Kotlin)"
    case scalaTarget = "target (Scala)"
    case zig_cache = "zig-cache (Zig)"
    case zig_out = "zig-out (Zig)"

    var folderName: String {
        switch self {
        case .nodeModules: return "node_modules"
        case .pythonCache: return "__pycache__"
        case .javaTarget, .rustTarget, .cargoTarget, .scalaTarget: return "target"
        case .gradleBuild, .flutterBuild, .kotlinBuild: return "build"
        case .dotNext: return ".next"
        case .coverage: return "coverage"
        case .dist: return "dist"
        case .buildOutput: return "out"
        case .goVendor, .phpVendor: return "vendor"
        case .goModCache: return "pkg/mod"
        case .swiftBuild: return ".build"
        case .derivedData: return "DerivedData"
        case .dartTool: return ".dart_tool"
        case .elixirBuild: return "_build"
        case .elixirDeps: return "deps"
        case .rubyVendor: return "vendor/bundle"
        case .dotnetObj: return "obj"
        case .dotnetBin: return "bin"
        case .zig_cache: return "zig-cache"
        case .zig_out: return "zig-out"
        }
    }

    /// Validation files to check in parent directory
    var validationFiles: [String] {
        switch self {
        case .nodeModules:
            return ["package.json"]
        case .pythonCache:
            return ["*.py", "setup.py", "pyproject.toml", "requirements.txt"]
        case .javaTarget:
            return ["pom.xml", "build.gradle", "build.gradle.kts"]
        case .rustTarget, .cargoTarget:
            return ["Cargo.toml"]
        case .gradleBuild:
            return ["build.gradle", "build.gradle.kts", "settings.gradle"]
        case .dotNext:
            return ["next.config.js", "next.config.mjs", "package.json"]
        case .coverage:
            return ["package.json", ".coveragerc", "pytest.ini", "jest.config.js"]
        case .dist:
            return ["package.json", "tsconfig.json", "setup.py", "pyproject.toml"]
        case .buildOutput:
            return ["CMakeLists.txt", "Makefile"]
        case .goVendor:
            return ["go.mod", "go.sum", "Gopkg.toml", "Gopkg.lock"]
        case .goModCache:
            return ["go.mod"]
        case .phpVendor:
            return ["composer.json", "composer.lock"]
        case .swiftBuild:
            return ["Package.swift"]
        case .derivedData:
            return ["*.xcodeproj", "*.xcworkspace"]
        case .dartTool, .flutterBuild:
            return ["pubspec.yaml", "pubspec.lock"]
        case .elixirBuild, .elixirDeps:
            return ["mix.exs", "mix.lock"]
        case .rubyVendor:
            return ["Gemfile", "Gemfile.lock"]
        case .dotnetObj, .dotnetBin:
            return ["*.csproj", "*.fsproj", "*.vbproj", "*.sln"]
        case .kotlinBuild:
            return ["build.gradle.kts", "build.gradle", "settings.gradle.kts"]
        case .scalaTarget:
            return ["build.sbt", "build.sc"]
        case .zig_cache, .zig_out:
            return ["build.zig", "build.zig.zon"]
        }
    }

    var displayName: String {
        return rawValue
    }
}

/// Settings for cache cleanup
struct CacheSettings: Codable {
    var parentFolders: [String]
    var cacheFolderNames: [String]
    var ageThresholdHours: Int
    var intervalHours: Int
    var enabled: Bool
    var lastCleanupDate: Date?

    // Project cache settings
    var projectCacheEnabled: Bool
    var enabledProjectCacheTypes: [ProjectCacheType]
    var projectScanDepth: Int

    // Application cache settings
    var applicationCacheEnabled: Bool
    var enabledApplicationCacheTypes: [ApplicationCacheType]
    var scanInstalledApps: Bool  // Scan /Applications for installed apps

    // Scheduler settings
    var requireConfirmationForScheduledCleanup: Bool

    init(
        parentFolders: [String] = CacheSettings.defaultParentFolders,
        cacheFolderNames: [String] = CacheSettings.defaultCacheFolders,
        ageThresholdHours: Int = 168,  // 7 days
        intervalHours: Int = 24,
        enabled: Bool = true,
        lastCleanupDate: Date? = nil,
        projectCacheEnabled: Bool = true,
        enabledProjectCacheTypes: [ProjectCacheType] = ProjectCacheType.allCases,
        projectScanDepth: Int = 100,
        applicationCacheEnabled: Bool = true,
        enabledApplicationCacheTypes: [ApplicationCacheType] = ApplicationCacheType.allCases,
        scanInstalledApps: Bool = true,
        requireConfirmationForScheduledCleanup: Bool = true
    ) {
        self.parentFolders = parentFolders
        self.cacheFolderNames = cacheFolderNames
        self.ageThresholdHours = ageThresholdHours
        self.intervalHours = intervalHours
        self.enabled = enabled
        self.lastCleanupDate = lastCleanupDate
        self.projectCacheEnabled = projectCacheEnabled
        self.enabledProjectCacheTypes = enabledProjectCacheTypes
        self.projectScanDepth = projectScanDepth
        self.applicationCacheEnabled = applicationCacheEnabled
        self.enabledApplicationCacheTypes = enabledApplicationCacheTypes
        self.scanInstalledApps = scanInstalledApps
        self.requireConfirmationForScheduledCleanup = requireConfirmationForScheduledCleanup
    }

    static var defaultParentFolders: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches",
            "\(home)/Library/Application Support",
            "/Library/Caches",
            "/System/Library/Caches",
        ]
    }

    static var defaultCacheFolders: [String] {
        [
            "Cache",
            "Caches",
            "CachedData",
            "cached-data",
            "GPUCache",
            "DawnCache",
            "Code Cache",
            "ShaderCache",
        ]
    }

    /// Get cutoff date for filtering cache files
    var cutoffDate: Date {
        Calendar.current.date(byAdding: .hour, value: -ageThresholdHours, to: Date()) ?? Date()
    }

    /// Check if cleanup should run based on interval
    var shouldRunCleanup: Bool {
        guard enabled else { return false }
        guard let lastDate = lastCleanupDate else { return true }

        let nextCleanupDate =
            Calendar.current.date(
                byAdding: .hour,
                value: intervalHours,
                to: lastDate
            ) ?? Date()

        return Date() >= nextCleanupDate
    }
}

/// Cache category for grouping
enum CacheCategory: String, CaseIterable {
    case systemCache = "System Cache"
    case applicationCache = "Application Cache"
    case projectCache = "Project Cache"

    var icon: String {
        switch self {
        case .systemCache:
            return "gearshape.fill"
        case .applicationCache:
            return "square.stack.3d.up.fill"
        case .projectCache:
            return "folder.badge.gearshape"
        }
    }

    var color: String {
        switch self {
        case .systemCache:
            return "orange"
        case .applicationCache:
            return "blue"
        case .projectCache:
            return "purple"
        }
    }
}

/// Cache item for preview before cleanup
struct CacheItem: Identifiable, Hashable {
    let id: UUID
    let path: String
    let name: String
    let sizeBytes: Int64
    let type: String  // "System Cache", "Project Cache", etc
    let lastModified: Date?
    var isSelected: Bool

    /// Computed category based on type
    var category: CacheCategory {
        if type.starts(with: "App:") {
            return .applicationCache
        } else if type.contains("node_modules") || type.contains("target")
            || type.contains("__pycache__") || type.contains("build") || type.contains("vendor")
            || type.contains("DerivedData") || type.contains(".next") || type.contains("dist")
            || type.contains("coverage")
            || ProjectCacheType.allCases.map({ $0.rawValue }).contains(type)
        {
            return .projectCache
        } else {
            return .systemCache
        }
    }

    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        sizeBytes: Int64,
        type: String,
        lastModified: Date? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.sizeBytes = sizeBytes
        self.type = type
        self.lastModified = lastModified
        self.isSelected = isSelected
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var parentPath: String {
        (path as NSString).deletingLastPathComponent
    }

    var formattedLastModified: String {
        guard let date = lastModified else { return "Unknown" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var formattedLastModifiedFull: String {
        guard let date = lastModified else { return "Unknown" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Grouped cache items by category
struct CacheGroup: Identifiable {
    let id = UUID()
    let category: CacheCategory
    var items: [CacheItem]
    var isExpanded: Bool = true

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
}

/// Cache cleanup record
struct CleanupRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let filePath: String
    let sizeBytes: Int64
    let deletedSuccessfully: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        filePath: String,
        sizeBytes: Int64,
        deletedSuccessfully: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.filePath = filePath
        self.sizeBytes = sizeBytes
        self.deletedSuccessfully = deletedSuccessfully
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Summary of cleanup operation
struct CleanupSummary {
    let totalDeleted: Int
    let totalSizeFreed: Int64
    let duration: TimeInterval
    let records: [CleanupRecord]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeFreed, countStyle: .file)
    }

    var successRate: Double {
        guard totalDeleted > 0 else { return 0 }
        let successful = records.filter { $0.deletedSuccessfully }.count
        return Double(successful) / Double(totalDeleted)
    }
}
