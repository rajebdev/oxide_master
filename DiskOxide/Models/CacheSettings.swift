//
//  CacheSettings.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation

/// Settings for cache cleanup
struct CacheSettings: Codable {
    var parentFolders: [String]
    var cacheFolderNames: [String]
    var ageThresholdHours: Int
    var intervalHours: Int
    var enabled: Bool
    var lastCleanupDate: Date?
    
    init(
        parentFolders: [String] = CacheSettings.defaultParentFolders,
        cacheFolderNames: [String] = CacheSettings.defaultCacheFolders,
        ageThresholdHours: Int = 168, // 7 days
        intervalHours: Int = 24,
        enabled: Bool = true,
        lastCleanupDate: Date? = nil
    ) {
        self.parentFolders = parentFolders
        self.cacheFolderNames = cacheFolderNames
        self.ageThresholdHours = ageThresholdHours
        self.intervalHours = intervalHours
        self.enabled = enabled
        self.lastCleanupDate = lastCleanupDate
    }
    
    static var defaultParentFolders: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches",
            "\(home)/Library/Application Support",
            "/Library/Caches",
            "/System/Library/Caches"
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
            "ShaderCache"
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
        
        let nextCleanupDate = Calendar.current.date(
            byAdding: .hour,
            value: intervalHours,
            to: lastDate
        ) ?? Date()
        
        return Date() >= nextCleanupDate
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
