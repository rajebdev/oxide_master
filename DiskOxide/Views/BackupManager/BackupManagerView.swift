//
//  BackupManagerView.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import AppKit
import SwiftUI

struct BackupManagerView: View {
    @StateObject private var viewModel = BackupManagerViewModel()
    @State private var showingHistory = false

    var body: some View {
        HSplitView {
            // Left: Configuration
            VStack(alignment: .leading, spacing: 20) {
                Text("Backup Configuration")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 16) {
                    // Source path
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Folder")
                            .font(.headline)
                        HStack {
                            TextField("Source path", text: $viewModel.config.sourcePath)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                selectSourceFolder()
                            }
                        }
                    }
                    .padding()
                    .background(Constants.Colors.cardBackgroundColor)
                    .cornerRadius(Constants.UI.cornerRadius)

                    // Destination path
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Destination Folder")
                            .font(.headline)
                        HStack {
                            TextField("Destination path", text: $viewModel.config.destinationPath)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                selectDestinationFolder()
                            }
                        }
                    }
                    .padding()
                    .background(Constants.Colors.cardBackgroundColor)
                    .cornerRadius(Constants.UI.cornerRadius)

                    // Age filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter Settings")
                            .font(.headline)
                        HStack {
                            Text("Backup files modified within:")
                            TextField(
                                "Days", value: $viewModel.config.ageFilterDays, format: .number
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: viewModel.config.ageFilterDays) { oldValue, newValue in
                                viewModel.updateAgeFilter(newValue)
                            }
                            Text("days")
                            Spacer()
                        }

                        Text("Files older than \(viewModel.formattedCutoffDate) will be ignored")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Constants.Colors.cardBackgroundColor)
                    .cornerRadius(Constants.UI.cornerRadius)
                }

                // Progress
                if viewModel.isRunning {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress) {
                            Text(viewModel.statusMessage)
                        }

                        Text("Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Constants.Colors.cardBackgroundColor)
                    .cornerRadius(Constants.UI.cornerRadius)
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
                    .background(Constants.Colors.errorColor.opacity(0.1))
                    .cornerRadius(Constants.UI.cornerRadius)
                }

                // Last backup info
                if let lastDate = viewModel.formattedLastBackupDate {
                    HStack {
                        Image(systemName: Constants.Icons.info)
                            .foregroundColor(Constants.Colors.infoColor)
                        Text("Last backup: \(lastDate)")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Constants.Colors.infoColor.opacity(0.1))
                    .cornerRadius(Constants.UI.cornerRadius)
                }

                Spacer()

                // Action buttons (at bottom)
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.scanPreview()
                        }
                    }) {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                    .disabled(
                        !viewModel.isConfigValid || viewModel.isScanning || viewModel.isRunning)

                    Button(action: {
                        Task {
                            await viewModel.runBackup()
                        }
                    }) {
                        Label("Move Files", systemImage: "arrow.right.circle.fill")
                    }
                    .disabled(
                        !viewModel.isConfigValid || viewModel.isRunning
                            || viewModel.previewResult == nil
                    )
                    .buttonStyle(.borderedProminent)

                    Button("View History") {
                        showingHistory = true
                    }
                }
            }
            .padding()
            .frame(minWidth: 400)

            // Right: Preview or Last backup results
            if let preview = viewModel.previewResult {
                BackupPreviewView(preview: preview)
            } else if let record = viewModel.lastBackupRecord {
                BackupResultView(record: record)
            } else {
                VStack {
                    Image(systemName: Constants.Icons.backup)
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Click 'Scan' to preview files")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingHistory) {
            BackupHistoryView(viewModel: viewModel)
        }
    }

    // MARK: - Helper Methods

    private func selectSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Source Folder"
        panel.message = "Choose the folder to move files from"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.updateSourcePath(url.path)
            }
        }
    }

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Destination Folder"
        panel.message = "Choose the folder to move files to"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.updateDestinationPath(url.path)
            }
        }
    }
}

// MARK: - Backup Result View

struct BackupResultView: View {
    let record: BackupRecord

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: record.statusIcon)
                .font(.system(size: 64))
                .foregroundColor(
                    record.success ? Constants.Colors.successColor : Constants.Colors.errorColor)

            Text(record.success ? "Move Complete" : "Move Failed")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Files Moved", value: "\(record.filesMoved)")
                InfoRow(label: "Repos Moved", value: "\(record.reposMoved)")
                InfoRow(label: "Total Size", value: record.formattedSize)
                InfoRow(label: "Duration", value: record.formattedDuration)
                InfoRow(label: "Timestamp", value: record.timestamp.dateTimeString())

                if let error = record.errorMessage {
                    InfoRow(label: "Error", value: error)
                        .foregroundColor(Constants.Colors.errorColor)
                }
            }
            .padding()
            .background(Constants.Colors.cardBackgroundColor)
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Backup Preview View

struct BackupPreviewView: View {
    @ObservedObject var preview: BackupPreviewResult

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Preview & Select Items")
                    .font(.title3)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected:")
                            .fontWeight(.semibold)
                        Text("\(preview.totalCount) of \(preview.allCount) items")
                        Spacer()
                        Text(
                            ByteCountFormatter.string(
                                fromByteCount: preview.totalSize, countStyle: .file)
                        )
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Constants.Colors.cardBackgroundColor)
                .cornerRadius(Constants.UI.cornerRadius)
            }
            .padding(.horizontal)

            // Tree view
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !preview.repoItems.isEmpty {
                        PreviewSection(
                            title: "📦 Repositories (\(preview.repoItems.count))",
                            items: preview.repoItems)
                    }

                    if !preview.fileItems.isEmpty {
                        PreviewSection(
                            title: "📄 Individual Files (\(preview.fileItems.count))",
                            items: preview.fileItems)
                    }
                }
                .padding(.horizontal)
            }

            Text("Select items and click 'Move Files' to proceed")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview Section

struct PreviewSection: View {
    let title: String
    let items: [SelectableItem]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            if isExpanded {
                ForEach(items) { item in
                    PreviewItemRow(item: item)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview Item Row

struct PreviewItemRow: View {
    @ObservedObject var item: SelectableItem

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $item.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Image(systemName: item.isRepo ? "folder.fill" : "doc.fill")
                .foregroundColor(item.isRepo ? .blue : .gray)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileInfo.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.fileInfo.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Text(
                        ByteCountFormatter.string(
                            fromByteCount: item.fileInfo.size, countStyle: .file)
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(item.fileInfo.modifiedDate.dateTimeString())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.leading, 24)
        .background(item.isSelected ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
