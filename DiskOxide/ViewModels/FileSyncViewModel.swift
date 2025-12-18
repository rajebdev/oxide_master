//
//  FileSyncViewModel.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

    private let fileOps = FileOperationsService()
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "syncSessions"

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

    /// Copy from left to right
    func copyLeftToRight() async {
        let sources = Array(leftSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperation {
            _ = try await fileOps.copyItems(from: sources, to: rightPanelPath) {
                [weak self] prog, msg in
                Task { @MainActor in
                    self?.operationProgress = prog
                    self?.statusMessage = msg
                }
            }
        }

        leftSelectedFiles.removeAll()
        await loadRightPanel()
    }

    /// Copy from right to left
    func copyRightToLeft() async {
        let sources = Array(rightSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperation {
            _ = try await fileOps.copyItems(from: sources, to: leftPanelPath) {
                [weak self] prog, msg in
                Task { @MainActor in
                    self?.operationProgress = prog
                    self?.statusMessage = msg
                }
            }
        }

        rightSelectedFiles.removeAll()
        await loadLeftPanel()
    }

    /// Move from left to right
    func moveLeftToRight() async {
        let sources = Array(leftSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperation {
            _ = try await fileOps.moveItems(from: sources, to: rightPanelPath) {
                [weak self] prog, msg in
                Task { @MainActor in
                    self?.operationProgress = prog
                    self?.statusMessage = msg
                }
            }
        }

        leftSelectedFiles.removeAll()
        await loadLeftPanel()
        await loadRightPanel()
    }

    /// Move from right to left
    func moveRightToLeft() async {
        let sources = Array(rightSelectedFiles)
        guard !sources.isEmpty else { return }

        await performOperation {
            _ = try await fileOps.moveItems(from: sources, to: leftPanelPath) {
                [weak self] prog, msg in
                Task { @MainActor in
                    self?.operationProgress = prog
                    self?.statusMessage = msg
                }
            }
        }

        rightSelectedFiles.removeAll()
        await loadLeftPanel()
        await loadRightPanel()
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

        sessions.append(session)
        currentSession = session
        saveSessions()
    }

    /// Load a session
    func loadSession(_ session: SyncSession) async {
        currentSession = session
        leftPanelPath = session.leftPanelPath
        rightPanelPath = session.rightPanelPath

        await loadLeftPanel()
        await loadRightPanel()

        // Update last used date
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].lastUsedDate = Date()
            saveSessions()
        }
    }

    /// Delete a session
    func deleteSession(_ session: SyncSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()

        if currentSession?.id == session.id {
            currentSession = nil
        }
    }

    /// Load sessions from UserDefaults
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey),
            let decoded = try? JSONDecoder().decode([SyncSession].self, from: data)
        else {
            return
        }
        sessions = decoded
    }

    /// Save sessions to UserDefaults
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: sessionsKey)
        }
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
}
