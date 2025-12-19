//
//  DiskAnalyzerView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct DiskAnalyzerView: View {
    @ObservedObject var viewModel: DiskAnalyzerViewModel
    @State private var showingFolderPicker = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            DiskAnalyzerToolbar(
                viewModel: viewModel,
                showingFolderPicker: $showingFolderPicker
            )

            Divider()

            // Content
            if viewModel.isScanning && viewModel.rootFileInfo == nil {
                // Initial scan - show progress
                VStack {
                    Spacer()
                    ProgressView(value: viewModel.scanProgress) {
                        Text(viewModel.scanMessage)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.errorMessage = nil
                }
            } else {
                switch viewModel.viewMode {
                case .list:
                    FileListView(viewModel: viewModel)
                case .tree:
                    TreeHierarchyView(viewModel: viewModel)
                case .treeMap:
                    TreeMapView(files: viewModel.displayedFiles)
                }
            }

            Divider()

            // Status bar
            StatusBarView(viewModel: viewModel)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing security-scoped resource
                    let didStart = url.startAccessingSecurityScopedResource()

                    Task {
                        await viewModel.scanDirectory(path: url.path)

                        // Stop accessing when done
                        if didStart {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Delete Files", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelectedFiles()
                }
            }
        } message: {
            Text("Are you sure you want to move \(viewModel.selectedFiles.count) items to trash?")
        }
        .onAppear {
            Task {
                await viewModel.performInitialScanIfNeeded()
            }
        }
    }
}

// MARK: - Toolbar

struct DiskAnalyzerToolbar: View {
    @ObservedObject var viewModel: DiskAnalyzerViewModel
    @Binding var showingFolderPicker: Bool

    private var viewModeIcon: String {
        switch viewModel.viewMode {
        case .list: return "list.bullet"
        case .tree: return "list.bullet.indent"
        case .treeMap: return "chart.bar.xaxis"
        }
    }

    var body: some View {
        HStack {
            // Path and scan button
            TextField("Path to scan", text: $viewModel.currentPath)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)
                .focusable(false)
                .focusEffectDisabled()

            Button("Browse...") {
                showingFolderPicker = true
            }

            Button(action: {
                Task {
                    await viewModel.scanDirectory(path: viewModel.currentPath)
                }
            }) {
                Label("Scan", systemImage: "play.fill")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.currentPath.isEmpty || viewModel.isScanning)

            Divider()
                .frame(height: 20)

            // View mode selector
            Menu {
                Button(action: { viewModel.viewMode = .list }) {
                    Label("List View", systemImage: "list.bullet")
                }
                Button(action: { viewModel.viewMode = .tree }) {
                    Label("Tree View", systemImage: "list.bullet.indent")
                }
                Button(action: { viewModel.viewMode = .treeMap }) {
                    Label("TreeMap", systemImage: "chart.bar.xaxis")
                }
            } label: {
                Image(systemName: viewModeIcon)
            }
            .menuStyle(.borderlessButton)
            .help("Change view mode")

            // Sort menu
            Menu {
                Button("Name") { viewModel.changeSortOrder(to: .name) }
                Button("Size") { viewModel.changeSortOrder(to: .size) }
                Button("Date") { viewModel.changeSortOrder(to: .date) }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)

            Spacer()

            // Selection actions
            if !viewModel.selectedFiles.isEmpty {
                Text("\(viewModel.selectedFiles.count) selected")
                    .foregroundColor(.secondary)

                Button(action: {
                    Task {
                        await viewModel.deleteSelectedFiles()
                    }
                }) {
                    Image(systemName: Constants.Icons.trash)
                }
                .foregroundColor(.red)

                Button("Deselect All") {
                    viewModel.deselectAll()
                }
            }
        }
        .padding()
    }
}

// MARK: - Status Bar

struct StatusBarView: View {
    @ObservedObject var viewModel: DiskAnalyzerViewModel

    var body: some View {
        HStack {
            Text("\(viewModel.fileCount) items")
            Divider()
                .frame(height: 16)
            Text("Total: \(viewModel.formattedTotalSize)")
            Spacer()

            // Show progress when calculating sizes
            if viewModel.isScanning && viewModel.totalItemsCount > 0 {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 12, height: 12)
                    Text(
                        "\(viewModel.calculatedItemsCount)/\(viewModel.totalItemsCount) calculated"
                    )
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                }
            } else if !viewModel.scanMessage.isEmpty {
                Text(viewModel.scanMessage)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Constants.Colors.backgroundColor)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: Constants.Icons.error)
                .font(.system(size: 64))
                .foregroundColor(Constants.Colors.errorColor)

            Text("Error")
                .font(.title)
                .fontWeight(.bold)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Dismiss") {
                onDismiss()
            }
        }
        .padding()
    }
}
