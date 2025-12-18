//
//  DiskAnalyzerViewModel.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// ViewModel for Disk Analyzer
@MainActor
class DiskAnalyzerViewModel: ObservableObject {
    @Published var currentPath: String = ""
    @Published var rootFileInfo: FileInfo?
    @Published var displayedFiles: [FileInfo] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanMessage: String = ""
    @Published var errorMessage: String?
    @Published var sortOrder: SortOrder = .name
    @Published var viewMode: ViewMode = .tree
    @Published var selectedFiles: Set<String> = []

    private let fileScanner = FileScanner.self
    private let fileOps = FileOperationsService()

    enum SortOrder {
        case name, size, date
    }

    enum ViewMode {
        case list, tree, treeMap
    }

    /// Scan directory
    func scanDirectory(path: String) async {
        guard !isScanning else { return }

        isScanning = true
        errorMessage = nil
        currentPath = path
        scanProgress = 0.0

        do {
            let info = try await fileScanner.scanWithProgress(at: path) {
                [weak self] progress, message in
                Task { @MainActor in
                    self?.scanProgress = progress
                    self?.scanMessage = message
                }
            }

            rootFileInfo = info
            displayedFiles = info.children
            sortFiles()
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }

    /// Scan children of a directory
    func scanChildren(of file: FileInfo) async {
        guard file.isDirectory else { return }

        do {
            let info = try await fileScanner.scanDirectory(at: file.path, shallow: true)

            // Update the file info with children
            if var updatedRoot = rootFileInfo {
                updateFileInfo(&updatedRoot, with: info)
                rootFileInfo = updatedRoot

                // If we're viewing this directory, update displayed files
                if currentPath == file.path {
                    displayedFiles = info.children
                    sortFiles()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Navigate into a directory
    func navigateToDirectory(_ path: String) async {
        await scanDirectory(path: path)
    }

    /// Go up one directory level
    func navigateUp() async {
        let url = URL(fileURLWithPath: currentPath)
        let parentPath = url.deletingLastPathComponent().path

        if parentPath != currentPath {
            await scanDirectory(path: parentPath)
        }
    }

    /// Delete selected files
    func deleteSelectedFiles() async {
        let pathsToDelete = Array(selectedFiles)

        do {
            let results = try await fileOps.deleteItems(pathsToDelete)

            // Remove deleted files from display
            displayedFiles.removeAll { selectedFiles.contains($0.path) }
            selectedFiles.removeAll()

            // Show results
            let successCount = results.filter { $0.success }.count
            scanMessage = "Deleted \(successCount) of \(pathsToDelete.count) items"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a single file
    func deleteFile(_ path: String) async {
        do {
            _ = try await fileOps.deleteItems([path])

            // Remove from display
            displayedFiles.removeAll { $0.path == path }
            selectedFiles.remove(path)

            scanMessage = "File moved to trash"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reveal file in Finder
    func revealInFinder(_ path: String) {
        fileOps.revealInFinder(path: path)
    }

    /// Sort files based on current sort order
    func sortFiles() {
        switch sortOrder {
        case .name:
            displayedFiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            displayedFiles.sort { $0.totalSize > $1.totalSize }
        case .date:
            displayedFiles.sort { $0.modifiedDate > $1.modifiedDate }
        }
    }

    /// Update sort order and re-sort
    func changeSortOrder(to newOrder: SortOrder) {
        sortOrder = newOrder
        sortFiles()
    }

    /// Select/deselect file
    func toggleSelection(for path: String) {
        if selectedFiles.contains(path) {
            selectedFiles.remove(path)
        } else {
            selectedFiles.insert(path)
        }
    }

    /// Select all files
    func selectAll() {
        selectedFiles = Set(displayedFiles.map { $0.path })
    }

    /// Deselect all files
    func deselectAll() {
        selectedFiles.removeAll()
    }

    /// Get total size of displayed files
    var totalSize: Int64 {
        displayedFiles.reduce(0) { $0 + $1.totalSize }
    }

    /// Get formatted total size
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Get file count
    var fileCount: Int {
        displayedFiles.count
    }

    // Helper to update nested file info
    private func updateFileInfo(_ current: inout FileInfo, with updated: FileInfo) {
        if current.path == updated.path {
            current.children = updated.children
        } else {
            for i in 0..<current.children.count {
                updateFileInfo(&current.children[i], with: updated)
            }
        }
    }
}
