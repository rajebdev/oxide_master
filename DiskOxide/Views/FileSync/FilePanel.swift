//
//  FilePanel.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI
import UniformTypeIdentifiers

struct FilePanel: View {
    let title: String
    @Binding var path: String
    let files: [FileInfo]
    @Binding var selectedFiles: Set<String>
    let isLoading: Bool
    let sortOption: SortOption
    let sortOrder: SortOrder
    let onNavigate: (String) -> Void
    let onNavigateToFolder: (String) -> Void  // For synchronized folder navigation
    let onNavigateToParent: () -> Void  // For synchronized parent navigation
    let onToggleSelection: (String) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onReveal: (String) -> Void
    let onDropFiles: ([URL]) -> Void
    let onSort: (SortOption) -> Void

    @State private var showingFolderPicker = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .fontWeight(.semibold)

                Spacer()

                if !selectedFiles.isEmpty {
                    Text("\(selectedFiles.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Deselect All") {
                        onDeselectAll()
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Constants.Colors.cardBackgroundColor)

            // Path navigation
            HStack {
                TextField(
                    "Path", text: $path,
                    onCommit: {
                        onNavigate(path)
                    }
                )
                .textFieldStyle(.roundedBorder)

                Button(action: {
                    showingFolderPicker = true
                }) {
                    Image(systemName: "folder")
                }

                Button(action: {
                    onNavigateToParent()
                }) {
                    Image(systemName: "arrow.up")
                }

                Button(action: {
                    onNavigate(path)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()

            Divider()

            // Sorting header
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundColor(.clear)
                    .frame(width: 20)

                Button(action: { onSort(.name) }) {
                    HStack(spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(sortOption == .name ? .primary : .secondary)
                        if sortOption == .name {
                            Image(
                                systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down"
                            )
                            .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { onSort(.size) }) {
                    HStack(spacing: 4) {
                        Text("Size")
                            .font(.caption)
                            .foregroundColor(sortOption == .size ? .primary : .secondary)
                        if sortOption == .size {
                            Image(
                                systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down"
                            )
                            .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 80, alignment: .trailing)

                Button(action: { onSort(.dateModified) }) {
                    HStack(spacing: 4) {
                        Text("Modified")
                            .font(.caption)
                            .foregroundColor(sortOption == .dateModified ? .primary : .secondary)
                        if sortOption == .dateModified {
                            Image(
                                systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down"
                            )
                            .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 140, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Constants.Colors.cardBackgroundColor.opacity(0.5))

            Divider()

            // File list
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if files.isEmpty {
                    VStack {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No files")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(files) { file in
                                FilePanelRow(
                                    file: file,
                                    isSelected: selectedFiles.contains(file.path),
                                    onToggleSelection: {
                                        onToggleSelection(file.path)
                                    },
                                    onDoubleClick: {
                                        if file.isDirectory {
                                            onNavigateToFolder(file.name)
                                        }
                                    },
                                    onReveal: {
                                        onReveal(file.path)
                                    }
                                )

                                Divider()
                            }
                        }
                    }
                }
            }
            .background(isDropTargeted ? Constants.Colors.primaryColor.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        isDropTargeted ? Constants.Colors.primaryColor : Color.clear,
                        lineWidth: 3
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                Task {
                    var urls: [URL] = []
                    for provider in providers {
                        if let url = try? await provider.loadItem(
                            forTypeIdentifier: UTType.fileURL.identifier, options: nil) as? Data,
                            let urlString = String(data: url, encoding: .utf8),
                            let fileURL = URL(string: urlString)
                        {
                            urls.append(fileURL)
                        }
                    }
                    if !urls.isEmpty {
                        onDropFiles(urls)
                    }
                }
                return true
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                path = url.path
                onNavigate(url.path)
            }
        }
    }
}

// MARK: - File Panel Row

struct FilePanelRow: View {
    let file: FileInfo
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onDoubleClick: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.iconName)
                .foregroundColor(Color(hex: file.typeColor))
                .frame(width: 20)

            Text(file.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(file.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            Text(formattedDate(file.modifiedDate))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Constants.Colors.primaryColor.opacity(0.1)
                : (isHovering ? Color.gray.opacity(0.1) : Color.clear)
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .onTapGesture {
            onToggleSelection()
        }
        .onDrag {
            isDragging = true
            let url = URL(fileURLWithPath: file.path)
            let provider = NSItemProvider(object: url as NSURL)
            provider.suggestedName = file.name
            return provider
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            if file.isDirectory {
                Button("Open") {
                    onDoubleClick()
                }
            }

            Button("Reveal in Finder") {
                onReveal()
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}
