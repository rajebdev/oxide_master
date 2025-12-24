//
//  BackupManagerViewModel.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// ViewModel for Backup Manager
@MainActor
class BackupManagerViewModel: ObservableObject {
    @Published var config: BackupConfig
    @Published var configs: [BackupConfig] = []
    @Published var isRunning = false
    @Published var isScanning = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var history: [BackupRecord] = []
    @Published var lastBackupRecord: BackupRecord?
    @Published var previewResult: BackupPreviewResult?
    @Published var showConfigSelector = false

    // Track first appearance for auto-scan
    @Published var hasPerformedInitialScan = false

    private let backupService = BackupService()

    init() {
        self.configs = backupService.loadConfigs()
        self.config = backupService.loadConfig()
        self.history = backupService.loadHistory()

        // If no configs exist, create default one
        if configs.isEmpty {
            self.config = BackupConfig()
            configs.append(config)
            backupService.saveConfig(config)
        }
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

    /// Update config name
    func updateConfigName(_ name: String) {
        config.name = name
        saveConfig()
    }

    /// Save configuration
    func saveConfig() {
        backupService.saveConfig(config)
        configs = backupService.loadConfigs()
    }

    /// Load a specific configuration
    func loadConfig(_ selectedConfig: BackupConfig) {
        config = selectedConfig
        backupService.setLastUsedConfig(selectedConfig.id)
        configs = backupService.loadConfigs()
        showConfigSelector = false

        // Clear preview when switching configs
        previewResult = nil
        errorMessage = nil
        statusMessage = ""
    }

    /// Create a new configuration
    func createNewConfig(name: String) {
        let newConfig = BackupConfig(name: name)
        config = newConfig
        backupService.addConfig(newConfig)
        configs = backupService.loadConfigs()
        showConfigSelector = false
    }

    /// Delete a configuration
    func deleteConfig(_ configToDelete: BackupConfig) {
        backupService.deleteConfig(configToDelete)
        configs = backupService.loadConfigs()

        // If deleted current config, load first available or create new
        if config.id == configToDelete.id {
            if let firstConfig = configs.first {
                config = firstConfig
            } else {
                config = BackupConfig()
                configs.append(config)
                backupService.saveConfig(config)
            }
        }
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
