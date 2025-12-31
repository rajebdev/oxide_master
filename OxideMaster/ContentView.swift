//
//  ContentView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//  Updated with proper macOS NavigationSplitView
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab? = .installer
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Persisted ViewModels - survive tab switches
    @StateObject private var diskAnalyzerVM = DiskAnalyzerViewModel()
    @StateObject private var backupManagerVM = BackupManagerViewModel()
    @StateObject private var fileSyncVM = FileSyncViewModel()
    @StateObject private var cacheManagerVM = CacheManagerViewModel()
    @StateObject private var appUninstallerVM = AppUninstallerViewModel()
    @StateObject private var appInstallerVM = AppInstallerViewModel()

    enum Tab: String, CaseIterable, Identifiable {
        case installer = "App Installer"
        case uninstaller = "App Uninstaller"
        case analyzer = "Disk Analyzer"
        case cache = "Cache Manager"
        case fileSync = "File Sync"
        case backup = "Backup Manager"
        case about = "About"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .installer: return "arrow.down.app.fill"
            case .uninstaller: return "xmark.app.fill"
            case .analyzer: return "externaldrive.fill"
            case .cache: return "tray.fill"
            case .fileSync: return "arrow.triangle.2.circlepath"
            case .backup: return "clock.arrow.circlepath"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with fixed About at bottom
            List(selection: $selectedTab) {
                ForEach([Tab.installer, .uninstaller, .analyzer, .cache, .fileSync, .backup], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            .safeAreaInset(edge: .bottom) {
                // Fixed About button at bottom - clean, no border
                Button {
                    selectedTab = .about
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: Tab.about.icon)
                            .foregroundColor(selectedTab == .about ? .accentColor : .secondary)
                        Text(Tab.about.rawValue)
                            .foregroundColor(selectedTab == .about ? .primary : .secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == .about ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        } detail: {
            // Content area
            contentView
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .analyzer:
            DiskAnalyzerView(viewModel: diskAnalyzerVM)
        case .backup:
            BackupManagerView(viewModel: backupManagerVM)
        case .fileSync:
            FileSyncView(viewModel: fileSyncVM)
        case .cache:
            CacheManagerView(viewModel: cacheManagerVM)
        case .uninstaller:
            AppUninstallerView(viewModel: appUninstallerVM)
        case .installer:
            AppInstallerView(viewModel: appInstallerVM)
        case .about:
            AboutView()
        case .none:
            Text("Select an item")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Header View (for other uses)

struct HeaderView: View {
    var body: some View {
        HStack {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: Constants.Icons.disk)
                    .font(.system(size: 32))
                    .foregroundColor(Constants.Colors.primaryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.appName)
                    .font(.title)
                    .fontWeight(.bold)

                Text(
                    "Disk Analyzer • Cache Cleaner • Backup Manager • App Uninstaller • App Installer • File Sync"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Legacy Sidebar Components (kept for compatibility)

struct LiquidGlassSidebar: View {
    @Binding var selectedTab: ContentView.Tab?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List(selection: $selectedTab) {
            ForEach([ContentView.Tab.installer, .uninstaller, .analyzer, .cache, .fileSync, .backup], id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            
            Divider()
            
            Label(ContentView.Tab.about.rawValue, systemImage: ContentView.Tab.about.icon)
                .tag(ContentView.Tab.about)
        }
        .listStyle(.sidebar)
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.plain)
    }
}

struct SidebarView: View {
    @Binding var selectedTab: ContentView.Tab?

    var body: some View {
        LiquidGlassSidebar(selectedTab: $selectedTab)
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
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: Constants.Icons.disk)
                    .font(.system(size: 64))
                    .foregroundColor(Constants.Colors.primaryColor)
            }

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

            Text("© 2025 Oxide Master. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
