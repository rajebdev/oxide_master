//
//  FileOperationsService.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import AppKit
import Foundation

/// Service for file system operations
class FileOperationsService {
    private let fileManager = FileManager.default

    /// Copy files or folders
    func copyItems(
        from sources: [String], to destination: String,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> [OperationResult] {
        var results: [OperationResult] = []

        // Auto-create destination folder if it doesn't exist
        if !fileManager.fileExists(atPath: destination) {
            try fileManager.createDirectory(
                atPath: destination,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        for (index, source) in sources.enumerated() {
            let sourceName = URL(fileURLWithPath: source).lastPathComponent
            let destinationPath = URL(fileURLWithPath: destination).appendingPathComponent(
                sourceName
            ).path

            progressHandler?(Double(index) / Double(sources.count), "Copying \(sourceName)...")

            do {
                // Check if destination exists
                if fileManager.fileExists(atPath: destinationPath) {
                    throw FileOperationError.fileExists(destinationPath)
                }

                try fileManager.copyItem(atPath: source, toPath: destinationPath)
                results.append(OperationResult(success: true, operation: .copy, path: source))
            } catch {
                results.append(
                    OperationResult(
                        success: false,
                        operation: .copy,
                        path: source,
                        errorMessage: error.localizedDescription
                    ))
            }
        }

        progressHandler?(1.0, "Copy complete")
        return results
    }

    /// Move files or folders
    func moveItems(
        from sources: [String], to destination: String,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> [OperationResult] {
        var results: [OperationResult] = []

        // Auto-create destination folder if it doesn't exist
        if !fileManager.fileExists(atPath: destination) {
            try fileManager.createDirectory(
                atPath: destination,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        for (index, source) in sources.enumerated() {
            let sourceName = URL(fileURLWithPath: source).lastPathComponent
            let destinationPath = URL(fileURLWithPath: destination).appendingPathComponent(
                sourceName
            ).path

            progressHandler?(Double(index) / Double(sources.count), "Moving \(sourceName)...")

            do {
                // Check if destination exists
                if fileManager.fileExists(atPath: destinationPath) {
                    throw FileOperationError.fileExists(destinationPath)
                }

                try fileManager.moveItem(atPath: source, toPath: destinationPath)
                results.append(OperationResult(success: true, operation: .move, path: source))
            } catch {
                results.append(
                    OperationResult(
                        success: false,
                        operation: .move,
                        path: source,
                        errorMessage: error.localizedDescription
                    ))
            }
        }

        progressHandler?(1.0, "Move complete")
        return results
    }

    /// Delete files or folders (move to trash)
    func deleteItems(_ paths: [String]) async throws -> [OperationResult] {
        var results: [OperationResult] = []

        for path in paths {
            do {
                let url = URL(fileURLWithPath: path)
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                results.append(OperationResult(success: true, operation: .delete, path: path))
            } catch {
                results.append(
                    OperationResult(
                        success: false,
                        operation: .delete,
                        path: path,
                        errorMessage: error.localizedDescription
                    ))
            }
        }

        return results
    }

    /// Rename a file or folder
    func renameItem(at path: String, to newName: String) async throws -> OperationResult {
        let url = URL(fileURLWithPath: path)
        let parentURL = url.deletingLastPathComponent()
        let newURL = parentURL.appendingPathComponent(newName)

        do {
            if fileManager.fileExists(atPath: newURL.path) {
                throw FileOperationError.fileExists(newURL.path)
            }

            try fileManager.moveItem(at: url, to: newURL)
            return OperationResult(success: true, operation: .rename(newName: newName), path: path)
        } catch {
            return OperationResult(
                success: false,
                operation: .rename(newName: newName),
                path: path,
                errorMessage: error.localizedDescription
            )
        }
    }

    /// Create a new directory
    func createDirectory(at path: String, withIntermediateDirectories: Bool = true) async throws {
        try fileManager.createDirectory(
            atPath: path,
            withIntermediateDirectories: withIntermediateDirectories,
            attributes: nil
        )
    }

    /// Reveal file in Finder
    func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Check if moving would cause a conflict
    func checkMoveConflict(from sources: [String], to destination: String) -> [String] {
        var conflicts: [String] = []

        for source in sources {
            let sourceName = URL(fileURLWithPath: source).lastPathComponent
            let destinationPath = URL(fileURLWithPath: destination).appendingPathComponent(
                sourceName
            ).path

            if fileManager.fileExists(atPath: destinationPath) {
                conflicts.append(sourceName)
            }
        }

        return conflicts
    }

    /// List directory contents
    func listDirectory(at path: String) async throws -> [FileInfo] {
        let url = URL(fileURLWithPath: path)

        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        )

        var fileInfos: [FileInfo] = []

        for itemURL in contents {
            do {
                let info = try FileInfo.from(url: itemURL, includeChildren: false)
                fileInfos.append(info)
            } catch {
                print("Error reading \(itemURL.path): \(error)")
            }
        }

        return fileInfos.sorted {
            // Sort folders first, then files
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory
            }
            // Within same type, sort alphabetically
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Get file or directory size
    func getSize(of path: String) async throws -> Int64 {
        return try await Task {
            try FileScanner.calculateDirectorySizeSync(at: path)
        }.value
    }

    /// Auto-create missing folders in destination that exist in source
    func syncCreateMissingFolders(source: String, destination: String) async throws -> [String] {
        var createdFolders: [String] = []

        let sourceURL = URL(fileURLWithPath: source)
        let destURL = URL(fileURLWithPath: destination)

        // Create destination if it doesn't exist
        if !fileManager.fileExists(atPath: destination) {
            try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true)
        }

        // Read source directory
        let contents = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        // Create missing folders in destination
        for itemURL in contents {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                let folderName = itemURL.lastPathComponent
                let destFolder = destURL.appendingPathComponent(folderName)

                if !fileManager.fileExists(atPath: destFolder.path) {
                    try fileManager.createDirectory(
                        at: destFolder, withIntermediateDirectories: false)
                    createdFolders.append(destFolder.path)
                }
            }
        }

        return createdFolders
    }

    /// Check for move/copy conflict
    func checkConflict(source: String, destination: String) -> MoveConflict {
        let sourceName = URL(fileURLWithPath: source).lastPathComponent
        let destPath = URL(fileURLWithPath: destination).appendingPathComponent(sourceName).path

        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: destPath, isDirectory: &isDir)

        var sourceIsDir: ObjCBool = false
        fileManager.fileExists(atPath: source, isDirectory: &sourceIsDir)

        return MoveConflict(
            exists: exists,
            isDirectory: isDir.boolValue,
            path: destPath,
            sourceIsDirectory: sourceIsDir.boolValue
        )
    }

    /// Smart move with merge support for directories
    func moveItemSmart(
        from source: String,
        to destination: String,
        replace: Bool,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> String {
        let conflict = checkConflict(source: source, destination: destination)
        let sourceName = URL(fileURLWithPath: source).lastPathComponent
        let finalDest = URL(fileURLWithPath: destination).appendingPathComponent(sourceName).path

        progressHandler?(0.0, "Preparing to move \(sourceName)...")

        // Handle conflicts
        if conflict.exists {
            switch conflict.conflictType {
            case .none:
                break
            case .fileReplace:
                if !replace {
                    throw FileOperationError.fileExists(finalDest)
                }
                // Remove existing file
                try fileManager.removeItem(atPath: finalDest)
            case .directoryMerge:
                // Merge directories
                return try await mergeDirectories(
                    from: source,
                    to: finalDest,
                    replace: replace,
                    progressHandler: progressHandler
                )
            case .typeMismatch:
                throw FileOperationError.typeMismatch
            }
        }

        // Simple move
        progressHandler?(0.5, "Moving \(sourceName)...")
        try fileManager.moveItem(atPath: source, toPath: finalDest)
        progressHandler?(1.0, "Move complete")

        return finalDest
    }

    /// Recursively merge directory contents
    private func mergeDirectories(
        from source: String,
        to destination: String,
        replace: Bool,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> String {
        let sourceURL = URL(fileURLWithPath: source)
        let destURL = URL(fileURLWithPath: destination)

        // Read source directory contents
        let contents = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        var processed = 0
        let total = contents.count

        for itemURL in contents {
            let itemName = itemURL.lastPathComponent
            let destItemPath = destURL.appendingPathComponent(itemName).path

            progressHandler?(Double(processed) / Double(total), "Merging \(itemName)...")

            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir)

            if isDir.boolValue {
                // Handle subdirectory
                if fileManager.fileExists(atPath: destItemPath) {
                    // Recursively merge
                    _ = try await mergeDirectories(
                        from: itemURL.path,
                        to: destItemPath,
                        replace: replace,
                        progressHandler: nil
                    )
                    // Remove source directory after merge
                    try? fileManager.removeItem(at: itemURL)
                } else {
                    // Just move the directory
                    try fileManager.moveItem(at: itemURL, to: URL(fileURLWithPath: destItemPath))
                }
            } else {
                // Handle file
                if fileManager.fileExists(atPath: destItemPath) {
                    if replace {
                        try fileManager.removeItem(atPath: destItemPath)
                        try fileManager.moveItem(
                            at: itemURL, to: URL(fileURLWithPath: destItemPath))
                    }
                    // If not replace, skip the file
                } else {
                    try fileManager.moveItem(at: itemURL, to: URL(fileURLWithPath: destItemPath))
                }
            }

            processed += 1
        }

        // Try to remove source directory if empty
        try? fileManager.removeItem(at: sourceURL)

        progressHandler?(1.0, "Merge complete")
        return destination
    }

    /// Copy item with merge support
    func copyItemSmart(
        from source: String,
        to destination: String,
        replace: Bool,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> String {
        let conflict = checkConflict(source: source, destination: destination)
        let sourceName = URL(fileURLWithPath: source).lastPathComponent
        let finalDest = URL(fileURLWithPath: destination).appendingPathComponent(sourceName).path

        progressHandler?(0.0, "Preparing to copy \(sourceName)...")

        // Handle conflicts
        if conflict.exists {
            switch conflict.conflictType {
            case .none:
                break
            case .fileReplace:
                if !replace {
                    throw FileOperationError.fileExists(finalDest)
                }
                try fileManager.removeItem(atPath: finalDest)
            case .directoryMerge:
                return try await copyMergeDirectories(
                    from: source,
                    to: finalDest,
                    replace: replace,
                    progressHandler: progressHandler
                )
            case .typeMismatch:
                throw FileOperationError.typeMismatch
            }
        }

        // Simple copy
        progressHandler?(0.5, "Copying \(sourceName)...")
        try fileManager.copyItem(atPath: source, toPath: finalDest)
        progressHandler?(1.0, "Copy complete")

        return finalDest
    }

    /// Recursively copy and merge directory contents
    private func copyMergeDirectories(
        from source: String,
        to destination: String,
        replace: Bool,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> String {
        let sourceURL = URL(fileURLWithPath: source)
        let destURL = URL(fileURLWithPath: destination)

        // Create destination if it doesn't exist
        if !fileManager.fileExists(atPath: destination) {
            try fileManager.createDirectory(at: destURL, withIntermediateDirectories: false)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        var processed = 0
        let total = contents.count

        for itemURL in contents {
            let itemName = itemURL.lastPathComponent
            let destItemPath = destURL.appendingPathComponent(itemName).path

            progressHandler?(Double(processed) / Double(total), "Copying \(itemName)...")

            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir)

            if isDir.boolValue {
                if fileManager.fileExists(atPath: destItemPath) {
                    _ = try await copyMergeDirectories(
                        from: itemURL.path,
                        to: destItemPath,
                        replace: replace,
                        progressHandler: nil
                    )
                } else {
                    try fileManager.copyItem(at: itemURL, to: URL(fileURLWithPath: destItemPath))
                }
            } else {
                if fileManager.fileExists(atPath: destItemPath) {
                    if replace {
                        try fileManager.removeItem(atPath: destItemPath)
                        try fileManager.copyItem(
                            at: itemURL, to: URL(fileURLWithPath: destItemPath))
                    }
                } else {
                    try fileManager.copyItem(at: itemURL, to: URL(fileURLWithPath: destItemPath))
                }
            }

            processed += 1
        }

        progressHandler?(1.0, "Copy complete")
        return destination
    }
}

/// File operation errors
enum FileOperationError: LocalizedError {
    case fileExists(String)
    case permissionDenied(String)
    case diskFull
    case typeMismatch
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .fileExists(let path):
            return "File already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .diskFull:
            return "Disk is full"
        case .typeMismatch:
            return "Cannot replace file with directory or vice versa"
        case .unknownError(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}
