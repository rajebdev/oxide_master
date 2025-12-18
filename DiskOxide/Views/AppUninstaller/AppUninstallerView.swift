import SwiftUI

struct AppUninstallerView: View {
    @StateObject private var viewModel = AppUninstallerViewModel()
    @State private var selectedApp: AppInfo?
    @State private var showingUninstallSheet = false
    @State private var showingOrphaned = false

    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - App List
            VStack(spacing: 0) {
                // Header Stats
                statsHeader

                Divider()

                // Controls
                controlsBar

                Divider()

                // App List
                if viewModel.isScanning {
                    scanningView
                } else {
                    appListView
                }
            }
            .frame(
                minWidth: selectedApp == nil ? nil : 400,
                maxWidth: selectedApp == nil ? .infinity : 500)

            if let app = selectedApp {
                Divider()

                // Right Panel - Detail
                AppDetailView(
                    app: app,
                    onClose: {
                        selectedApp = nil
                    }
                ) { action in
                    handleAppAction(app, action: action)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingOrphaned) {
            OrphanedFilesView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            if viewModel.apps.isEmpty {
                await viewModel.scanApplications()
            }
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 30) {
            StatBox(
                title: "Total Apps",
                value: "\(viewModel.filteredApps.count)",
                icon: "square.grid.2x2",
                color: .blue
            )

            StatBox(
                title: "Total Size",
                value: viewModel.totalAppsSize.formatted(.byteCount(style: .file)),
                icon: "externaldrive",
                color: .orange
            )

            if viewModel.totalOrphanedSize > 0 {
                StatBox(
                    title: "Orphaned Files",
                    value: viewModel.totalOrphanedSize.formatted(.byteCount(style: .file)),
                    icon: "trash",
                    color: .red
                )
            }

            Spacer()
        }
        .padding()
    }

    private var controlsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search apps...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: 300)

                Spacer()

                // Category Filter
                Picker("Filter", selection: $viewModel.selectedCategory) {
                    ForEach(AppUninstallerViewModel.FilterCategory.allCases, id: \.self) {
                        category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                // Sort
                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(AppUninstallerViewModel.SortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.icon)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                // Source Filter Menu
                Menu {
                    ForEach(AppInfo.AppSource.allCases, id: \.self) { source in
                        Button {
                            if viewModel.sourceFilters.contains(source) {
                                viewModel.sourceFilters.remove(source)
                            } else {
                                viewModel.sourceFilters.insert(source)
                            }
                        } label: {
                            Label {
                                Text(source.rawValue)
                            } icon: {
                                Image(
                                    systemName: viewModel.sourceFilters.contains(source)
                                        ? "checkmark.square.fill"
                                        : "square")
                            }
                        }
                    }

                    Divider()

                    Button("Select All") {
                        viewModel.sourceFilters = Set(AppInfo.AppSource.allCases)
                    }

                    Button("Deselect All") {
                        viewModel.sourceFilters.removeAll()
                    }
                } label: {
                    Label("Sources", systemImage: "line.3.horizontal.decrease.circle")
                }

                // Group by Source
                Toggle(isOn: $viewModel.groupBySource) {
                    Label("Group", systemImage: "folder.fill")
                }
                .toggleStyle(.button)

                // Refresh
                Button {
                    Task {
                        await viewModel.scanApplications()
                    }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }

                // Orphaned Files
                Button {
                    showingOrphaned.toggle()
                } label: {
                    Label("Orphaned", systemImage: "trash")
                }
            }
        }
        .padding()
    }

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(viewModel.scanProgress)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appListView: some View {
        List(selection: $selectedApp) {
            if viewModel.groupBySource {
                // Grouped by source (tree view)
                ForEach(AppInfo.AppSource.allCases, id: \.self) { source in
                    if let apps = viewModel.groupedApps[source], !apps.isEmpty {
                        Section {
                            ForEach(apps) { app in
                                AppRowView(app: app)
                                    .tag(app)
                            }
                        } header: {
                            HStack {
                                Image(systemName: source.icon)
                                    .foregroundColor(.blue)
                                Text(source.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text("\(apps.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            } else {
                // Flat list
                ForEach(viewModel.filteredApps) { app in
                    AppRowView(app: app)
                        .tag(app)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func handleAppAction(_ app: AppInfo, action: AppAction) {
        switch action {
        case .uninstallComplete:
            Task {
                let success = await viewModel.uninstallApp(
                    app,
                    removeAppBundle: true,
                    removeRelatedFiles: true,
                    removeLoginItems: true,
                    moveToTrash: true
                )
                if success {
                    selectedApp = nil
                }
            }
        case .uninstallAppOnly:
            Task {
                let success = await viewModel.uninstallApp(
                    app,
                    removeAppBundle: true,
                    removeRelatedFiles: false,
                    removeLoginItems: false,
                    moveToTrash: true
                )
                if success {
                    selectedApp = nil
                }
            }
        case .cleanFiles:
            Task {
                await viewModel.uninstallApp(
                    app,
                    removeAppBundle: false,
                    removeRelatedFiles: true,
                    removeLoginItems: true,
                    moveToTrash: true
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct AppRowView: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 40, height: 40)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(.headline)

                    if app.isSystemApp {
                        Image(systemName: "lock.shield")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !app.loginItems.isEmpty {
                        Image(systemName: "power")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Text("v\(app.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(app.totalSize.formatted(.byteCount(style: .file)))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Spacer()

            if let lastUsed = app.lastUsedDate {
                Text(lastUsed, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

enum AppAction {
    case uninstallComplete
    case uninstallAppOnly
    case cleanFiles
}
