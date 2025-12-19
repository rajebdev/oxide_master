//
//  CacheManagerView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct CacheManagerView: View {
    @StateObject private var viewModel = CacheManagerViewModel()
    @State private var showingSettings = false
    @State private var showingHistory = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            CacheManagerHeader(
                viewModel: viewModel,
                showingSettings: $showingSettings,
                showingHistory: $showingHistory
            )

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Pending scheduled cleanup alert
                    if viewModel.hasPendingScheduledCleanup && !viewModel.showPreview {
                        ScheduledCleanupAlert(viewModel: viewModel)
                    }

                    // Status card
                    CacheStatusCard(viewModel: viewModel)

                    // Progress
                    if viewModel.isScanning || viewModel.isRunning {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.progress) {
                                Text(viewModel.statusMessage)
                            }

                            Text(viewModel.isScanning ? "Scanning..." : "Cleaning up caches...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Constants.Colors.cardBackgroundColor)
                        .cornerRadius(Constants.UI.cornerRadius)
                    }

                    // Cache items preview
                    if viewModel.showPreview && !viewModel.cacheItems.isEmpty {
                        CachePreviewView(viewModel: viewModel)
                    }

                    // Last cleanup summary
                    if let summary = viewModel.lastSummary, !viewModel.showPreview {
                        CleanupSummaryCard(summary: summary)
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: Constants.Icons.error)
                                .foregroundColor(Constants.Colors.errorColor)
                            Text(error)
                                .foregroundColor(Constants.Colors.errorColor)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Constants.Colors.errorColor.opacity(0.1))
                        .cornerRadius(Constants.UI.cornerRadius)
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        if !viewModel.showPreview {
                            Button(action: {
                                Task {
                                    await viewModel.scanCacheItems()
                                }
                            }) {
                                Label("Scan Cache Folders", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(viewModel.isScanning || !viewModel.settings.enabled)
                            .buttonStyle(.borderedProminent)
                            .tint(Constants.Colors.primaryColor)
                            .controlSize(.large)
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.runCleanup()
                                }
                            }) {
                                Label(
                                    "Clean Selected (\(viewModel.selectedCount))",
                                    systemImage: "trash.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(viewModel.isRunning || viewModel.selectedCount == 0)
                            .buttonStyle(.borderedProminent)
                            .tint(Constants.Colors.primaryColor)
                            .controlSize(.large)

                            Button(action: {
                                viewModel.showPreview = false
                                viewModel.cacheItems = []
                            }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding(.horizontal)

                    // Quick settings
                    if !viewModel.showPreview {
                        QuickSettingsView(viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingSettings) {
            CacheSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingHistory) {
            CacheHistoryView(viewModel: viewModel)
        }
    }
}

// MARK: - Cache Manager Header

struct CacheManagerHeader: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    @Binding var showingSettings: Bool
    @Binding var showingHistory: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cache Manager")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Automatically clean up old cache files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("History") {
                showingHistory = true
            }

            Button("Settings") {
                showingSettings = true
            }
        }
        .padding()
    }
}

// MARK: - Cache Status Card

struct CacheStatusCard: View {
    @ObservedObject var viewModel: CacheManagerViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Cleanup Status")
                        .font(.headline)
                    Text(viewModel.settings.enabled ? "Enabled" : "Disabled")
                        .foregroundColor(
                            viewModel.settings.enabled
                                ? Constants.Colors.successColor : Constants.Colors.errorColor)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: .init(
                        get: { viewModel.settings.enabled },
                        set: { _ in viewModel.toggleEnabled() }
                    )
                )
                .tint(Constants.Colors.primaryColor)
            }

            Divider()

            VStack(spacing: 8) {
                InfoRow(label: "Age Threshold", value: viewModel.formattedAgeThreshold)
                InfoRow(label: "Cleanup Interval", value: viewModel.formattedInterval)

                if let lastCleanup = viewModel.formattedLastCleanupDate {
                    InfoRow(label: "Last Cleanup", value: lastCleanup)
                }

                if let nextCleanup = viewModel.formattedNextCleanupDate {
                    InfoRow(label: "Next Cleanup", value: nextCleanup)
                }

                InfoRow(label: "Total Freed", value: viewModel.formattedTotalSizeFreed)
            }
        }
        .padding()
        .background(Constants.Colors.cardBackgroundColor)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Scheduled Cleanup Alert

