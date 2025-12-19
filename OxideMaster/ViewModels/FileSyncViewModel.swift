//
//  FileSyncViewModel.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Panel identifier for drag and drop
enum Panel {
    case left
    case right
}

/// Sort option for file list
enum SortOption {
    case name
    case size
    case dateModified
}

/// Sort order
enum SortOrder {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

/// ViewModel for File Synchronization
@MainActor
class FileSyncViewModel: ObservableObject {
    @Published var leftPanelPath: String = ""
    @Published var rightPanelPath: String = ""
    @Published var leftPanelFiles: [FileInfo] = []
    @Published var rightPanelFiles: [FileInfo] = []
    @Published var leftSelectedFiles: Set<String> = []
    @Published var rightSelectedFiles: Set<String> = []
    @Published var isLoadingLeft = false
    @Published var isLoadingRight = false
    @Published var isOperating = false
    @Published var operationProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var sessions: [SyncSession] = []
    @Published var currentSession: SyncSession?
    @Published var leftSortOption: SortOption = .name
    @Published var leftSortOrder: SortOrder = .ascending
    @Published var rightSortOption: SortOption = .name
    @Published var rightSortOrder: SortOrder = .ascending

    // Track first appearance for auto-scan
    @Published var hasPerformedInitialScan = false

    private let fileOps = FileOperationsService()
    private let sessionManager = SyncSessionManager.shared
    @Published var showSetup = true
    @Published var showConflictAlert = false
    @Published var pendingConflict: MoveConflict?
    @Published var pendingOperation: (() async -> Void)?

    init() {
        loadSessions()

        // Set default paths
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        leftPanelPath = homeURL.path
        rightPanelPath = homeURL.path
    }

    /// Load left panel
    func loadLeftPanel(path: String? = nil) async {
        if let path = path {
            leftPanelPath = path
        }

        isLoadingLeft = true
        errorMessage = nil

        do {
            leftPanelFiles = try await fileOps.listDirectory(at: leftPanelPath)
            leftPanelFiles = sortFiles(leftPanelFiles, by: leftSortOption, order: leftSortOrder)
        } catch {
            errorMessage = error.localizedDescription
            leftPanelFiles = []
        }

        isLoadingLeft = false
    }

    /// Load right panel
    func loadRightPanel(path: String? = nil) async {
        if let path = path {
            rightPanelPath = path
        }

        isLoadingRight = true
        errorMessage = nil

        do {
            rightPanelFiles = try await fileOps.listDirectory(at: rightPanelPath)
            rightPanelFiles = sortFiles(rightPanelFiles, by: rightSortOption, order: rightSortOrder)
        } catch {
            errorMessage = error.localizedDescription
            rightPanelFiles = []
        }

        isLoadingRight = false
    }

    /// Navigate left panel
    func navigateLeft(to path: String) async {
        await loadLeftPanel(path: path)
    }

    /// Navigate right panel
    func navigateRight(to path: String) async {
        await loadRightPanel(path: path)
    }

    /// Navigate both panels to the same subfolder (synchronized navigation)
    func navigateToBothPanels(subfolder: String) async {
        // Append subfolder name to both paths
        leftPanelPath =
            URL(fileURLWithPath: leftPanelPath)
            .appendingPathComponent(subfolder).path
        rightPanelPath =
            URL(fileURLWithPath: rightPanelPath)
            .appendingPathComponent(subfolder).path

        // Auto-sync missing folders FIRST before loading
        _ = try? await fileOps.syncCreateMissingFolders(
            source: leftPanelPath,
            destination: rightPanelPath
        )

        // Then load both panels
        await loadLeftPanel()
        await loadRightPanel()
    }

    /// Navigate both panels to parent directory (synchronized)
    func navigateToParentBoth() async {
        let leftParent = URL(fileURLWithPath: leftPanelPath).deletingLastPathComponent().path
        let rightParent = URL(fileURLWithPath: rightPanelPath).deletingLastPathComponent().path

        leftPanelPath = leftParent
        rightPanelPath = rightParent

        await loadLeftPanel()
        await loadRightPanel()
    }

