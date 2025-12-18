//
//  FileOperationsService.swift
//  DiskOxide
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
            options: [.skipsHiddenFiles]
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

        return fileInfos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Get file or directory size
    func getSize(of path: String) async throws -> Int64 {
        return try await Task {
            try FileScanner.calculateDirectorySizeSync(at: path)
        }.value
    }
}

/// File operation errors
enum FileOperationError: LocalizedError {
    case fileExists(String)
    case permissionDenied(String)
    case diskFull
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .fileExists(let path):
            return "File already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .diskFull:
            return "Disk is full"
        case .unknownError(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}
