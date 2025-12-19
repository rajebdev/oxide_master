//
//  Extensions.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// Get file extension
    var fileExtension: String {
        (self as NSString).pathExtension
    }
    
    /// Get file name without extension
    var fileNameWithoutExtension: String {
        (self as NSString).deletingPathExtension
    }
    
    /// Get last path component
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
    
    /// Get directory path
    var directoryPath: String {
        (self as NSString).deletingLastPathComponent
    }
    
    /// Append path component
    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }
}

// MARK: - Int64 Extensions

extension Int64 {
    /// Format bytes as human-readable string
    func formatAsFileSize() -> String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
    
    /// Format bytes as memory size
    func formatAsMemorySize() -> String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .memory)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Get relative time string (e.g., "2 hours ago")
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format as short date string
    func shortDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Format as date and time string
    func dateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is within the last N days
    func isWithinLast(days: Int) -> Bool {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return false
        }
        return self >= cutoffDate
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Check if path is a directory
    func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
    
    /// Get file size
    func fileSize(atPath path: String) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// Get modification date
    func modificationDate(atPath path: String) -> Date? {
        guard let attributes = try? attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Get color for file type
    static func forFileType(_ type: FileType) -> Color {
        Color(hex: type.colorHex)
    }
}

// MARK: - Array Extensions

extension Array where Element == FileInfo {
    /// Calculate total size
    var totalSize: Int64 {
        reduce(0) { $0 + $1.totalSize }
    }
    
    /// Get formatted total size
    var formattedTotalSize: String {
        totalSize.formatAsFileSize()
    }
    
    /// Filter by file type
    func filtered(by type: FileType) -> [FileInfo] {
        filter { $0.fileType == type }
    }
    
    /// Sort by name
    func sortedByName(ascending: Bool = true) -> [FileInfo] {
        sorted { first, second in
            let comparison = first.name.localizedStandardCompare(second.name)
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }
    
    /// Sort by size
    func sortedBySize(ascending: Bool = false) -> [FileInfo] {
        sorted { ascending ? $0.totalSize < $1.totalSize : $0.totalSize > $1.totalSize }
    }
    
    /// Sort by date
    func sortedByDate(ascending: Bool = false) -> [FileInfo] {
        sorted { ascending ? $0.modifiedDate < $1.modifiedDate : $0.modifiedDate > $1.modifiedDate }
    }
}

// MARK: - View Extensions

extension View {
    /// Conditionally apply a modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply corner radius
    func cornerRadius(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Binding Extensions

extension Binding where Value == String {
    /// Create binding for Int value
    func intValue() -> Binding<Int> {
        Binding<Int>(
            get: { Int(self.wrappedValue) ?? 0 },
            set: { self.wrappedValue = String($0) }
        )
    }
}
