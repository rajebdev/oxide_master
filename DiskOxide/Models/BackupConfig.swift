//
//  BackupConfig.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation

/// Configuration for backup operations
struct BackupConfig: Codable {
    var sourcePath: String
    var destinationPath: String
    var ageFilterDays: Int
    var lastBackupDate: Date?
    var preserveStructure: Bool
    
    init(
        sourcePath: String = "",
        destinationPath: String = "",
        ageFilterDays: Int = 7,
        lastBackupDate: Date? = nil,
        preserveStructure: Bool = true
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.ageFilterDays = ageFilterDays
        self.lastBackupDate = lastBackupDate
        self.preserveStructure = preserveStructure
    }
    
    /// Check if configuration is valid
    var isValid: Bool {
        !sourcePath.isEmpty &&
        !destinationPath.isEmpty &&
        ageFilterDays > 0
    }
    
    /// Get cutoff date for filtering files
    var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -ageFilterDays, to: Date()) ?? Date()
    }
}

/// Backup history record
struct BackupRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let sourcePath: String
    let destinationPath: String
    let filesCopied: Int
    let totalSize: Int64
    let duration: TimeInterval
    let success: Bool
    let errorMessage: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sourcePath: String,
        destinationPath: String,
        filesCopied: Int,
        totalSize: Int64,
        duration: TimeInterval,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.filesCopied = filesCopied
        self.totalSize = totalSize
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedDuration: String {
        String(format: "%.1f seconds", duration)
    }
    
    var statusIcon: String {
        success ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}
