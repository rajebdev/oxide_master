import SwiftUI

struct AppInstallerView: View {
    @ObservedObject var viewModel: AppInstallerViewModel
    @State private var selectedApp: HomebrewApp?

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
        .onAppear {
            if viewModel.apps.isEmpty && viewModel.installedApps.isEmpty {
                viewModel.initialLoad()
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
                    Label("Installed Only", systemImage: "checkmark.circle.fill")
                }
                .toggleStyle(.button)
                .tint(Constants.Colors.primaryColor)
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

    var body: some View {
        HStack(spacing: 12) {
            // Icon - Load asynchronously
            AsyncAppIcon(app: app, size: 48)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.displayName)
                        .font(.headline)

                    if app.isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                if let description = app.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(app.version)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Constants.Colors.primaryColor.opacity(0.2))
                        .cornerRadius(4)

                    if app.installSize != nil {
                        Text(app.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let releaseDate = app.formattedReleaseDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(releaseDate)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let installs = app.analytics?.install30Days {
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
                if app.isInstalled {
                    viewModel.uninstallApp(app)
                } else {
                    viewModel.installApp(app)
                }
            }) {
                Label(
                    app.isInstalled ? "Uninstall" : "Install",
                    systemImage: app.isInstalled ? "trash" : "arrow.down.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(app.isInstalled ? .red : Constants.Colors.primaryColor)
            .disabled(viewModel.isInstalling)
        }
        .padding()
        .background(
            isSelected
                ? Constants.Colors.primaryColor.opacity(0.15)
                : Color(NSColor.controlBackgroundColor).opacity(0.5)
        )
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Constants.Colors.primaryColor : Color.clear, lineWidth: 2)
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
