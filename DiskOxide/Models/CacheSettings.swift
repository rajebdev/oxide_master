//
//  CacheSettings.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation

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

/// Cache item for preview before cleanup
struct CacheItem: Identifiable, Hashable {
    let id: UUID
    let path: String
    let name: String
    let sizeBytes: Int64
    let type: String  // "System Cache", "Project Cache", etc
    let lastModified: Date?
    var isSelected: Bool

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
