import SwiftUI

struct HomebrewAppDetailView: View {
    let app: HomebrewApp
    @ObservedObject var viewModel: AppInstallerViewModel
    let onClose: () -> Void

    @State private var detailedApp: HomebrewApp?
    @State private var isLoadingDetails = true

    var displayApp: HomebrewApp {
        detailedApp ?? app
    }

    var body: some View {
        VStack(spacing: 0) {
            // Close Button Header
            HStack {
                Text("App Details")
                    .font(.headline)
                    .padding(.leading)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    Divider()

                    // Information Sections
                    VStack(spacing: 20) {
                        // Basic Info
                        infoSection

                        // Installation Info
                        if displayApp.isInstalled {
                            installationInfoSection
                        }

                        // Dependencies
                        if let dependencies = displayApp.dependencies, !dependencies.isEmpty {
                            dependenciesSection(dependencies: dependencies)
                        }

                        // Analytics
                        if let analytics = displayApp.analytics {
                            analyticsSection(analytics: analytics)
                        }

                        // Links
                        linksSection
                    }
                    .padding()
                }
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadDetails()
        }
        .onChange(of: app.id) {
            // Reset state and reload when app changes
            detailedApp = nil
            isLoadingDetails = true
            loadDetails()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon - Load asynchronously
            AsyncAppIcon(app: displayApp, size: 100)
                .shadow(radius: 5)

            // App Name
            VStack(spacing: 8) {
                HStack {
                    Text(displayApp.displayName)
                        .font(.title)
                        .fontWeight(.bold)

                    if displayApp.isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                }

                Text(displayApp.token)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            // Description
            if let description = displayApp.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action Buttons
            HStack(spacing: 12) {
                if displayApp.isInstalled {
                    Button(action: {
                        viewModel.uninstallApp(displayApp)
                    }) {
                        Label("Uninstall", systemImage: "trash")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isInstalling)
                } else {
                    Button(action: {
                        viewModel.installApp(displayApp)
                    }) {
                        Label("Install", systemImage: "arrow.down.circle.fill")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent).tint(Constants.Colors.primaryColor).disabled(
                        viewModel.isInstalling)
                }

                if let homepage = displayApp.homepage, let url = URL(string: homepage) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Label("Website", systemImage: "safari")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Status
            if viewModel.isInstalling {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)

            VStack(spacing: 8) {
                BrewInfoRow(label: "Version", value: displayApp.version, icon: "number.circle.fill")

                BrewInfoRow(
                    label: "Type",
                    value: displayApp.isCask ? "Application (GUI)" : "Package (CLI)",
                    icon: displayApp.isCask ? "app.dashed" : "terminal.fill"
                )

                BrewInfoRow(
                    label: "Category",
                    value: displayApp.category.rawValue,
                    icon: displayApp.category.icon
                )

                if displayApp.installSize != nil {
                    BrewInfoRow(
                        label: "Size",
                        value: displayApp.formattedSize,
                        icon: "internaldrive"
                    )
                }

                if let releaseDate = displayApp.formattedReleaseDate {
                    BrewInfoRow(
                        label: "Last Release",
                        value: releaseDate,
                        icon: "calendar.circle.fill"
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }

    // MARK: - Installation Info Section

    private var installationInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation")
                .font(.headline)

            VStack(spacing: 8) {
                BrewInfoRow(
                    label: "Status",
                    value: "Installed",
                    icon: "checkmark.circle.fill",
                    valueColor: .green
                )

                BrewInfoRow(
                    label: "Command",
                    value:
                        "brew \(displayApp.isCask ? "install --cask" : "install") \(displayApp.token)",
                    icon: "terminal"
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }

    // MARK: - Dependencies Section

    private func dependenciesSection(dependencies: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dependencies")
                    .font(.headline)

                Text("\(dependencies.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Constants.Colors.primaryColor.opacity(0.2))
                    .cornerRadius(4)
            }

            VStack(spacing: 0) {
                ForEach(dependencies, id: \.self) { dependency in
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(dependency)
                            .font(.body)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)

                    if dependency != dependencies.last {
                        Divider()
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }

    // MARK: - Analytics Section

    private func analyticsSection(analytics: HomebrewAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popularity")
                .font(.headline)

            VStack(spacing: 8) {
                if let installs30 = analytics.install30Days {
                    BrewInfoRow(
                        label: "Last 30 Days",
                        value: "\(installs30) installs",
                        icon: "chart.bar.fill"
                    )
                }

                if let installs90 = analytics.install90Days {
                    BrewInfoRow(
                        label: "Last 90 Days",
                        value: "\(installs90) installs",
                        icon: "chart.bar.fill"
                    )
                }

                if let installs365 = analytics.install365Days {
                    BrewInfoRow(
                        label: "Last Year",
                        value: "\(installs365) installs",
                        icon: "chart.bar.fill"
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.headline)

            VStack(spacing: 8) {
                if let homepage = displayApp.homepage {
                    LinkRow(
                        label: "Homepage",
                        url: homepage,
                        icon: "safari"
                    )
                }

                LinkRow(
                    label: "Homebrew Formula",
                    url:
                        "https://formulae.brew.sh/\(displayApp.isCask ? "cask" : "formula")/\(displayApp.token)",
                    icon: "terminal.fill"
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }

    // MARK: - Helper Methods

    private func loadDetails() {
        Task {
            if let detailed = await viewModel.loadAppDetails(app) {
                detailedApp = detailed
                isLoadingDetails = false
            } else {
                isLoadingDetails = false
            }
        }
    }
}

// MARK: - Brew Info Row

struct BrewInfoRow: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)

            Spacer()

            Text(value)
                .foregroundColor(valueColor)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Link Row

struct LinkRow: View {
    let label: String
    let url: String
    let icon: String

    var body: some View {
        Button(action: {
            if let urlObj = URL(string: url) {
                NSWorkspace.shared.open(urlObj)
            }
        }) {
            HStack {
                Label(label, systemImage: icon)

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(Constants.Colors.primaryColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

struct HomebrewAppDetailView_Previews: PreviewProvider {
    static var previews: some View {
        HomebrewAppDetailView(
            app: HomebrewApp(
                name: "Visual Studio Code",
                token: "visual-studio-code",
                description:
                    "Code editor redefined and optimized for building and debugging modern web and cloud applications",
                homepage: "https://code.visualstudio.com",
                version: "1.85.0",
                isInstalled: true,
                isCask: true,
                icon: "https://formulae.brew.sh/images/cask/visual-studio-code.png",
                installSize: 500_000_000,
                dependencies: ["git", "node"],
                analytics: HomebrewAnalytics(
                    install30Days: 15000, install90Days: 45000, install365Days: 180000)
            ),
            viewModel: AppInstallerViewModel(),
            onClose: {}
        )
    }
}
