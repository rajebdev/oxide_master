import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Spacer()
                    .frame(height: 40)

                // App Icon
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 100, height: 100)
                } else {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(Constants.Colors.primaryColor.gradient)
                }

                // App Name & Version
                VStack(spacing: 8) {
                    Text("Oxide Master")
                        .font(.system(size: 36, weight: .bold))

                    Text("Version 1.0.0")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Complete Disk Management Suite for macOS")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .padding(.horizontal, 100)

                // Features
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "chart.pie.fill",
                        title: "Disk Analyzer",
                        description: "Visualize disk usage with TreeMap and hierarchical views"
                    )

                    FeatureRow(
                        icon: "tray.fill",
                        title: "Cache Cleaner",
                        description: "Clean system and application caches"
                    )

                    FeatureRow(
                        icon: "arrow.clockwise.circle.fill",
                        title: "Backup Manager",
                        description: "Schedule automated backups with compression"
                    )

                    FeatureRow(
                        icon: "xmark.app.fill",
                        title: "App Uninstaller",
                        description: "Completely remove apps and leftover files"
                    )

                    FeatureRow(
                        icon: "square.and.arrow.down.fill",
                        title: "App Installer",
                        description: "Browse and install apps from Homebrew"
                    )

                    FeatureRow(
                        icon: "arrow.left.arrow.right.circle.fill",
                        title: "File Sync",
                        description: "Synchronize files between directories"
                    )
                }
                .frame(maxWidth: 500)

                Divider()
                    .padding(.horizontal, 100)

                // Tech Stack
                VStack(spacing: 12) {
                    Text("Built with")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        TechBadge(icon: "swift", name: "Swift", color: .orange)
                        TechBadge(
                            icon: "apple.logo", name: "SwiftUI",
                            color: Constants.Colors.primaryColor)
                        TechBadge(icon: "gearshape.2", name: "macOS", color: .gray)
                    }
                }

                Divider()
                    .padding(.horizontal, 100)

                // Info
                VStack(spacing: 12) {
                    HStack {
                        Text("Developer:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("RajebDev")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("License:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("MIT License")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Created:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("December 2025")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: 400)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Links
                HStack(spacing: 20) {
                    Button {
                        if let url = URL(string: "https://github.com/rajebdev") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("GitHub", systemImage: "link.circle.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if let url = URL(string: "mailto:support@oxidemaster.app") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Support", systemImage: "envelope.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
                    .frame(height: 40)

                // Copyright
                Text("© 2025 Oxide Master. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(Constants.Colors.primaryColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct TechBadge: View {
    let icon: String
    let name: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(width: 80)
    }
}
