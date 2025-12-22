import SwiftUI

struct AppInstallerView: View {
    @ObservedObject var viewModel: AppInstallerViewModel
    @State private var selectedApp: HomebrewApp?
    @State private var selectedAppId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search and Filters
            searchAndFilterBar

            Divider()

            // Main Content - App List and Detail Side by Side
            HStack(spacing: 0) {
                // Left Panel - App List
                VStack(spacing: 0) {
                    // Content
                    if !viewModel.homebrewInstalled {
                        homebrewNotInstalledView
                    } else if viewModel.isLoading || viewModel.isSearching {
                        loadingView
                    } else if viewModel.filteredApps.isEmpty {
                        emptyStateView
                    } else {
                        appListView
                    }

                    Divider()

                    // Status Bar
                    statusBar
                }
                .frame(
                    minWidth: selectedApp == nil ? nil : 400,
                    maxWidth: selectedApp == nil ? .infinity : 500
                )

                // Right Panel - Detail
                if let app = selectedApp {
                    Divider()

                    HomebrewAppDetailView(
                        app: app,
                        viewModel: viewModel,
                        onClose: {
                            selectedApp = nil
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $viewModel.showInstallationLogs) {
            InstallationLogsView(
                logs: viewModel.installationLogs,
                isInstalling: viewModel.isInstalling
            )
        }
        .onAppear {
            if viewModel.apps.isEmpty && viewModel.installedApps.isEmpty {
                viewModel.initialLoad()
            }
        }
        .onChange(of: viewModel.lastUpdatedAppId) { _, updatedId in
            // Update selectedApp if it matches the updated app
            if let id = selectedAppId, id == updatedId {
                // Find updated app in viewModel
                if let updated = viewModel.apps.first(where: { $0.id == id }) {
                    selectedApp = updated
                } else if let updated = viewModel.installedApps.first(where: { $0.id == id }) {
                    selectedApp = updated
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 32))
                .foregroundColor(Constants.Colors.primaryColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("App Installer")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Browse and install apps from Homebrew")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Refresh Button
            Button(action: {
                viewModel.searchApps()
                viewModel.loadInstalledApps()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(Constants.Colors.primaryColor)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    // MARK: - Search and Filter Bar

    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search apps...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: viewModel.searchText) {
                            viewModel.onSearchTextChanged()
                        }

                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Installed Only Toggle
                Toggle(isOn: $viewModel.showInstalledOnly) {
                    HStack(spacing: 6) {
                        Image(
                            systemName: viewModel.showInstalledOnly
                                ? "checkmark.seal.fill" : "checkmark.circle")
                        Text("Installed Only")
                        if viewModel.showInstalledOnly && !viewModel.installedApps.isEmpty {
                            Text("(\(viewModel.installedApps.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(.button)
                .tint(viewModel.showInstalledOnly ? Color.green : Constants.Colors.primaryColor)
                .controlSize(.regular)
            }

            HStack(spacing: 12) {
                // Category Filter
                HStack(spacing: 6) {
                    Text("Category:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.selectedCategory) {
                        ForEach(AppCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                Spacer()

                // Sort Options
                HStack(spacing: 6) {
                    Text("Sort:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.sortOption) {
                        ForEach(AppInstallerViewModel.SortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }
        }
        .padding()
    }

    // MARK: - App List View

    private var appListView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedGroupKeys, id: \.self) { group in
                    appGroupSection(group: group)
                }
            }
        }
    }

    private var sortedGroupKeys: [String] {
        Array(viewModel.groupedApps.keys.sorted())
    }

    private func appGroupSection(group: String) -> some View {
        let apps = viewModel.groupedApps[group] ?? []

        return Section {
            ForEach(apps, id: \.id) { app in
                BrewAppRowView(
                    app: app, viewModel: viewModel, isSelected: selectedApp?.id == app.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedApp = app
                    selectedAppId = app.id
                }
            }
        } header: {
            appGroupHeader(group: group, count: apps.count)
        }
    }

    private func appGroupHeader(group: String, count: Int) -> some View {
        HStack {
            Text(group)
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(count) apps")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Apps Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Try searching for apps or adjusting your filters")
                .font(.body)
                .foregroundColor(.secondary)

            Button("Search All Apps") {
                viewModel.searchText = ""
                viewModel.selectedCategory = .all
                viewModel.showInstalledOnly = false
                viewModel.searchApps()
            }
            .buttonStyle(.borderedProminent)
            .tint(Constants.Colors.primaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading Homebrew apps...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Homebrew Not Installed

    private var homebrewNotInstalledView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Homebrew Not Installed")
                .font(.title)
                .fontWeight(.bold)

            Text("This feature requires Homebrew to be installed on your system.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("To install Homebrew, run this command in Terminal:")
                    .font(.headline)

                HStack {
                    Text(
                        "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                    )
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)

                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(
                            "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                            forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            Button("Open Homebrew Website") {
                if let url = URL(string: "https://brew.sh") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Constants.Colors.primaryColor)

            Button("Check Again") {
                viewModel.checkHomebrewInstallation()
            }
        }
        .frame(maxWidth: 600)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            if viewModel.isLoading || viewModel.isInstalling {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "info.circle")
                    .foregroundColor(Constants.Colors.primaryColor)
            }

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Installed apps count
            if !viewModel.installedApps.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(viewModel.installedApps.count) installed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }

            Text("\(viewModel.filteredApps.count) apps")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Brew App Row View

struct BrewAppRowView: View {
    let app: HomebrewApp
    @ObservedObject var viewModel: AppInstallerViewModel
    var isSelected: Bool = false

    // Get the latest app state from viewModel
    var currentApp: HomebrewApp {
        viewModel.apps.first(where: { $0.id == app.id })
            ?? viewModel.installedApps.first(where: { $0.id == app.id })
            ?? app
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon - Load asynchronously
            AsyncAppIcon(app: currentApp, size: 48)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(currentApp.displayName)
                        .font(.headline)

                    if currentApp.isInstalled {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("INSTALLED")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(4)
                        .help("This app is already installed on your system")
                    }
                }

                if let description = currentApp.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(currentApp.version)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Constants.Colors.primaryColor.opacity(0.2))
                        .cornerRadius(4)

                    if currentApp.installSize != nil {
                        Text(currentApp.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let releaseDate = currentApp.formattedReleaseDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(releaseDate)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let installs = currentApp.analytics?.install30Days {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                            Text("\(installs) installs")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Action Button
            Button(action: {
                if currentApp.isInstalled {
                    viewModel.uninstallApp(currentApp)
                } else {
                    viewModel.installApp(currentApp)
                }
            }) {
                Label(
                    currentApp.isInstalled ? "Uninstall" : "Install",
                    systemImage: currentApp.isInstalled ? "trash" : "arrow.down.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(currentApp.isInstalled ? .red : Constants.Colors.primaryColor)
            .disabled(viewModel.isInstalling)
        }
        .padding()
        .background(
            Group {
                if currentApp.isInstalled {
                    Color.green.opacity(0.05)
                } else if isSelected {
                    Constants.Colors.primaryColor.opacity(0.15)
                } else {
                    Color(NSColor.controlBackgroundColor).opacity(0.5)
                }
            }
        )
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    currentApp.isInstalled
                        ? Color.green.opacity(0.3)
                        : (isSelected ? Constants.Colors.primaryColor : Color.clear),
                    lineWidth: currentApp.isInstalled ? 1.5 : 2
                )
                .padding(.horizontal)
                .padding(.vertical, 4)
        )
    }
}

struct AppInstallerView_Previews: PreviewProvider {
    static var previews: some View {
        AppInstallerView(viewModel: AppInstallerViewModel())
            .frame(width: 900, height: 700)
    }
}
