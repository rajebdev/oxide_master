//
//  CacheSettingsView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct CacheSettingsView: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newParentFolder = ""
    @State private var newCacheFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cache Settings")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()

            Divider()

            // Settings content
            Form {
                // Parent folders
                Section("Parent Folders to Scan") {
                    List {
                        ForEach(Array(viewModel.settings.parentFolders.enumerated()), id: \.offset)
                        { index, folder in
                            HStack {
                                Text(folder)
                                    .font(.caption)
                                Spacer()
                                Button(action: {
                                    viewModel.removeParentFolder(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("Add parent folder path", text: $newParentFolder)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            if !newParentFolder.isEmpty {
                                viewModel.addParentFolder(newParentFolder)
                                newParentFolder = ""
                            }
                        }
                        .disabled(newParentFolder.isEmpty)
                    }
                }

                // Cache folder names
                Section("Cache Folder Names to Match") {
                    List {
                        ForEach(
                            Array(viewModel.settings.cacheFolderNames.enumerated()), id: \.offset
                        ) { index, name in
                            HStack {
                                Text(name)
                                Spacer()
                                Button(action: {
                                    viewModel.removeCacheFolderName(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("Add cache folder name", text: $newCacheFolderName)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            if !newCacheFolderName.isEmpty {
                                viewModel.addCacheFolderName(newCacheFolderName)
                                newCacheFolderName = ""
                            }
                        }
                        .disabled(newCacheFolderName.isEmpty)
                    }
                }

                // Thresholds
                Section("Cleanup Thresholds") {
                    HStack {
                        Text("Age Threshold (hours):")
                        Spacer()
                        TextField(
                            "Hours",
                            value: .init(
                                get: { viewModel.settings.ageThresholdHours },
                                set: { viewModel.updateAgeThreshold($0) }
                            ), format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }

                    Text("Files older than this will be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Cleanup Interval (hours):")
                        Spacer()
                        TextField(
                            "Hours",
                            value: .init(
                                get: { viewModel.settings.intervalHours },
                                set: { viewModel.updateInterval($0) }
                            ), format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }

                    Text("How often to run automatic cleanup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Scheduler Behavior
                Section("Automatic Cleanup Behavior") {
                    Toggle(
                        isOn: .init(
                            get: { viewModel.settings.requireConfirmationForScheduledCleanup },
                            set: { _ in viewModel.toggleRequireConfirmation() }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Require Confirmation")
                                .font(.body)
                            Text("Show notification and wait for your approval before cleaning")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Constants.Colors.primaryColor)

                    if !viewModel.settings.requireConfirmationForScheduledCleanup {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Cache will be cleaned automatically without confirmation")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Project Cache Cleaning
                Section {
                    Toggle(
                        "Enable Project Cache Cleaning",
                        isOn: .init(
                            get: { viewModel.settings.projectCacheEnabled },
                            set: { _ in viewModel.toggleProjectCacheEnabled() }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(Constants.Colors.primaryColor)

                    Text("Safely clean build artifacts and dependencies from development projects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Label(
                        "Project Cache Cleaning (Advanced)", systemImage: "folder.badge.gearshape")
                }

                if viewModel.settings.projectCacheEnabled {
                    Section("Project Types to Clean") {
                        ForEach(ProjectCacheType.allCases, id: \.self) { cacheType in
                            HStack {
                                Toggle(
                                    isOn: .init(
                                        get: { viewModel.isProjectCacheTypeEnabled(cacheType) },
                                        set: { _ in viewModel.toggleProjectCacheType(cacheType) }
                                    )
                                ) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cacheType.displayName)
                                            .font(.body)
                                        Text(
                                            "Validates: \(cacheType.validationFiles.prefix(2).joined(separator: ", "))"
                                        )
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    }
                                }
                                .tint(Constants.Colors.primaryColor)
                            }
                        }
                    }

                    Section("Scan Settings") {
                        HStack {
                            Text("Max Scan Depth:")
                            Spacer()
                            Stepper(
                                value: .init(
                                    get: { viewModel.settings.projectScanDepth },
                                    set: { viewModel.updateProjectScanDepth($0) }
                                ), in: 1...10
                            ) {
                                Text("\(viewModel.settings.projectScanDepth) levels")
                                    .frame(width: 80)
                            }
                        }

                        Text("Deeper scans take longer but find more projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Safety Validation", systemImage: "checkmark.shield.fill")
                                .font(.headline)
                                .foregroundColor(.green)

                            Text("Each folder is validated before deletion:")
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 4) {
                                Label(
                                    "node_modules → checks for package.json",
                                    systemImage: "checkmark.circle.fill")
                                Label(
                                    "target → checks for Cargo.toml or pom.xml",
                                    systemImage: "checkmark.circle.fill")
                                Label(
                                    "__pycache__ → checks for .py files",
                                    systemImage: "checkmark.circle.fill")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Application Cache Cleaning
                Section {
                    Toggle(
                        "Enable Application Cache Cleaning",
                        isOn: .init(
                            get: { viewModel.settings.applicationCacheEnabled },
                            set: { _ in viewModel.toggleApplicationCacheEnabled() }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(Constants.Colors.primaryColor)

                    Text(
                        "Clean cache from installed macOS applications like browsers, developer tools, and more"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Label(
                        "Application Cache Cleaning", systemImage: "app.badge")
                }

                if viewModel.settings.applicationCacheEnabled {
                    Section("Application Categories") {
                        ForEach(ApplicationCacheType.allCases, id: \.self) { cacheType in
                            Toggle(
                                isOn: .init(
                                    get: { viewModel.isApplicationCacheTypeEnabled(cacheType) },
                                    set: { _ in viewModel.toggleApplicationCacheType(cacheType) }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cacheType.displayName)
                                        .font(.body)
                                    Text(getExampleApps(for: cacheType))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(Constants.Colors.primaryColor)
                        }
                    }

                    Section("Additional Options") {
                        Toggle(
                            "Scan Installed Applications",
                            isOn: .init(
                                get: { viewModel.settings.scanInstalledApps },
                                set: { _ in viewModel.toggleScanInstalledApps() }
                            )
                        )
                        .toggleStyle(.switch)
                        .tint(Constants.Colors.primaryColor)

                        Text("Automatically detect and clean cache from all apps in /Applications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Common App Caches", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundColor(Constants.Colors.primaryColor)

                            Text("Examples of what will be cleaned:")
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Chrome/Safari/Firefox browser cache", systemImage: "globe")
                                Label(
                                    "Xcode DerivedData and build cache", systemImage: "hammer.fill")
                                Label(
                                    "Slack, Discord, Teams message cache",
                                    systemImage: "message.fill")
                                Label(
                                    "VSCode, JetBrains IDE cache",
                                    systemImage: "chevron.left.forwardslash.chevron.right")
                                Label("Spotify, Music app cache", systemImage: "music.note")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 650, height: 800)
    }

    private func getExampleApps(for type: ApplicationCacheType) -> String {
        switch type {
        case .browsers:
            return "Chrome, Safari, Firefox, Edge, Brave"
        case .developerTools:
            return "Xcode, VSCode, JetBrains IDEs, Android Studio"
        case .messaging:
            return "Slack, Discord, Microsoft Teams"
        case .media:
            return "Spotify, VLC, Music, TV"
        case .productivity:
            return "Notion, Adobe Apps, Microsoft Office"
        case .systemCache:
            return "iCloud cache, system logs, app states"
        }
    }
}
