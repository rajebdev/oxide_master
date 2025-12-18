//
//  FilePanel.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI

struct FilePanel: View {
    let title: String
    @Binding var path: String
    let files: [FileInfo]
    @Binding var selectedFiles: Set<String>
    let isLoading: Bool
    let onNavigate: (String) -> Void
    let onToggleSelection: (String) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onReveal: (String) -> Void
    
    @State private var showingFolderPicker = false
    
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
                TextField("Path", text: $path, onCommit: {
                    onNavigate(path)
                })
                .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    showingFolderPicker = true
                }) {
                    Image(systemName: "folder")
                }
                
                Button(action: {
                    let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
                    onNavigate(parentPath)
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
            
            // File list
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
                                        onNavigate(file.path)
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
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isSelected ? Constants.Colors.primaryColor.opacity(0.1) : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
        .onTapGesture {
            onToggleSelection()
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
}

