//
//  SyncSetupView.swift
//  OxideMaster
//
//  Created on 2025-12-18.
//

import SwiftUI

struct SyncSetupView: View {
    @ObservedObject var viewModel: FileSyncViewModel
    @State private var selectedMode: SetupMode = .newSetup
    @State private var sourcePath: String = ""
    @State private var destPath: String = ""

    enum SetupMode {
        case newSetup
        case fromHistory
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Modal Container
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                        .foregroundColor(Constants.Colors.primaryColor)
                    Text("Setup File Synchronization")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Constants.Colors.cardBackgroundColor)

                Divider()

                // Mode Tabs
                HStack(spacing: 0) {
                    Button(action: {
                        selectedMode = .newSetup
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                            Text("New Setup")
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selectedMode == .newSetup ? Constants.Colors.primaryColor : Color.clear
                        )
                        .foregroundColor(selectedMode == .newSetup ? .white : .primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        selectedMode = .fromHistory
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("From History")
                                .font(.body)
                            if !viewModel.sessions.isEmpty {
                                Text("\(viewModel.sessions.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.3))
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selectedMode == .fromHistory
                                ? Constants.Colors.primaryColor : Color.clear
                        )
                        .foregroundColor(selectedMode == .fromHistory ? .white : .primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.sessions.isEmpty)
                }
                .background(Constants.Colors.cardBackgroundColor)

                Divider()

                // Content
                ScrollView {
                    if selectedMode == .newSetup {
                        newSetupView
                    } else {
                        historyView
                    }
                }
                .frame(maxHeight: 380)
            }
            .frame(width: 580)
            .background(Constants.Colors.backgroundColor)
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }

    private var newSetupView: some View {
        VStack(spacing: 20) {
            // Source Folder
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.body)
                        .foregroundColor(Constants.Colors.primaryColor)
                    Text("Source Folder")
                        .font(.body)
                        .fontWeight(.medium)
                }

                HStack(spacing: 12) {
                    TextField("No folder selected", text: $sourcePath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button(action: {
                        selectSourceFolder()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Browse")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(Constants.Colors.cardBackgroundColor)
            .cornerRadius(8)

            // Arrow
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary.opacity(0.6))

            // Destination Folder
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill.badge.checkmark")
                        .font(.body)
                        .foregroundColor(.green)
                    Text("Destination Folder")
                        .font(.body)
                        .fontWeight(.medium)
                }

                HStack(spacing: 12) {
                    TextField("No folder selected", text: $destPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button(action: {
                        selectDestinationFolder()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Browse")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(Constants.Colors.cardBackgroundColor)
            .cornerRadius(8)

            Spacer()
                .frame(height: 12)

            // Start Button
            Button(action: {
                Task {
                    await viewModel.startNewSession(leftPath: sourcePath, rightPath: destPath)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Synchronization")
                        .font(.body)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    sourcePath.isEmpty || destPath.isEmpty
                        ? Color.gray : Constants.Colors.primaryColor
                )
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(sourcePath.isEmpty || destPath.isEmpty)
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    // MARK: - Helper Methods

    private func selectSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Select Source Folder"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            if let url = panel.url {
                sourcePath = url.path
            }
        }
    }

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Select Destination Folder"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            if let url = panel.url {
                destPath = url.path
            }
        }
    }

    private var historyView: some View {
        VStack(spacing: 12) {
            if viewModel.sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No sync history available")
                        .foregroundColor(.secondary)
                    Text("Create a new sync to get started")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(viewModel.sessions) { session in
                    SessionCard(session: session) {
                        Task {
                            await viewModel.loadSession(session)
                        }
                    } onDelete: {
                        viewModel.deleteSession(session)
                    }
                }
            }
        }
        .padding(20)
    }
}

struct SessionCard: View {
    let session: SyncSession
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Paths
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.primaryColor)
                    Text(session.leftPanelPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "folder.fill.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(session.rightPanelPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Timestamp
                Text(session.lastUsedDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Load")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Constants.Colors.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHovering ? Constants.Colors.primaryColor : Color.gray.opacity(0.2),
                            lineWidth: 1)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
