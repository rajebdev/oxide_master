import AppKit
import Foundation
import SwiftUI

@MainActor
class AppInstallerViewModel: ObservableObject {
    @Published var apps: [HomebrewApp] = []
    @Published var installedApps: [HomebrewApp] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var isInstalling = false
    @Published var searchText = ""
    @Published var selectedCategory: AppCategory = .all
    @Published var sortOption: SortOption = .name
    @Published var showInstalledOnly = false
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var homebrewInstalled = true
    @Published var installationLogs: [String] = []
    @Published var showInstallationLogs = false

    // Track first appearance for auto-scan
    @Published var hasPerformedInitialScan = false

    // Track when an app's status changes to force UI updates
    @Published var lastUpdatedAppId: UUID?

    private let service = HomebrewService.shared
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init() {
        setupSearchDebouncing()
    }

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case popularity = "Popularity"
        case size = "Size"

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .popularity: return "chart.bar"
            case .size: return "arrow.up.arrow.down"
            }
        }
    }

    var filteredApps: [HomebrewApp] {
        var filtered = showInstalledOnly ? installedApps : apps

        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.token.localizedCaseInsensitiveContains(searchText)
                    || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by category
        if selectedCategory != .all {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        // Sort
        switch sortOption {
        case .name:
            filtered.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .popularity:
            filtered.sort {
                ($0.analytics?.install30Days ?? 0) > ($1.analytics?.install30Days ?? 0)
            }
        case .size:
            filtered.sort { ($0.installSize ?? 0) > ($1.installSize ?? 0) }
        }

        return filtered
    }

    var groupedApps: [String: [HomebrewApp]] {
        Dictionary(grouping: filteredApps) { app in
            app.isCask ? "Applications (GUI)" : "Packages (CLI)"
        }
    }

    // MARK: - Initialization

    func checkHomebrewInstallation() {
        homebrewInstalled = service.isHomebrewInstalled()
        if !homebrewInstalled {
            errorMessage =
                "Homebrew is not installed. Please install Homebrew first from https://brew.sh"
            showError = true
        }
    }

    private func setupSearchDebouncing() {
        // Observe searchText changes and debounce
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(
                named: .init("SearchTextChanged"))
            {
                performDebouncedSearch()
            }
        }
    }

    func onSearchTextChanged() {
        // Cancel previous debounce
        debounceTask?.cancel()

        // Set searching flag immediately if there's text
        if !searchText.isEmpty {
            isSearching = true
        }

        // Start new debounce task
        debounceTask = Task {
            // Wait 500ms before searching
            try? await Task.sleep(nanoseconds: 500_000_000)

            if !Task.isCancelled {
                searchApps()
            }
        }
    }

    private func performDebouncedSearch() {
        debounceTask?.cancel()

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            if !Task.isCancelled {
                searchApps()
            }
        }
    }

    // MARK: - Search Apps

    func searchApps() {
        // Cancel previous search
        searchTask?.cancel()

        searchTask = Task {
            isLoading = true
            statusMessage = "Searching Homebrew apps..."

            do {
                let results = try await service.searchApps(query: searchText)

                if !Task.isCancelled {
                    apps = results
                    statusMessage = "Found \(results.count) apps"
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    showError = true
                    statusMessage = "Search failed"
                }
            }

            isLoading = false
            isSearching = false
        }
    }

    // MARK: - Load Installed Apps

    func loadInstalledApps() {
        Task {
            isLoading = true
            statusMessage = "Loading installed apps..."

            do {
                installedApps = try await service.getInstalledApps()
                statusMessage = "\(installedApps.count) apps installed"
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                statusMessage = "Failed to load installed apps"
            }

            isLoading = false
        }
    }

    // MARK: - Install / Uninstall

    func installApp(_ app: HomebrewApp) {
        Task {
            isInstalling = true
            installationLogs = []
            showInstallationLogs = true

            addLog("🚀 Starting installation of \(app.name)...")
            addLog("📦 Package: \(app.token)")
            addLog("")

            do {
                try await service.installApp(app) { message in
                    Task { @MainActor in
                        self.statusMessage = message
                        self.addLog(message)
                    }
                }

                // Refresh app status
                await refreshAppStatus(app)

                addLog("")
                addLog("✅ \(app.name) installed successfully!")
                statusMessage = "✓ \(app.name) installed successfully"
            } catch {
                addLog("")
                addLog("❌ Installation failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showError = true
                statusMessage = "Installation failed"
            }

            isInstalling = false
        }
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(), dateStyle: .none, timeStyle: .medium)
        installationLogs.append("[\(timestamp)] \(message)")
    }

    func uninstallApp(_ app: HomebrewApp) {
        Task {
            isInstalling = true
            installationLogs = []
            showInstallationLogs = true

            addLog("🗑️ Starting uninstallation of \(app.name)...")
            addLog("📦 Package: \(app.token)")
            addLog("")

            do {
                try await service.uninstallApp(app) { message in
                    Task { @MainActor in
                        self.statusMessage = message
                        self.addLog(message)
                    }
                }

                // Refresh app status
                await refreshAppStatus(app)

                addLog("")
                addLog("✅ \(app.name) uninstalled successfully!")
                statusMessage = "✓ \(app.name) uninstalled successfully"
            } catch {
                addLog("")
                addLog("❌ Uninstallation failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showError = true
                statusMessage = "Uninstallation failed"
            }

            isInstalling = false
        }
    }

    private func refreshAppStatus(_ app: HomebrewApp) async {
        do {
            let updatedApp: HomebrewApp
            if app.isCask {
                updatedApp = try await service.getCaskDetail(token: app.token)
            } else {
                updatedApp = try await service.getFormulaDetail(name: app.token)
            }

            // Update in apps list
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                apps[index] = updatedApp
            }

            // Update installed apps list
            if updatedApp.isInstalled {
                if !installedApps.contains(where: { $0.id == app.id }) {
                    installedApps.append(updatedApp)
                } else if let index = installedApps.firstIndex(where: { $0.id == app.id }) {
                    installedApps[index] = updatedApp
                }
            } else {
                installedApps.removeAll { $0.id == app.id }
            }

            // Trigger UI update
            lastUpdatedAppId = app.id
        } catch {
            // Silently fail, the app might not have detailed info
        }
    }

    // MARK: - Get App Details

    func loadAppDetails(_ app: HomebrewApp) async -> HomebrewApp? {
        do {
            if app.isCask {
                return try await service.getCaskDetail(token: app.token)
            } else {
                return try await service.getFormulaDetail(name: app.token)
            }
        } catch {
            // Silently fail - some apps may not have detailed info available
            return nil
        }
    }

    // MARK: - Initial Load

    func initialLoad() {
        checkHomebrewInstallation()

        if homebrewInstalled {
            loadInstalledApps()
            searchApps()
        }
    }
}
