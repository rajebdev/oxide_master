//
//  BackupManagerViewModel.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// ViewModel for Backup Manager
@MainActor
class BackupManagerViewModel: ObservableObject {
    @Published var config: BackupConfig
    @Published var isRunning = false
    @Published var isScanning = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var history: [BackupRecord] = []
    @Published var lastBackupRecord: BackupRecord?
    @Published var previewResult: BackupPreviewResult?

    private let backupService = BackupService()

    init() {
        self.config = backupService.loadConfig()
        self.history = backupService.loadHistory()
    }

    /// Update source path
    func updateSourcePath(_ path: String) {
        config.sourcePath = path
        saveConfig()
    }

    /// Update destination path
    func updateDestinationPath(_ path: String) {
        config.destinationPath = path
        saveConfig()
    }

    /// Update age filter
    func updateAgeFilter(_ days: Int) {
        config.ageFilterDays = max(1, days)
        saveConfig()
    }

    /// Save configuration
    func saveConfig() {
        backupService.saveConfig(config)
    }

    /// Scan and preview files to be moved
    func scanPreview() async {
        guard config.isValid else {
            errorMessage = "Invalid configuration. Please set source and destination paths."
            return
        }

        guard !isScanning && !isRunning else { return }

        isScanning = true
        errorMessage = nil
        previewResult = nil
        progress = 0.0
        statusMessage = "Scanning..."

        do {
            let result = try await backupService.scanPreview(config: config) {
                [weak self] prog, message in
                Task { @MainActor in
                    self?.progress = prog
                    self?.statusMessage = message
                }
            }

            previewResult = result
            statusMessage = "Scan complete"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Scan failed"
        }

        isScanning = false
    }

    /// Run backup
    func runBackup() async {
        guard config.isValid else {
            errorMessage = "Invalid configuration. Please set source and destination paths."
            return
        }

        guard !isRunning else { return }

        isRunning = true
        errorMessage = nil
        progress = 0.0

        do {
            let record = try await backupService.runBackup(
                config: config, previewResult: previewResult
            ) {
                [weak self] prog, message in
                Task { @MainActor in
                    self?.progress = prog
                    self?.statusMessage = message
                }
            }

            lastBackupRecord = record
            history = backupService.loadHistory()
            previewResult = nil  // Clear preview after successful move

            if record.success {
                let repoInfo = record.reposMoved > 0 ? " and \(record.reposMoved) repos" : ""
                statusMessage =
                    "Move complete: \(record.filesMoved) files\(repoInfo) moved (\(record.formattedSize))"
            } else {
                errorMessage = record.errorMessage ?? "Move completed with errors"
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Backup failed"
        }

        isRunning = false
    }

    /// Reload history
    func reloadHistory() {
        history = backupService.loadHistory()
    }

    /// Clear history
    func clearHistory() {
        backupService.clearHistory()
        history = []
    }

    /// Get formatted cutoff date
    var formattedCutoffDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: config.cutoffDate)
    }

    /// Get formatted last backup date
    var formattedLastBackupDate: String? {
        guard let date = config.lastBackupDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Check if configuration is valid
    var isConfigValid: Bool {
        config.isValid
    }
}
