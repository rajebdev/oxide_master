//
//  FileInfo.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// Status of size calculation for progressive loading
enum SizeStatus: Codable, Hashable {
    case notCalculated
    case calculating
    case calculated
}

/// Represents a file or directory with its metadata
struct FileInfo: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let path: String
    var size: Int64  // Changed to var for progressive updates
    let modifiedDate: Date
    let isDirectory: Bool
    var children: [FileInfo]
    let fileType: FileType
    let permissions: String
    let isHidden: Bool
    let isReadOnly: Bool
    var sizeStatus: SizeStatus

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        size: Int64,
        modifiedDate: Date,
        isDirectory: Bool,
        children: [FileInfo] = [],
        fileType: FileType = .other,
        permissions: String = "---------",
        isHidden: Bool = false,
        isReadOnly: Bool = false,
        sizeStatus: SizeStatus = .calculated
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
        self.isDirectory = isDirectory
        self.children = children
        self.fileType = fileType
        self.permissions = permissions
        self.isHidden = isHidden
        self.isReadOnly = isReadOnly
        self.sizeStatus = sizeStatus
    }

    /// Create FileInfo from a file URL
    static func from(url: URL, includeChildren: Bool = false) throws -> FileInfo {
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .totalFileSizeKey,
            .isHiddenKey,
        ]

        let resourceValues = try url.resourceValues(forKeys: resourceKeys)

        let name = resourceValues.name ?? url.lastPathComponent
        let isDirectory = resourceValues.isDirectory ?? false
        let modifiedDate = resourceValues.contentModificationDate ?? Date()
        let fileType = FileType.from(url: url)

        // Get size - for directories use du command for fast calculation
        let size: Int64
        if isDirectory {
            size = calculateDirectorySize(path: url.path)
        } else {
            size = Int64(resourceValues.fileSize ?? 0)
        }

        // Get permissions and check if read-only
        let permissions: String
        var isReadOnly = false
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let posixPerms = attrs[.posixPermissions] as? NSNumber
        {
            permissions = formatPermissions(posixPerms.intValue, isDirectory: isDirectory)
            // Check if write permission is denied (owner write bit is 0)
            isReadOnly = (posixPerms.intValue & 0o200) == 0
        } else {
            permissions = isDirectory ? "d---------" : "---------"
        }

        // Check if file is hidden
        let isHidden = resourceValues.isHidden ?? name.hasPrefix(".")

        var children: [FileInfo] = []
        if includeChildren && isDirectory {
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            ) {
                for case let childURL as URL in enumerator {
                    if let childInfo = try? FileInfo.from(url: childURL, includeChildren: false) {
                        children.append(childInfo)
                    }
                }
            }
        }

        return FileInfo(
            name: name,
            path: url.path,
            size: size,
            modifiedDate: modifiedDate,
            isDirectory: isDirectory,
            children: children,
            fileType: fileType,
            permissions: permissions,
            isHidden: isHidden,
            isReadOnly: isReadOnly,
            sizeStatus: .calculated
        )
    }

    /// Calculate total size including all children
    var totalSize: Int64 {
        if sizeStatus == .notCalculated {
            return 0
        }
        if isDirectory {
            // For directories: use calculated size from du command
            // This is more accurate and works with lazy-loaded children
            if size > 0 {
                return size
            }
            // Fallback to sum of children if size not calculated yet
            return children.reduce(0) { $0 + $1.totalSize }
        }
        return size
    }

    /// Check if size is being calculated or not calculated yet
    var isLoadingSize: Bool {
        sizeStatus == .calculating || sizeStatus == .notCalculated
    }

    /// Calculate total file count including all children
    var totalFileCount: Int {
        if isDirectory {
            return 1 + children.reduce(0) { $0 + $1.totalFileCount }
        }
        return 1
    }

    /// Get formatted size string
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Get icon name for SF Symbol
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        return fileType.iconName
    }

    /// Get color for file type
    var typeColor: String {
        fileType.colorHex
    }

    /// Get text color based on file attributes
    var textColor: Color {
        if isHidden {
            return .secondary  // Gray for hidden files
        } else if isReadOnly {
            return .blue  // Blue for read-only files
        }
        return .primary  // Default color
    }
}

/// Calculate directory size using du command (fast)
func calculateDirectorySize(path: String) -> Int64 {
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
            // du output format: "size\tpath"
            let components = output.components(separatedBy: "\t")
            if let sizeStr = components.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                let sizeKB = Int64(sizeStr)
            {
                return sizeKB * 1024  // Convert KB to bytes
            }
        }
    } catch {
        // If du fails, return 0
        return 0
    }

    return 0
}

/// Format POSIX permissions to string (e.g., "drwxr-xr-x")
func formatPermissions(_ permissions: Int, isDirectory: Bool) -> String {
    var result = isDirectory ? "d" : "-"

    // Owner permissions
    result += (permissions & 0o400) != 0 ? "r" : "-"
    result += (permissions & 0o200) != 0 ? "w" : "-"
    result += (permissions & 0o100) != 0 ? "x" : "-"

    // Group permissions
    result += (permissions & 0o040) != 0 ? "r" : "-"
    result += (permissions & 0o020) != 0 ? "w" : "-"
    result += (permissions & 0o010) != 0 ? "x" : "-"

    // Other permissions
    result += (permissions & 0o004) != 0 ? "r" : "-"
    result += (permissions & 0o002) != 0 ? "w" : "-"
    result += (permissions & 0o001) != 0 ? "x" : "-"

    return result
}

/// File type categories
enum FileType: String, Codable {
    case image
    case video
    case audio
    case document
    case code
    case archive
    case executable
    case folder
    case other

    static func from(url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()

        switch ext {
        // Images
        case "jpg", "jpeg", "png", "gif", "bmp", "svg", "webp", "heic":
            return .image
        // Videos
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm":
            return .video
        // Audio
        case "mp3", "wav", "flac", "aac", "ogg", "m4a":
            return .audio
        // Documents
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf":
            return .document
        // Code
        case "swift", "js", "ts", "py", "java", "cpp", "c", "h", "rs", "go", "html", "css", "json",
            "xml":
            return .code
        // Archives
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return .archive
        // Executables
        case "app", "exe", "dmg", "pkg":
            return .executable
        default:
            return .other
        }
    }

    var iconName: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "archivebox.fill"
        case .executable: return "app.fill"
        case .folder: return "folder.fill"
        case .other: return "doc"
        }
    }

    var colorHex: String {
        switch self {
        case .image: return "#FF6B6B"
        case .video: return "#4ECDC4"
        case .audio: return "#95E1D3"
        case .document: return "#F38181"
        case .code: return "#AA96DA"
        case .archive: return "#FCBAD3"
        case .executable: return "#FFFFD2"
        case .folder: return "#A8D8EA"
        case .other: return "#D3D3D3"
        }
    }
}
