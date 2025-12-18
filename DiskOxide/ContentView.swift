//
//  ContentView.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .analyzer

    enum Tab {
        case analyzer
        case backup
        case fileSync
        case cache
        case uninstaller
        case installer
        case about
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            Divider()

            // Main content with sidebar
            HStack(spacing: 0) {
                // Sidebar
                SidebarView(selectedTab: $selectedTab)

                Divider()

                // Content
                Group {
                    switch selectedTab {
                    case .analyzer:
                        DiskAnalyzerView()
                    case .backup:
                        BackupManagerView()
                    case .fileSync:
                        FileSyncView()
                    case .cache:
                        CacheManagerView()
                    case .uninstaller:
                        AppUninstallerView()
                    case .installer:
                        AppInstallerView()
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: Constants.Icons.disk)
                .font(.system(size: 32))
                .foregroundColor(Constants.Colors.primaryColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.appName)
                    .font(.title)
                    .fontWeight(.bold)

                Text(
                    "Disk Analyzer • Backup Manager • File Sync • Cache Cleaner • App Uninstaller • App Installer"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Constants.Colors.backgroundColor)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        VStack(spacing: 0) {
            SidebarButton(
                title: "Disk Analyzer",
                icon: Constants.Icons.disk,
                isSelected: selectedTab == .analyzer
            ) {
                selectedTab = .analyzer
            }

            SidebarButton(
                title: "Backup Manager",
                icon: Constants.Icons.backup,
                isSelected: selectedTab == .backup
            ) {
                selectedTab = .backup
            }

            SidebarButton(
                title: "File Sync",
                icon: Constants.Icons.sync,
                isSelected: selectedTab == .fileSync
            ) {
                selectedTab = .fileSync
            }

            SidebarButton(
                title: "Cache Manager",
                icon: Constants.Icons.cache,
                isSelected: selectedTab == .cache
            ) {
                selectedTab = .cache
            }

            SidebarButton(
                title: "App Uninstaller",
                icon: "xmark.app.fill",
                isSelected: selectedTab == .uninstaller
            ) {
                selectedTab = .uninstaller
            }

            SidebarButton(
                title: "App Installer",
                icon: "arrow.down.app.fill",
                isSelected: selectedTab == .installer
            ) {
                selectedTab = .installer
            }

            Spacer()

            Divider()

            SidebarButton(
                title: "About",
                icon: "info.circle",
                isSelected: selectedTab == .about
            ) {
                selectedTab = .about
            }
        }
        .frame(width: 220)
        .background(Constants.Colors.backgroundColor)
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 13))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Constants.Colors.primaryColor.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? Constants.Colors.primaryColor : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("Appearance") {
                Text("Settings coming soon...")
            }
        }
        .padding()
    }
}

struct PermissionsSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("Uses File Picker - No Special Permissions Needed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding()

            Spacer()
        }
        .padding()
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: Constants.Icons.disk)
                .font(.system(size: 64))
                .foregroundColor(Constants.Colors.primaryColor)

            Text(Constants.appName)
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(Constants.appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(
                "A powerful native macOS app for disk analysis, backup management, file synchronization, and cache cleanup."
            )
            .multilineTextAlignment(.center)
            .padding()

            Spacer()

            Text("© 2025 Disk Oxide. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
