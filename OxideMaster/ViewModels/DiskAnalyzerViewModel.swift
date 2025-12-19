//
//  DiskAnalyzerViewModel.swift
//  OxideMaster
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
    @Published var calculatedItemsCount: Int = 0
    @Published var totalItemsCount: Int = 0

    // Track first appearance for auto-scan
    @Published var hasPerformedInitialScan = false

    private let fileScanner = FileScanner.self
    private let fileOps = FileOperationsService()

    // Persisted last scan directory
    private let lastScanDirKey = "lastScanDirectory"

    var lastScanDirectory: String {
        get {
            UserDefaults.standard.string(forKey: lastScanDirKey)
                ?? FileManager.default.homeDirectoryForCurrentUser.path
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastScanDirKey)
        }
    }

    enum SortOrder {
        case name, size, date
    }

    enum ViewMode {
        case list, tree, treeMap
    }

    /// Perform initial auto-scan on first appearance
    func performInitialScanIfNeeded() async {
        guard !hasPerformedInitialScan else { return }
        hasPerformedInitialScan = true

        // Use last scan directory or home directory
        let pathToScan = lastScanDirectory
        await scanDirectory(path: pathToScan)
    }

    /// Scan directory with progressive loading
    func scanDirectory(path: String) async {
        guard !isScanning else { return }

        isScanning = true
        errorMessage = nil
        currentPath = path
        lastScanDirectory = path  // Save last scanned directory
        scanProgress = 0.0
        calculatedItemsCount = 0
        scanMessage = "Loading structure..."

        do {
            // Phase 1: Quick structure scan (INSTANT)
            let info = try await fileScanner.quickStructureScan(at: path)

            rootFileInfo = info
            displayedFiles = info.children
            totalItemsCount = countAllItems(in: info)
            sortFiles()

            scanMessage = "Structure loaded. Calculating sizes concurrently..."

            // Phase 2: Progressive CONCURRENT size calculation (much faster!)
            try await fileScanner.progressiveSizeCalculation(root: info) {
                [weak self] updatedFile in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Update the file info in the tree
                    if var root = self.rootFileInfo {
                        self.updateFileInfoInTree(&root, with: updatedFile)
                        // Re-sort tree after size update
                        self.sortTreeRecursive(&root)
                        self.rootFileInfo = root

                        // Update displayed files if needed
                        if self.currentPath == path {
                            self.displayedFiles = root.children
                            self.sortFiles()
                        }
                    }

                    // Update progress
                    if updatedFile.sizeStatus == .calculated {
                        self.calculatedItemsCount += 1
                        self.scanProgress =
                            Double(self.calculatedItemsCount) / Double(max(self.totalItemsCount, 1))
                        self.scanMessage =
                            "Calculated \\(self.calculatedItemsCount)/\\(self.totalItemsCount) items (concurrent)"
                    }
                }
            }

            scanMessage = "Scan complete!"
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }

    /// Count all items in tree (for progress tracking)
    private func countAllItems(in file: FileInfo) -> Int {
        var count = 1
        for child in file.children {
            count += countAllItems(in: child)
        }
        return count
    }

    /// Update file info in tree structure
    private func updateFileInfoInTree(_ current: inout FileInfo, with updated: FileInfo) {
        if current.path == updated.path {
            // Update size and status
            current.size = updated.size
            current.sizeStatus = updated.sizeStatus
        } else {
            // Recursively search in children
            for i in 0..<current.children.count {
                updateFileInfoInTree(&current.children[i], with: updated)
            }
        }
    }

    /// Lazy load children when folder is expanded
    func loadChildren(for file: FileInfo) async {
        guard file.isDirectory else { return }
        guard file.children.isEmpty else { return }  // Already loaded

        do {
            // Quick scan just this folder's immediate children
            let info = try await fileScanner.quickStructureScan(at: file.path)

            // Update the file info with children in the tree
            if var updatedRoot = rootFileInfo {
                updateChildrenInTree(&updatedRoot, for: file.path, children: info.children)
                rootFileInfo = updatedRoot

                // Update displayed files if we're viewing this directory
                if currentPath == file.path {
                    displayedFiles = info.children
                    sortFiles()
                }

                // Start calculating sizes for new children CONCURRENTLY
                // Use batchConcurrentCalculation to calculate all children at once
                await fileScanner.batchConcurrentCalculation(
                    files: info.children, maxConcurrency: 20
                ) {
                    [weak self] updatedFile in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if var root = self.rootFileInfo {
                            self.updateFileInfoInTree(&root, with: updatedFile)
                            // Re-sort tree after each size calculation
                            self.sortTreeRecursive(&root)
                            self.rootFileInfo = root

                            // Update displayed files if needed
                            if self.currentPath == file.path {
                                self.displayedFiles = root.children
                                self.sortFiles()
                            }
                        }
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Update children for a specific path in tree
    private func updateChildrenInTree(
        _ current: inout FileInfo, for path: String, children: [FileInfo]
    ) {
        if current.path == path {
            current.children = children
        } else {
            for i in 0..<current.children.count {
                updateChildrenInTree(&current.children[i], for: path, children: children)
            }
        }
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

    /// Recursively sort all children in tree by size (largest first)
    private func sortTreeRecursive(_ file: inout FileInfo) {
        // Sort children by size descending
        file.children.sort { $0.totalSize > $1.totalSize }

        // Recursively sort grandchildren
        for i in 0..<file.children.count {
            sortTreeRecursive(&file.children[i])
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
