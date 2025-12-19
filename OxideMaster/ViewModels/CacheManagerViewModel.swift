//
//  CacheManagerViewModel.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import Foundation
import SwiftUI

/// ViewModel for Cache Manager
@MainActor
class CacheManagerViewModel: ObservableObject {
    @Published var settings: CacheSettings
    @Published var isScanning = false
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var history: [CleanupRecord] = []
    @Published var lastSummary: CleanupSummary?

    // Preview mode
    @Published var cacheItems: [CacheItem] = []
    @Published var showPreview = false

    // Grouped items for tree view
    @Published var expandedCategories: Set<CacheCategory> = Set(CacheCategory.allCases)

    // Scheduler access
    @Published var hasPendingScheduledCleanup = false

    /// Group cache items by category
    var groupedCacheItems: [CacheGroup] {
        let grouped = Dictionary(grouping: cacheItems) { $0.category }
        return CacheCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return CacheGroup(
                category: category,
                items: items.sorted { $0.name < $1.name },
                isExpanded: expandedCategories.contains(category)
            )
        }
    }

    private let cacheService = CacheCleanerService()
    let scheduler: SchedulerService

    init() {
        self.settings = cacheService.loadSettings()
        self.history = cacheService.loadHistory()
        self.scheduler = SchedulerService(cacheService: cacheService)

        // Start scheduler if enabled
        if settings.enabled {
            scheduler.startScheduler()
        }

        // Check for pending cleanup
        checkPendingCleanup()
    }

    /// Scan for cache items (preview)
    func scanCacheItems() async {
        guard !isScanning else { return }

        isScanning = true
        errorMessage = nil
        progress = 0.0
        cacheItems = []

        do {
            let items = try await cacheService.scanCacheItems(settings: settings) {
                [weak self] prog, message in
                Task { @MainActor in
                    self?.progress = prog
                    self?.statusMessage = message
                }
            }

            cacheItems = items
            showPreview = true
            statusMessage = "Found \(items.count) cache folders (\(formatTotalSize(items)))"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Scan failed"
        }

        isScanning = false
    }

    /// Run cleanup with selected items
    func runCleanup() async {
        guard !isRunning else { return }
        guard showPreview else {
            // If no preview, scan first
            await scanCacheItems()
            return
        }

        isRunning = true
        errorMessage = nil
        progress = 0.0

        do {
            let summary = try await cacheService.runCleanup(items: cacheItems) {
                [weak self] prog, message in
                Task { @MainActor in
                    self?.progress = prog
                    self?.statusMessage = message
                }
            }

            lastSummary = summary
            history = cacheService.loadHistory()

            statusMessage =
                "Cleanup complete: \(summary.totalDeleted) items deleted, \(summary.formattedSize) freed"

            // Clear preview
            showPreview = false
            cacheItems = []
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Cleanup failed"
        }

        isRunning = false
    }

    /// Toggle selection for cache item
    func toggleSelection(for item: CacheItem) {
        if let index = cacheItems.firstIndex(where: { $0.id == item.id }) {
            cacheItems[index].isSelected.toggle()
        }
    }

    /// Select all items
    func selectAll() {
        for index in cacheItems.indices {
            cacheItems[index].isSelected = true
        }
    }

    /// Deselect all items
    func deselectAll() {
        for index in cacheItems.indices {
            cacheItems[index].isSelected = false
        }
    }

    /// Get total size of items
    func formatTotalSize(_ items: [CacheItem]) -> String {
        let total = items.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    /// Get selected items total size
    var selectedTotalSize: String {
        let total = cacheItems.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    /// Get selected count
    var selectedCount: Int {
        cacheItems.filter { $0.isSelected }.count
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

    /// Toggle project cache enabled
    func toggleProjectCacheEnabled() {
        settings.projectCacheEnabled.toggle()
        saveSettings()
    }

    /// Toggle specific project cache type
    func toggleProjectCacheType(_ type: ProjectCacheType) {
        if let index = settings.enabledProjectCacheTypes.firstIndex(of: type) {
            settings.enabledProjectCacheTypes.remove(at: index)
        } else {
            settings.enabledProjectCacheTypes.append(type)
        }
        saveSettings()
    }

    /// Update project scan depth
    func updateProjectScanDepth(_ depth: Int) {
        settings.projectScanDepth = max(1, min(10, depth))
        saveSettings()
    }

    /// Toggle application cache enabled
    func toggleApplicationCacheEnabled() {
        settings.applicationCacheEnabled.toggle()
        saveSettings()
    }

    /// Check if application cache type is enabled
    func isApplicationCacheTypeEnabled(_ type: ApplicationCacheType) -> Bool {
        settings.enabledApplicationCacheTypes.contains(type)
    }

    /// Toggle application cache type
    func toggleApplicationCacheType(_ type: ApplicationCacheType) {
        if let index = settings.enabledApplicationCacheTypes.firstIndex(of: type) {
            settings.enabledApplicationCacheTypes.remove(at: index)
        } else {
            settings.enabledApplicationCacheTypes.append(type)
        }
        saveSettings()
    }

    /// Toggle scan installed apps
    func toggleScanInstalledApps() {
        settings.scanInstalledApps.toggle()
        saveSettings()
    }

    /// Toggle category expansion
    func toggleCategoryExpansion(_ category: CacheCategory) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    /// Select all items in a category
    func selectAllInCategory(_ category: CacheCategory) {
        for index in cacheItems.indices where cacheItems[index].category == category {
            cacheItems[index].isSelected = true
        }
    }

    /// Deselect all items in a category
    func deselectAllInCategory(_ category: CacheCategory) {
        for index in cacheItems.indices where cacheItems[index].category == category {
            cacheItems[index].isSelected = false
        }
    }

    /// Check if project cache type is enabled
    func isProjectCacheTypeEnabled(_ type: ProjectCacheType) -> Bool {
        settings.enabledProjectCacheTypes.contains(type)
    }

    /// Toggle require confirmation for scheduled cleanup
    func toggleRequireConfirmation() {
        settings.requireConfirmationForScheduledCleanup.toggle()
        saveSettings()
    }

    /// Load pending cleanup from scheduler
    func loadPendingCleanup() {
        if !scheduler.pendingCacheItems.isEmpty {
            cacheItems = scheduler.pendingCacheItems
            showPreview = true
            hasPendingScheduledCleanup = false
            statusMessage = "Scheduled cleanup ready: \(cacheItems.count) items found"
        }
    }

    /// Check for pending scheduled cleanup
    func checkPendingCleanup() {
        hasPendingScheduledCleanup = !scheduler.pendingCacheItems.isEmpty
    }

    /// Confirm and run scheduled cleanup
    func confirmScheduledCleanup() async {
        isRunning = true
        errorMessage = nil
        progress = 0.0

        do {
            let summary = try await scheduler.confirmAndRunPendingCleanup()

            lastSummary = summary
            history = cacheService.loadHistory()

            statusMessage =
                "Scheduled cleanup complete: \(summary.totalDeleted) items deleted, \(summary.formattedSize) freed"

            // Clear preview
            showPreview = false
            cacheItems = []
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Cleanup failed"
        }

        isRunning = false
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
