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
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(Constants.Colors.primaryColor)
                    Text("Setup File Synchronization")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding()
                .background(Constants.Colors.cardBackgroundColor)

                Divider()

                // Mode Tabs
                HStack(spacing: 0) {
                    Button(action: {
                        selectedMode = .newSetup
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("New Setup")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
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
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("From History")
                            if !viewModel.sessions.isEmpty {
                                Text("\(viewModel.sessions.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.3))
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
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
                .frame(maxHeight: 400)
            }
            .frame(width: 600)
            .background(Constants.Colors.backgroundColor)
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }

    private var newSetupView: some View {
        VStack(spacing: 20) {
            // Source Folder
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(Constants.Colors.primaryColor)
                    Text("Source Folder")
                        .fontWeight(.semibold)
                }

                HStack {
                    TextField("No folder selected", text: $sourcePath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button(action: {
                        selectSourceFolder()
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .padding(8)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Arrow
            Image(systemName: "arrow.down.circle.fill")
                .font(.title)
                .foregroundColor(.secondary)

            // Destination Folder
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder.fill.badge.checkmark")
                        .foregroundColor(.green)
                    Text("Destination Folder")
                        .fontWeight(.semibold)
                }

                HStack {
                    TextField("No folder selected", text: $destPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button(action: {
                        selectDestinationFolder()
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .padding(8)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Start Button
            Button(action: {
                Task {
                    await viewModel.startNewSession(leftPath: sourcePath, rightPath: destPath)
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Synchronization")
                }
                .frame(maxWidth: .infinity)
                .padding()
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
        .padding()
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
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No sync history available")
                        .foregroundColor(.secondary)
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
        .padding()
    }
}

struct SessionCard: View {
    let session: SyncSession
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Paths
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(Constants.Colors.primaryColor)
                    Text(session.leftPanelPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "folder.fill.badge.checkmark")
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
            }

            Spacer()

            // Delete button (shows on hover)
            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovering
                        ? Constants.Colors.cardBackgroundColor : Constants.Colors.backgroundColor
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHovering ? Constants.Colors.primaryColor : Color.gray.opacity(0.3),
                            lineWidth: 1)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}