struct ScheduledCleanupAlert: View {
    @ObservedObject var viewModel: CacheManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(Constants.Colors.primaryColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Scheduled Cleanup Ready")
                        .font(.headline)
                    Text(
                        "Found \(viewModel.scheduler.pendingCacheItems.count) cache folders waiting for your approval"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.loadPendingCleanup()
                }) {
                    Label("Review & Confirm", systemImage: "eye.fill")
                }
                .buttonStyle(.borderedProminent).tint(Constants.Colors.primaryColor).controlSize(
                    .small)

                Button(action: {
                    Task {
                        await viewModel.confirmScheduledCleanup()
                    }
                }) {
                    Label("Clean Now", systemImage: "trash.fill")
                }
                .buttonStyle(.bordered)
                .tint(Constants.Colors.primaryColor)
                .controlSize(.small)

                Button(action: {
                    Task { @MainActor in
                        viewModel.scheduler.pendingCacheItems = []
                        viewModel.hasPendingScheduledCleanup = false
                    }
                }) {
                    Text("Dismiss")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Constants.Colors.primaryColor.opacity(0.1))
        .cornerRadius(Constants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Constants.Colors.primaryColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Cache Preview View

struct CachePreviewView: View {
    @ObservedObject var viewModel: CacheManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Cache Folders Found")
                        .font(.headline)
                    Text(
                        "\(viewModel.selectedCount) of \(viewModel.cacheItems.count) selected • \(viewModel.selectedTotalSize)"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            // Grouped list of cache items
            LazyVStack(spacing: 12, pinnedViews: []) {
                ForEach(viewModel.groupedCacheItems) { group in
                    CacheGroupView(group: group, viewModel: viewModel)
                }
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Constants.Colors.cardBackgroundColor)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Cache Group View

struct CacheGroupView: View {
    let group: CacheGroup
    @ObservedObject var viewModel: CacheManagerViewModel

    private var categoryColor: Color {
        switch group.category.color {
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Group Header
            Button(action: {
                viewModel.toggleCategoryExpansion(group.category)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: group.category.icon)
                        .foregroundColor(categoryColor)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.category.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(
                            "\(group.selectedCount)/\(group.items.count) selected • \(group.formattedSelectedSize) of \(group.formattedTotalSize)"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Button(action: {
                            viewModel.selectAllInCategory(group.category)
                        }) {
                            Image(systemName: "checkmark.square")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Select all in category")

                        Button(action: {
                            viewModel.deselectAllInCategory(group.category)
                        }) {
                            Image(systemName: "square")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Deselect all in category")
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Group Items (when expanded)
            if group.isExpanded {
                VStack(spacing: 6) {
                    ForEach(group.items) { item in
                        CacheItemRow(item: item, viewModel: viewModel)
                            .padding(.leading, 28)
                    }
                }
            }
        }
    }
}

// MARK: - Cache Item Row

struct CacheItemRow: View {
    let item: CacheItem
    @ObservedObject var viewModel: CacheManagerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { item.isSelected },
                    set: { _ in viewModel.toggleSelection(for: item) }
                )
            )
            .toggleStyle(.checkbox)
            .tint(Constants.Colors.primaryColor)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(item.type)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Constants.Colors.primaryColor.opacity(0.2))
                        .cornerRadius(4)
                }

                Text(item.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Show last modified only for non-application cache
                if item.category != .applicationCache {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(item.formattedLastModified)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.formattedSize)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                // Show full date only for non-application cache
                if item.category != .applicationCache, item.lastModified != nil {
                    Text(item.formattedLastModifiedFull)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(item.isSelected ? Constants.Colors.primaryColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    item.isSelected
                        ? Constants.Colors.primaryColor.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 1)
        )
    }
}

// MARK: - Cleanup Summary Card

struct CleanupSummaryCard: View {
    let summary: CleanupSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: Constants.Icons.success)
                    .foregroundColor(Constants.Colors.successColor)
                Text("Last Cleanup Results")
                    .font(.headline)
            }

            Divider()

            InfoRow(label: "Files Deleted", value: "\(summary.totalDeleted)")
            InfoRow(label: "Space Freed", value: summary.formattedSize)
            InfoRow(label: "Duration", value: String(format: "%.1f seconds", summary.duration))
            InfoRow(
                label: "Success Rate", value: String(format: "%.0f%%", summary.successRate * 100))
        }
        .padding()
        .background(Constants.Colors.successColor.opacity(0.1))
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Quick Settings View

struct QuickSettingsView: View {
    @ObservedObject var viewModel: CacheManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Settings")
                .font(.headline)

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
        }
        .padding()
        .background(Constants.Colors.cardBackgroundColor)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}
