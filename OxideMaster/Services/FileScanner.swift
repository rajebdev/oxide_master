//
//  FileScanner.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Combine
import Foundation

/// Simple async semaphore for limiting concurrency
actor AsyncSemaphore {
    private var count: Int
    private let maxCount: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(count: Int) {
        self.count = count
        self.maxCount = count
    }

    func wait() async {
        count -= 1
        if count >= 0 {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        count += 1
        if !waiters.isEmpty && count <= 0 {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

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

    // MARK: - Progressive Scanning

    /// Get quick item info WITHOUT children (non-recursive)
    private static func quickItemInfo(at path: String) throws -> FileInfo {
        let url = URL(fileURLWithPath: path)

        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .contentModificationDateKey,
            .isSymbolicLinkKey,
            .isHiddenKey,
        ]

        let resourceValues = try url.resourceValues(forKeys: resourceKeys)
        let name = resourceValues.name ?? url.lastPathComponent
        let modifiedDate = resourceValues.contentModificationDate ?? Date()
        let fileType = FileType.from(url: url)

        // Get stat info
        var isSymlink = false
        var statInfo = Darwin.stat()
        var permissions: String = "---------"

        if lstat((url.path as NSString).fileSystemRepresentation, &statInfo) == 0 {
            isSymlink = (statInfo.st_mode & S_IFMT) == S_IFLNK
            let mode = Int(statInfo.st_mode)
            permissions = formatPermissions(
                mode, isDirectory: (statInfo.st_mode & S_IFMT) == S_IFDIR)
        }

        let isDirectory = !isSymlink && (resourceValues.isDirectory ?? false)
        let isHidden = resourceValues.isHidden ?? name.hasPrefix(".")
        let isReadOnly = (statInfo.st_mode & S_IWUSR) == 0

        return FileInfo(
            name: name,
            path: url.path,
            size: 0,
            modifiedDate: modifiedDate,
            isDirectory: isDirectory,
            children: [],  // NO CHILDREN - will be loaded on demand
            fileType: fileType,
            permissions: permissions,
            isHidden: isHidden,
            isReadOnly: isReadOnly,
            sizeStatus: isDirectory ? .notCalculated : .notCalculated
        )
    }

    /// Quick scan: Get directory structure without calculating sizes (INSTANT)
    static func quickStructureScan(at path: String) async throws -> FileInfo {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try quickStructureScanSync(at: path)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Synchronous quick structure scan - ONLY IMMEDIATE CHILDREN (not recursive!)
    private static func quickStructureScanSync(at path: String) throws -> FileInfo {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            throw FileScannerError.pathNotFound(path)
        }

        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .contentModificationDateKey,
            .isSymbolicLinkKey,
            .isHiddenKey,
        ]

        let resourceValues = try url.resourceValues(forKeys: resourceKeys)
        let name = resourceValues.name ?? url.lastPathComponent
        let modifiedDate = resourceValues.contentModificationDate ?? Date()
        let fileType = FileType.from(url: url)

        // Get stat info
        var isSymlink = false
        var statInfo = Darwin.stat()
        var permissions: String = "---------"

        if lstat((url.path as NSString).fileSystemRepresentation, &statInfo) == 0 {
            isSymlink = (statInfo.st_mode & S_IFMT) == S_IFLNK
            let mode = Int(statInfo.st_mode)
            permissions = formatPermissions(
                mode, isDirectory: (statInfo.st_mode & S_IFMT) == S_IFDIR)
        }

        let isDirectory = !isSymlink && (resourceValues.isDirectory ?? false)
        let isHidden = resourceValues.isHidden ?? name.hasPrefix(".")
        let isReadOnly = (statInfo.st_mode & S_IWUSR) == 0

        var children: [FileInfo] = []

        // For directories, get immediate children ONLY - NO NESTED CHILDREN
        // This keeps the scan fast and non-blocking!
        if isDirectory && !isSymlink {
            if let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants]
            ) {
                children.reserveCapacity(contents.count)

                for childURL in contents {
                    autoreleasepool {
                        do {
                            // Get child info WITHOUT scanning its children
                            let childInfo = try quickItemInfo(at: childURL.path)
                            children.append(childInfo)
                        } catch {
                            print("Error reading \(childURL.path): \(error)")
                        }
                    }
                }
            }
        }

        return FileInfo(
            name: name,
            path: url.path,
            size: 0,  // Size will be calculated later
            modifiedDate: modifiedDate,
            isDirectory: isDirectory,
            children: children,
            fileType: fileType,
            permissions: permissions,
            isHidden: isHidden,
            isReadOnly: isReadOnly,
            sizeStatus: isDirectory ? .notCalculated : .notCalculated
        )
    }

    /// Calculate size using du command (FAST for directories)
    static func calculateSizeWithDU(at path: String) async throws -> Int64 {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
                process.arguments = ["-sk", path]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // du -sk returns "<size in KB>\t<path>"
                        let parts = output.split(separator: "\t")
                        if let sizeKB = parts.first,
                            let size = Int64(sizeKB.trimmingCharacters(in: .whitespaces))
                        {
                            continuation.resume(returning: size * 1024)  // Convert KB to bytes
                            return
                        }
                    }
                    continuation.resume(returning: 0)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Calculate size for file using stat (FAST for regular files)
    static func calculateFileSize(at path: String) -> Int64 {
        var statInfo = Darwin.stat()
        if stat((path as NSString).fileSystemRepresentation, &statInfo) == 0 {
            // Check if it's a symlink
            if (statInfo.st_mode & S_IFMT) == S_IFLNK {
                return 0
            }
            // Use allocated blocks for accuracy
            return Int64(statInfo.st_blocks) * 512
        }
        return 0
    }

    /// Progressive size calculation - emits updates as each item is calculated (CONCURRENT)
    static func progressiveSizeCalculation(
        root: FileInfo,
        progressHandler: @escaping @Sendable (FileInfo) -> Void,
        maxConcurrency: Int = 20
    ) async throws {
        // Create semaphore to limit concurrent du processes
        let semaphore = AsyncSemaphore(count: maxConcurrency)

        // Calculate size for root and all children concurrently
        await calculateSizeConcurrent(
            file: root, progressHandler: progressHandler, semaphore: semaphore)
    }

    /// Concurrent size calculation with progress updates (using semaphore for concurrency limit)
    private static func calculateSizeConcurrent(
        file: FileInfo,
        progressHandler: @escaping @Sendable (FileInfo) -> Void,
        semaphore: AsyncSemaphore
    ) async {
        var updatedFile = file

        // Mark as calculating
        updatedFile.sizeStatus = .calculating
        progressHandler(updatedFile)

        // Calculate size based on type
        if file.isDirectory {
            // Acquire semaphore to limit concurrency
            await semaphore.wait()

            // Use du for directories (fast!)
            if let size = try? await calculateSizeWithDU(at: file.path) {
                updatedFile.size = size
                updatedFile.sizeStatus = .calculated
                progressHandler(updatedFile)
            } else {
                updatedFile.sizeStatus = .calculated
                progressHandler(updatedFile)
            }

            // Release semaphore after du finishes
            await semaphore.signal()

            // Calculate children sizes CONCURRENTLY using TaskGroup
            await withTaskGroup(of: Void.self) { group in
                for child in file.children {
                    group.addTask {
                        await calculateSizeConcurrent(
                            file: child,
                            progressHandler: progressHandler,
                            semaphore: semaphore
                        )
                    }
                }
            }
        } else {
            // Regular file - use stat (instant, no need for semaphore!)
            let size = calculateFileSize(at: file.path)
            updatedFile.size = size
            updatedFile.sizeStatus = .calculated
            progressHandler(updatedFile)
        }
    }

    /// Batch concurrent calculation for multiple files (for lazy-loaded children)
    static func batchConcurrentCalculation(
        files: [FileInfo],
        maxConcurrency: Int = 20,
        progressHandler: @escaping @Sendable (FileInfo) -> Void
    ) async {
        // Create semaphore to limit concurrent du processes
        let semaphore = AsyncSemaphore(count: maxConcurrency)

        // Calculate all files concurrently
        await withTaskGroup(of: Void.self) { group in
            for file in files {
                group.addTask {
                    await calculateSizeConcurrent(
                        file: file,
                        progressHandler: progressHandler,
                        semaphore: semaphore
                    )
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
