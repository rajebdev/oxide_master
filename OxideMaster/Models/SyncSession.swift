//
//  SyncSession.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Foundation

/// Represents a file synchronization session
struct SyncSession: Identifiable, Codable, Equatable {
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
        return fm.fileExists(atPath: leftPanelPath) && fm.fileExists(atPath: rightPanelPath)
    }

    static func == (lhs: SyncSession, rhs: SyncSession) -> Bool {
        lhs.id == rhs.id
    }
}

/// Session persistence manager
class SyncSessionManager {
    static let shared = SyncSessionManager()
    private let maxSessions = 10

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("OxideMaster", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent("sync_history.json")
    }

    private init() {}

    /// Load sessions from disk
    func loadSessions() -> [SyncSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sessions = try decoder.decode([SyncSession].self, from: data)
            // Filter out invalid sessions and return only valid ones
            return sessions.filter { $0.isValid }
        } catch {
            print("Failed to load sync sessions: \(error)")
            return []
        }
    }

    /// Save sessions to disk
    func saveSessions(_ sessions: [SyncSession]) {
        do {
            // Filter: remove duplicates based on paths and keep only last 10
            var uniqueSessions: [SyncSession] = []
            for session in sessions {
                // Skip if paths are the same
                if session.leftPanelPath == session.rightPanelPath {
                    continue
                }
                // Skip if duplicate path combination exists
                let isDuplicate = uniqueSessions.contains { existing in
                    (existing.leftPanelPath == session.leftPanelPath
                        && existing.rightPanelPath == session.rightPanelPath)
                        || (existing.leftPanelPath == session.rightPanelPath
                            && existing.rightPanelPath == session.leftPanelPath)
                }
                if !isDuplicate {
                    uniqueSessions.append(session)
                }
            }

            // Keep only last 10 sessions
            let sessionsToSave = Array(uniqueSessions.prefix(maxSessions))

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessionsToSave)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save sync sessions: \(error)")
        }
    }

    /// Add a new session to history
    func addSession(_ session: SyncSession) {
        var sessions = loadSessions()
        // Remove any existing session with same ID
        sessions.removeAll { $0.id == session.id }
        // Add new session at the beginning
        sessions.insert(session, at: 0)
        saveSessions(sessions)
    }

    /// Remove a session
    func removeSession(_ session: SyncSession) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == session.id }
        saveSessions(sessions)
    }

    /// Update session's last used date
    func updateLastUsed(_ session: SyncSession) {
        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].lastUsedDate = Date()
            // Move to front
            let updated = sessions.remove(at: index)
            sessions.insert(updated, at: 0)
            saveSessions(sessions)
        }
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

/// Conflict information for move/copy operations
struct MoveConflict {
    let exists: Bool
    let isDirectory: Bool
    let path: String
    let sourceIsDirectory: Bool

    var canMerge: Bool {
        exists && isDirectory && sourceIsDirectory
    }

    var conflictType: ConflictType {
        if !exists {
            return .none
        }
        if isDirectory && sourceIsDirectory {
            return .directoryMerge
        }
        if !isDirectory && !sourceIsDirectory {
            return .fileReplace
        }
        return .typeMismatch
    }
}

enum ConflictType {
    case none
    case fileReplace
    case directoryMerge
    case typeMismatch

    var description: String {
        switch self {
        case .none:
            return "No conflict"
        case .fileReplace:
            return "File already exists"
        case .directoryMerge:
            return "Directory already exists - will merge"
        case .typeMismatch:
            return "Cannot replace file with directory or vice versa"
        }
    }
}
