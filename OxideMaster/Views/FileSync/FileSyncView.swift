//
//  FileSyncView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct FileSyncView: View {
    @ObservedObject var viewModel: FileSyncViewModel
    @State private var showingSaveSession = false
    @State private var sessionName = ""

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Toolbar
                FileSyncToolbar(viewModel: viewModel, showingSaveSession: $showingSaveSession)

                Divider()

                // Dual panes
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left pane
                        FilePanel(
                            title: "Left Panel",
                            path: $viewModel.leftPanelPath,
                            files: viewModel.leftPanelFiles,
                            selectedFiles: $viewModel.leftSelectedFiles,
                            isLoading: viewModel.isLoadingLeft,
                            sortOption: viewModel.leftSortOption,
                            sortOrder: viewModel.leftSortOrder,
                            onNavigate: { path in
                                Task {
                                    await viewModel.navigateLeft(to: path)
                                }
                            },
                            onNavigateToFolder: { folderName in
                                Task {
                                    await viewModel.navigateToBothPanels(subfolder: folderName)
                                }
                            },
                            onNavigateToParent: {
                                Task {
                                    await viewModel.navigateToParentBoth()
                                }
                            },
                            onToggleSelection: { path in
                                viewModel.toggleLeftSelection(path)
                            },
                            onSelectAll: {
                                viewModel.selectAllLeft()
                            },
                            onDeselectAll: {
                                viewModel.deselectAllLeft()
                            },
                            onReveal: { path in
                                viewModel.revealInFinder(path)
                            },
                            onDropFiles: { urls in
                                Task {
                                    await viewModel.handleDroppedFiles(urls, toPanel: .left)
                                }
                            },
                            onSort: { option in
                                viewModel.setSortLeft(by: option)
                            }
                        )
                        .frame(width: (geometry.size.width - 80) / 2)

                        // Center buttons
                        VStack(spacing: 16) {
                            Spacer()

                            Button(action: {
                                Task {
                                    await viewModel.copyLeftToRight()
                                }
                            }) {
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                            }
                            .disabled(viewModel.leftSelectedFiles.isEmpty)
                            .help("Copy selected files to right →")

                            Button(action: {
                                Task {
                                    await viewModel.moveLeftToRight()
                                }
                            }) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.title2)
                            }
                            .disabled(viewModel.leftSelectedFiles.isEmpty)
                            .help("Move selected files to right →")

                            Divider()
                                .frame(width: 30)

                            Button(action: {
                                Task {
                                    await viewModel.copyRightToLeft()
                                }
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                            }
                            .disabled(viewModel.rightSelectedFiles.isEmpty)
                            .help("← Copy selected files to left")

                            Button(action: {
                                Task {
                                    await viewModel.moveRightToLeft()
                                }
                            }) {
                                Image(systemName: "arrow.left.circle")
                                    .font(.title2)
                            }
                            .disabled(viewModel.rightSelectedFiles.isEmpty)
                            .help("← Move selected files to left")

                            Spacer()
                        }
                        .frame(width: 80)
                        .background(Constants.Colors.cardBackgroundColor)

                        // Right pane
                        FilePanel(
                            title: "Right Panel",
                            path: $viewModel.rightPanelPath,
                            files: viewModel.rightPanelFiles,
                            selectedFiles: $viewModel.rightSelectedFiles,
                            isLoading: viewModel.isLoadingRight,
                            sortOption: viewModel.rightSortOption,
                            sortOrder: viewModel.rightSortOrder,
                            onNavigate: { path in
                                Task {
                                    await viewModel.navigateRight(to: path)
                                }
                            },
                            onNavigateToFolder: { folderName in
                                Task {
                                    await viewModel.navigateToBothPanels(subfolder: folderName)
                                }
                            },
                            onNavigateToParent: {
                                Task {
                                    await viewModel.navigateToParentBoth()
                                }
                            },
                            onToggleSelection: { path in
                                viewModel.toggleRightSelection(path)
                            },
                            onSelectAll: {
                                viewModel.selectAllRight()
                            },
                            onDeselectAll: {
                                viewModel.deselectAllRight()
                            },
                            onReveal: { path in
                                viewModel.revealInFinder(path)
                            },
                            onDropFiles: { urls in
                                Task {
                                    await viewModel.handleDroppedFiles(urls, toPanel: .right)
                                }
                            },
                            onSort: { option in
                                viewModel.setSortRight(by: option)
                            }
                        )
                        .frame(width: (geometry.size.width - 80) / 2)
                    }
                }

                Divider()

                // Status bar
                if !viewModel.statusMessage.isEmpty || viewModel.isOperating {
                    HStack(spacing: 12) {
                        if viewModel.isOperating {
                            ProgressView(value: viewModel.operationProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 250)

                            Text("\(Int(viewModel.operationProgress * 100))%")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(width: 40, alignment: .trailing)
                        }

                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Constants.Colors.backgroundColor)
                }
            }
            .sheet(isPresented: $showingSaveSession) {
                SaveSessionView(sessionName: $sessionName) {
                    viewModel.saveSession(name: sessionName)
                    sessionName = ""
                    showingSaveSession = false
                }
            }
            .onAppear {
                Task {
                    if !viewModel.showSetup {
                        await viewModel.loadLeftPanel()
                        await viewModel.loadRightPanel()
                    }
                }
            }

            // Setup Modal Overlay
            if viewModel.showSetup {
                SyncSetupView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - File Sync Toolbar

struct FileSyncToolbar: View {
    @ObservedObject var viewModel: FileSyncViewModel
    @Binding var showingSaveSession: Bool

    var body: some View {
        HStack {
            // Sessions menu
            Menu("Sessions") {
                ForEach(viewModel.sessions) { session in
                    Button(session.name) {
                        Task {
                            await viewModel.loadSession(session)
                        }
                    }
                }

                if !viewModel.sessions.isEmpty {
                    Divider()
                }

                Button("Save Current Session...") {
                    showingSaveSession = true
                }
            }

            Spacer()

            // Current session indicator
            if let session = viewModel.currentSession {
                Text("Session: \(session.name)")
                    .foregroundColor(.secondary)
            }

            // Change button
            Button(action: {
                viewModel.resetToSetup()
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Change")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Save Session View

struct SaveSessionView: View {
    @Binding var sessionName: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Session")
                .font(.title2)
                .fontWeight(.bold)

            TextField("Session name", text: $sessionName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    onSave()
                }
                .disabled(sessionName.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
