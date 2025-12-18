//
//  SyncSession.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation

/// Represents a file synchronization session
struct SyncSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var leftPanelPath: String
    var rightPanelPath: String
    var createdDate: Date
    var lastUsedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        leftPanelPath: String,
        rightPanelPath: String,
        createdDate: Date = Date(),
        lastUsedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.leftPanelPath = leftPanelPath
        self.rightPanelPath = rightPanelPath
        self.createdDate = createdDate
        self.lastUsedDate = lastUsedDate
    }
    
    /// Check if session is valid (both paths exist)
    var isValid: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: leftPanelPath) &&
               fm.fileExists(atPath: rightPanelPath)
    }
}

/// File operation type for sync panel
enum FileOperation {
    case copy
    case move
    case delete
    case rename(newName: String)
}

/// Represents a pending file operation
struct PendingOperation: Identifiable {
    let id: UUID = UUID()
    let operation: FileOperation
    let sourcePath: String
    let destinationPath: String?
    let fileInfo: FileInfo
    
    var description: String {
        switch operation {
        case .copy:
            return "Copy \(fileInfo.name) to \(destinationPath ?? "")"
        case .move:
            return "Move \(fileInfo.name) to \(destinationPath ?? "")"
        case .delete:
            return "Delete \(fileInfo.name)"
        case .rename(let newName):
            return "Rename \(fileInfo.name) to \(newName)"
        }
    }
    
    var icon: String {
        switch operation {
        case .copy: return "doc.on.doc"
        case .move: return "arrow.right.doc.on.clipboard"
        case .delete: return "trash"
        case .rename: return "pencil"
        }
    }
}

/// Result of a file operation
struct OperationResult {
    let success: Bool
    let operation: FileOperation
    let path: String
    let errorMessage: String?
    
    init(success: Bool, operation: FileOperation, path: String, errorMessage: String? = nil) {
        self.success = success
        self.operation = operation
        self.path = path
        self.errorMessage = errorMessage
    }
}
