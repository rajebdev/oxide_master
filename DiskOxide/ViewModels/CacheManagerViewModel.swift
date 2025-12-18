//
//  CacheManagerViewModel.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// ViewModel for Cache Manager
@MainActor
class CacheManagerViewModel: ObservableObject {
    @Published var settings: CacheSettings
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var history: [CleanupRecord] = []
    @Published var lastSummary: CleanupSummary?
    
    private let cacheService = CacheCleanerService()
    private let scheduler: SchedulerService
    
    init() {
        self.settings = cacheService.loadSettings()
        self.history = cacheService.loadHistory()
        self.scheduler = SchedulerService(cacheService: cacheService)
        
        // Start scheduler if enabled
        if settings.enabled {
            scheduler.startScheduler()
        }
    }
    
    /// Run manual cleanup
    func runCleanup() async {
        guard !isRunning else { return }
        
        isRunning = true
        errorMessage = nil
        progress = 0.0
        
        do {
            let summary = try await cacheService.runCleanup(settings: settings) { [weak self] prog, message in
                Task { @MainActor in
                    self?.progress = prog
                    self?.statusMessage = message
                }
            }
            
            lastSummary = summary
            history = cacheService.loadHistory()
            
            statusMessage = "Cleanup complete: \(summary.totalDeleted) files deleted, \(summary.formattedSize) freed"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Cleanup failed"
        }
        
        isRunning = false
    }
    
    /// Update parent folders
    func updateParentFolders(_ folders: [String]) {
        settings.parentFolders = folders
        saveSettings()
    }
    
    /// Add parent folder
    func addParentFolder(_ folder: String) {
        if !settings.parentFolders.contains(folder) {
            settings.parentFolders.append(folder)
            saveSettings()
        }
    }
    
    /// Remove parent folder
    func removeParentFolder(at index: Int) {
        settings.parentFolders.remove(at: index)
        saveSettings()
    }
    
    /// Update cache folder names
    func updateCacheFolderNames(_ names: [String]) {
        settings.cacheFolderNames = names
        saveSettings()
    }
    
    /// Add cache folder name
    func addCacheFolderName(_ name: String) {
        if !settings.cacheFolderNames.contains(name) {
            settings.cacheFolderNames.append(name)
            saveSettings()
        }
    }
    
    /// Remove cache folder name
    func removeCacheFolderName(at index: Int) {
        settings.cacheFolderNames.remove(at: index)
        saveSettings()
    }
    
    /// Update age threshold
    func updateAgeThreshold(_ hours: Int) {
        settings.ageThresholdHours = max(1, hours)
        saveSettings()
    }
    
    /// Update interval
    func updateInterval(_ hours: Int) {
        settings.intervalHours = max(1, hours)
        saveSettings()
    }
    
    /// Toggle enabled state
    func toggleEnabled() {
        settings.enabled.toggle()
        saveSettings()
        
        if settings.enabled {
            scheduler.startScheduler()
        } else {
            scheduler.stopScheduler()
        }
    }
    
    /// Save settings
    func saveSettings() {
        cacheService.saveSettings(settings)
    }
    
    /// Reload settings
    func reloadSettings() {
        settings = cacheService.loadSettings()
    }
    
    /// Reload history
    func reloadHistory() {
        history = cacheService.loadHistory()
    }
    
    /// Clear history
    func clearHistory() {
        cacheService.clearHistory()
        history = []
    }
    
    /// Get formatted age threshold
    var formattedAgeThreshold: String {
        if settings.ageThresholdHours < 24 {
            return "\(settings.ageThresholdHours) hours"
        } else {
            let days = settings.ageThresholdHours / 24
            return "\(days) days"
        }
    }
    
    /// Get formatted interval
    var formattedInterval: String {
        if settings.intervalHours < 24 {
            return "\(settings.intervalHours) hours"
        } else {
            let days = settings.intervalHours / 24
            return "\(days) days"
        }
    }
    
    /// Get formatted last cleanup date
    var formattedLastCleanupDate: String? {
        guard let date = settings.lastCleanupDate else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Get formatted next cleanup date
    var formattedNextCleanupDate: String? {
        guard let date = scheduler.nextCleanupDate else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Get total size from history
    var totalSizeFreed: Int64 {
        history.filter { $0.deletedSuccessfully }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// Get formatted total size freed
    var formattedTotalSizeFreed: String {
        ByteCountFormatter.string(fromByteCount: totalSizeFreed, countStyle: .file)
    }
}
