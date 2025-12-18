//
//  FileScanner.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Combine
import Foundation

/// Service for scanning directories and calculating sizes
class FileScanner {

    /// Scan a directory and return file information (SHALLOW ONLY)
    /// - Parameters:
    ///   - path: Path to scan
    ///   - shallow: Always true - only immediate children
    /// - Returns: FileInfo with immediate children
    static func scanDirectory(at path: String, shallow: Bool = true) async throws -> FileInfo {
        // Execute on background thread to avoid blocking UI
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try scanDirectorySync(at: path)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Synchronous recursive scan - load all children
    private static func scanDirectorySync(at path: String) throws -> FileInfo {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            throw FileScannerError.pathNotFound(path)
        }

        // Track inodes to avoid counting hard links multiple times
        var seenInodes = Set<UInt64>()

        return try scanDirectoryRecursive(
            url: url, fileManager: fileManager, seenInodes: &seenInodes)
    }

    /// Recursive helper to scan directory and all subdirectories
    private static func scanDirectoryRecursive(
        url: URL, fileManager: FileManager, seenInodes: inout Set<UInt64>
    ) throws
        -> FileInfo
    {
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isSymbolicLinkKey,
            .isHiddenKey,
        ]

        let resourceValues = try url.resourceValues(forKeys: resourceKeys)

        let name = resourceValues.name ?? url.lastPathComponent
        let modifiedDate = resourceValues.contentModificationDate ?? Date()
        let fileType = FileType.from(url: url)

        // Check if symlink using lstat (more reliable than resourceValues)
        var isSymlink = false
        var inode: UInt64 = 0
        var statInfo = Darwin.stat()
        var permissions: String = "---------"

        if lstat((url.path as NSString).fileSystemRepresentation, &statInfo) == 0 {
            isSymlink = (statInfo.st_mode & S_IFMT) == S_IFLNK
            inode = statInfo.st_ino

            // Get permissions directly from lstat (no extra permission request!)
            let mode = Int(statInfo.st_mode)
            permissions = formatPermissions(
                mode, isDirectory: (statInfo.st_mode & S_IFMT) == S_IFDIR)

            if isSymlink {
                print("[SYMLINK] Skipping: \(url.path)")
            }
        }

        // Only check isDirectory if not a symlink
        let isDirectory = !isSymlink && (resourceValues.isDirectory ?? false)

        var fileSize: Int64 = 0
        var children: [FileInfo] = []

        // Stop at symlinks, don't follow them
        if isSymlink {
            fileSize = 0
        } else if isDirectory {
            // Check if this directory was already scanned (hard link to directory)
            if inode > 0 && statInfo.st_nlink > 1 && seenInodes.contains(inode) {
                print("[HARD LINK DIR] Already scanned inode \(inode): \(url.path)")
                fileSize = 0
                // Don't scan children again
            } else {
                // Get all contents including hidden files (but don't follow symlinks in enumeration)
                if let contents = try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsPackageDescendants]
                ) {
                    children.reserveCapacity(contents.count)

                    // Mark this directory as seen
                    if inode > 0 && statInfo.st_nlink > 1 {
                        seenInodes.insert(inode)
                    }

                    for childURL in contents {
                        autoreleasepool {
                            do {
                                // Recursively scan subdirectories
                                let childInfo = try scanDirectoryRecursive(
                                    url: childURL, fileManager: fileManager, seenInodes: &seenInodes
                                )
                                children.append(childInfo)
                                // Don't accumulate here - totalSize computed property will handle it
                            } catch {
                                // Skip files/folders we can't read
                                print("Error reading \(childURL.path): \(error)")
                            }
                        }
                    }

                    // Sort children by size descending
                    children.sort { $0.totalSize > $1.totalSize }
                }
            }
        } else {
            // For regular files: check for hard links
            if inode > 0 && statInfo.st_nlink > 1 {
                // This is a hard link
                if seenInodes.contains(inode) {
                    print("[HARD LINK] Already counted inode \(inode): \(url.path)")
                    fileSize = 0  // Don't count size again
                } else {
                    seenInodes.insert(inode)
                    // Use allocated blocks (like Rust) - more accurate for sparse files
                    fileSize = Int64(statInfo.st_blocks) * 512
                }
            } else {
                // Regular file, not a hard link
                // Use allocated blocks (like Rust) - more accurate for sparse files
                fileSize = Int64(statInfo.st_blocks) * 512
            }
        }

        // Check if file is hidden
        let isHidden = resourceValues.isHidden ?? name.hasPrefix(".")

        // Check if file is read-only (owner write bit is 0)
        let isReadOnly = (statInfo.st_mode & S_IWUSR) == 0

        let info = FileInfo(
            name: name,
            path: url.path,
            size: fileSize,
            modifiedDate: modifiedDate,
            isDirectory: isDirectory,
            children: children,
            fileType: fileType,
            permissions: permissions,
            isHidden: isHidden,
            isReadOnly: isReadOnly
        )

        // Debug: log directories with huge sizes
        if isDirectory && info.totalSize > 100_000_000_000 {  // > 100GB
            print(
                "[DEBUG] Large directory: \(name) = \(ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file)) - children: \(children.count)"
            )
        }

        return info
    }

    /// Calculate directory size synchronously (for background use)
    static func calculateDirectorySizeSync(at path: String) throws -> Int64 {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            return 0
        }

        // Check if it's a file first
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            return attributes?[.size] as? Int64 ?? 0
        }

        // For directories, calculate total size of all contents
        var totalSize: Int64 = 0
        let url = URL(fileURLWithPath: path)

        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsPackageDescendants]
            )
        else {
            return 0
        }

        while let fileURL = enumerator.nextObject() as? URL {
            autoreleasepool {
                if let values = try? fileURL.resourceValues(forKeys: [
                    .fileSizeKey, .isDirectoryKey,
                ]),
                    let isDirectory = values.isDirectory,
                    !isDirectory
                {
                    totalSize += Int64(values.fileSize ?? 0)
                }
            }
        }

        return totalSize
    }

    /// Scan directory with progress reporting (simplified)
    static func scanWithProgress(
        at path: String,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> FileInfo {
        // Execute on background thread
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    progressHandler(0.1, "Starting scan...")
                    let info = try scanDirectorySync(at: path)
                    progressHandler(1.0, "Scan complete")
                    continuation.resume(returning: info)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// Errors that can occur during file scanning
enum FileScannerError: LocalizedError {
    case pathNotFound(String)
    case accessDenied(String)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .accessDenied(let path):
            return "Access denied: \(path)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