    /// Copy from left to right with conflict detection
    func copyLeftToRight() async {
        let sources = Array(leftSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperationWithConflictCheck(
            sources: sources, destination: rightPanelPath, isCopy: true
        ) { [weak self] in
            guard let self = self else { return }
            self.leftSelectedFiles.removeAll()
            await self.loadRightPanel()
            // Auto-sync missing folders
            _ = try? await self.fileOps.syncCreateMissingFolders(
                source: self.leftPanelPath, destination: self.rightPanelPath)
        }
    }

    /// Copy from right to left with conflict detection
    func copyRightToLeft() async {
        let sources = Array(rightSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperationWithConflictCheck(
            sources: sources, destination: leftPanelPath, isCopy: true
        ) { [weak self] in
            guard let self = self else { return }
            self.rightSelectedFiles.removeAll()
            await self.loadLeftPanel()
            // Auto-sync missing folders
            _ = try? await self.fileOps.syncCreateMissingFolders(
                source: self.rightPanelPath, destination: self.leftPanelPath)
        }
    }

    /// Move from left to right with conflict detection
    func moveLeftToRight() async {
        let sources = Array(leftSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperationWithConflictCheck(
            sources: sources, destination: rightPanelPath, isCopy: false
        ) { [weak self] in
            guard let self = self else { return }
            self.leftSelectedFiles.removeAll()
            await self.loadLeftPanel()
            await self.loadRightPanel()
            // Auto-sync missing folders
            _ = try? await self.fileOps.syncCreateMissingFolders(
                source: self.leftPanelPath, destination: self.rightPanelPath)
        }
    }

    /// Move from right to left with conflict detection
    func moveRightToLeft() async {
        let sources = Array(rightSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperationWithConflictCheck(
            sources: sources, destination: leftPanelPath, isCopy: false
        ) { [weak self] in
            guard let self = self else { return }
            self.rightSelectedFiles.removeAll()
            await self.loadLeftPanel()
            await self.loadRightPanel()
            // Auto-sync missing folders
            _ = try? await self.fileOps.syncCreateMissingFolders(
                source: self.rightPanelPath, destination: self.leftPanelPath)
        }
    }

    /// Perform operation with conflict checking
    private func performOperationWithConflictCheck(
        sources: [String],
        destination: String,
        isCopy: Bool,
        completion: @escaping () async -> Void
    ) async {
        isOperating = true
        errorMessage = nil
        var hasConflicts = false

        // Check for conflicts
        for source in sources {
            let conflict = fileOps.checkConflict(source: source, destination: destination)
            if conflict.exists {
                hasConflicts = true

                // Show alert based on conflict type
                let fileName = URL(fileURLWithPath: source).lastPathComponent
                let shouldProceed: Bool

                switch conflict.conflictType {
                case .fileReplace:
                    shouldProceed = await showAlert(
                        title: "File Exists",
                        message: "\"\(fileName)\" already exists. Do you want to replace it?",
                        primaryButton: "Replace",
                        secondaryButton: "Skip"
                    )
                case .directoryMerge:
                    shouldProceed = await showAlert(
                        title: "Folder Exists",
                        message: "\"\(fileName)\" already exists. Merge contents?",
                        primaryButton: "Merge",
                        secondaryButton: "Skip"
                    )
                case .typeMismatch:
                    errorMessage = "Cannot replace file with folder or vice versa: \(fileName)"
                    isOperating = false
                    return
                case .none:
                    shouldProceed = true
                }

                if !shouldProceed {
                    continue
                }
            }

            // Perform the operation
            do {
                if isCopy {
                    _ = try await fileOps.copyItemSmart(
                        from: source,
                        to: destination,
                        replace: hasConflicts
                    ) { [weak self] prog, msg in
                        Task { @MainActor in
                            self?.operationProgress = prog
                            self?.statusMessage = msg
                        }
                    }
                } else {
                    _ = try await fileOps.moveItemSmart(
                        from: source,
                        to: destination,
                        replace: hasConflicts
                    ) { [weak self] prog, msg in
                        Task { @MainActor in
                            self?.operationProgress = prog
                            self?.statusMessage = msg
                        }
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        await completion()
        statusMessage = isCopy ? "Copy completed" : "Move completed"
        isOperating = false
    }

    /// Show alert dialog and return user's choice
    private func showAlert(
        title: String, message: String, primaryButton: String, secondaryButton: String
    ) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: primaryButton)
                alert.addButton(withTitle: secondaryButton)

                let response = alert.runModal()
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }

    /// Delete selected files in left panel
    func deleteLeftSelected() async {
        let paths = Array(leftSelectedFiles)
        guard !paths.isEmpty else { return }

        await performOperation {
            _ = try await fileOps.deleteItems(paths)
        }

        leftSelectedFiles.removeAll()
        await loadLeftPanel()
    }

    /// Delete selected files in right panel
    func deleteRightSelected() async {
        let paths = Array(rightSelectedFiles)
        guard !paths.isEmpty else { return }

        await performOperation {
            _ = try await fileOps.deleteItems(paths)
        }

        rightSelectedFiles.removeAll()
        await loadRightPanel()
    }

    /// Reveal in Finder
    func revealInFinder(_ path: String) {
        fileOps.revealInFinder(path: path)
    }

    /// Save current session
    func saveSession(name: String) {
        let session = SyncSession(
            name: name,
            leftPanelPath: leftPanelPath,
            rightPanelPath: rightPanelPath
        )

        sessionManager.addSession(session)
        sessions = sessionManager.loadSessions()
        currentSession = session
        showSetup = false
    }

    /// Load a session
    func loadSession(_ session: SyncSession) async {
        currentSession = session
        leftPanelPath = session.leftPanelPath
        rightPanelPath = session.rightPanelPath
        showSetup = false

        await loadLeftPanel()
        await loadRightPanel()

        // Auto-sync missing folders in both directions
        _ = try? await fileOps.syncCreateMissingFolders(
            source: leftPanelPath, destination: rightPanelPath)

        // Update last used date
        sessionManager.updateLastUsed(session)
        sessions = sessionManager.loadSessions()
    }

    /// Delete a session
    func deleteSession(_ session: SyncSession) {
        sessionManager.removeSession(session)
        sessions = sessionManager.loadSessions()

        if currentSession?.id == session.id {
            currentSession = nil
        }
    }

    /// Load sessions from persistence
    private func loadSessions() {
        sessions = sessionManager.loadSessions()
    }

    /// Start new session manually
    func startNewSession(leftPath: String, rightPath: String) async {
        guard leftPath != rightPath else {
            errorMessage = "Source and destination must be different"
            return
        }

        leftPanelPath = leftPath
        rightPanelPath = rightPath
        showSetup = false

        await loadLeftPanel()
        await loadRightPanel()

        // Auto-sync missing folders
        _ = try? await fileOps.syncCreateMissingFolders(
            source: leftPanelPath, destination: rightPanelPath)

        // Auto-save to history
        let session = SyncSession(
            name: "Auto-saved session",
            leftPanelPath: leftPath,
            rightPanelPath: rightPath
        )
        sessionManager.addSession(session)
        sessions = sessionManager.loadSessions()
        currentSession = session
    }

    /// Reset to setup screen
    func resetToSetup() {
        showSetup = true
        leftSelectedFiles.removeAll()
        rightSelectedFiles.removeAll()
        currentSession = nil
    }

    /// Perform an operation with error handling
    private func performOperation(_ operation: () async throws -> Void) async {
        isOperating = true
        errorMessage = nil

        do {
            try await operation()
            statusMessage = "Operation completed successfully"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Operation failed"
        }

        isOperating = false
    }

    /// Toggle selection in left panel
    func toggleLeftSelection(_ path: String) {
        if leftSelectedFiles.contains(path) {
            leftSelectedFiles.remove(path)
        } else {
            leftSelectedFiles.insert(path)
        }
    }

    /// Toggle selection in right panel
    func toggleRightSelection(_ path: String) {
        if rightSelectedFiles.contains(path) {
            rightSelectedFiles.remove(path)
        } else {
            rightSelectedFiles.insert(path)
        }
    }

    /// Select all in left panel
    func selectAllLeft() {
        leftSelectedFiles = Set(leftPanelFiles.map { $0.path })
    }

    /// Select all in right panel
    func selectAllRight() {
        rightSelectedFiles = Set(rightPanelFiles.map { $0.path })
    }

    /// Deselect all in left panel
    func deselectAllLeft() {
        leftSelectedFiles.removeAll()
    }

    /// Deselect all in right panel
    func deselectAllRight() {
        rightSelectedFiles.removeAll()
    }

    /// Handle dropped files from drag and drop (MOVE operation)
    func handleDroppedFiles(_ urls: [URL], toPanel panel: Panel) async {
        guard !urls.isEmpty else { return }

        let paths = urls.map { $0.path }
        let destinationPath = panel == .left ? leftPanelPath : rightPanelPath

        // Check if files are being dropped in their own panel (do nothing)
        let sourcePath = URL(fileURLWithPath: paths[0]).deletingLastPathComponent().path
        if sourcePath == destinationPath {
            // Same panel - cancel operation
            return
        }

        // Use move operation with conflict detection
        await performOperationWithConflictCheck(
            sources: paths, destination: destinationPath, isCopy: false
        ) { [weak self] in
            guard let self = self else { return }
            // Reload both panels since files were moved
            await self.loadLeftPanel()
            await self.loadRightPanel()
        }
    }

    /// Sort files based on selected option and order
    private func sortFiles(_ files: [FileInfo], by option: SortOption, order: SortOrder)
        -> [FileInfo]
    {
        let sorted = files.sorted { file1, file2 in
            // Always put directories first
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory
            }

            // Then sort by selected option
            let comparison: Bool
            switch option {
            case .name:
                comparison = file1.name.localizedStandardCompare(file2.name) == .orderedAscending
            case .size:
                comparison = file1.size < file2.size
            case .dateModified:
                comparison = file1.modifiedDate < file2.modifiedDate
            }

            return order == .ascending ? comparison : !comparison
        }
        return sorted
    }

    /// Change sort option for left panel
    func setSortLeft(by option: SortOption) {
        if leftSortOption == option {
            leftSortOrder.toggle()
        } else {
            leftSortOption = option
            leftSortOrder = .ascending
        }
        leftPanelFiles = sortFiles(leftPanelFiles, by: leftSortOption, order: leftSortOrder)
    }

    /// Change sort option for right panel
    func setSortRight(by option: SortOption) {
        if rightSortOption == option {
            rightSortOrder.toggle()
        } else {
            rightSortOption = option
            rightSortOrder = .ascending
        }
        rightPanelFiles = sortFiles(rightPanelFiles, by: rightSortOption, order: rightSortOrder)
    }
}
