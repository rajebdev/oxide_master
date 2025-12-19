import Foundation
import SwiftUI

@MainActor
class AppUninstallerViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var orphanedFiles: [OrphanedFiles] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress = ""
    @Published var searchText = ""
    @Published var sortOption: SortOption = .name
    @Published var sourceFilters: Set<AppInfo.AppSource> = [.user, .appStore]
    @Published var selectedCategory: FilterCategory = .all
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var groupBySource = true

    // Track first appearance for auto-scan
    @Published var hasPerformedInitialScan = false

    private let service = AppUninstallerService.shared

    var groupedApps: [AppInfo.AppSource: [AppInfo]] {
        Dictionary(grouping: filteredApps) { $0.source }
    }

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case lastUsed = "Last Used"

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .size: return "arrow.up.arrow.down"
            case .lastUsed: return "clock"
            }
        }
    }

    enum FilterCategory: String, CaseIterable {
        case all = "All Apps"
        case large = "Large Apps"
        case unused = "Rarely Used"
        case withLoginItems = "Login Items"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .large: return "externaldrive"
            case .unused: return "clock.badge.questionmark"
            case .withLoginItems: return "power"
            }
        }
    }

    var filteredApps: [AppInfo] {
        var filtered = apps

        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by source
        filtered = filtered.filter { sourceFilters.contains($0.source) }

        // Filter by category
        switch selectedCategory {
        case .all:
            break
        case .large:
            filtered = filtered.filter { $0.totalSize > 500_000_000 }  // > 500MB
        case .unused:
            if let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) {
                filtered = filtered.filter { app in
                    if let lastUsed = app.lastUsedDate {
                        return lastUsed < thirtyDaysAgo
                    }
                    return false
                }
            }
        case .withLoginItems:
            filtered = filtered.filter { !$0.loginItems.isEmpty }
        }

        // Sort
        switch sortOption {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .size:
            filtered.sort { $0.totalSize > $1.totalSize }
        case .lastUsed:
            filtered.sort { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
        }

        return filtered
    }

    var totalAppsSize: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }

    var totalOrphanedSize: Int64 {
        orphanedFiles.reduce(0) { $0 + $1.totalSize }
    }

    func scanApplications() async {
        isScanning = true
        scanProgress = "Starting scan..."

        do {
            apps = try await service.scanApplications { [weak self] progress in
                self?.scanProgress = progress
            }
            scanProgress = "Scan complete!"
        } catch {
            scanProgress = "Error: \(error.localizedDescription)"
        }

        isScanning = false
    }

    func scanOrphaned() async {
        isScanning = true
        scanProgress = "Scanning orphaned files..."

        do {
            orphanedFiles = try await service.scanOrphanedFiles(installedApps: apps) {
                [weak self] progress in
                self?.scanProgress = progress
            }
            scanProgress = "Found \(orphanedFiles.count) orphaned items"
        } catch {
            scanProgress = "Error: \(error.localizedDescription)"
        }

        isScanning = false
    }

    func uninstallApp(
        _ app: AppInfo,
        removeAppBundle: Bool = true,
        removeRelatedFiles: Bool = true,
        removeLoginItems: Bool = true,
        moveToTrash: Bool = true
    ) async -> Bool {
        isCleaning = true
        errorMessage = nil

        do {
            try await service.uninstallApp(
                app,
                removeAppBundle: removeAppBundle,
                removeRelatedFiles: removeRelatedFiles,
                removeLoginItems: removeLoginItems,
                moveToTrash: moveToTrash
            )

            // Remove from list
            apps.removeAll { $0.id == app.id }
            isCleaning = false
            return true
        } catch {
            errorMessage = "Failed to uninstall \(app.name):\n\(error.localizedDescription)"
            showError = true
            isCleaning = false
            return false
        }
    }

    func cleanOrphanedFiles(_ orphaned: OrphanedFiles, moveToTrash: Bool = true) async {
        isCleaning = true

        do {
            try await service.cleanOrphanedFiles(orphaned, moveToTrash: moveToTrash)
            orphanedFiles.removeAll { $0.id == orphaned.id }
        } catch {
            print("Error cleaning orphaned files: \(error)")
        }

        isCleaning = false
    }
}
