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
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var history: [BackupRecord] = []
    @Published var lastBackupRecord: BackupRecord?
    
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
    
    /// Update preserve structure setting
    func updatePreserveStructure(_ preserve: Bool) {
        config.preserveStructure = preserve
        saveConfig()
    }
    
    /// Save configuration
    func saveConfig() {
        backupService.saveConfig(config)
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
            let record = try await backupService.runBackup(config: config) { [weak self] prog, message in
                Task { @MainActor in
                    self?.progress = prog
                    self?.statusMessage = message
                }
            }
            
            lastBackupRecord = record
            history = backupService.loadHistory()
            
            if record.success {
                statusMessage = "Backup complete: \(record.filesCopied) files copied (\(record.formattedSize))"
            } else {
                errorMessage = record.errorMessage ?? "Backup completed with errors"
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
