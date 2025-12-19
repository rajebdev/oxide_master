//
//  TreeHierarchyView.swift
//  OxideMaster
//
//  Created on 2025-12-18.
//

import SwiftUI

/// Hierarchical tree view like Windows Explorer/WinDirStat
struct TreeHierarchyView: View {
    @ObservedObject var viewModel: DiskAnalyzerViewModel
    @State private var expandedPaths: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header with loaded info
            if let rootInfo = viewModel.rootFileInfo {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(
                        "Loaded: \(rootInfo.totalFileCount) items | Size: \(rootInfo.formattedSize)"
                    )
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
            }

            // Directory tree header
            HStack {
                Image(systemName: "folder.fill")
                Text("Directory Tree")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tree content
            ScrollView {
                if let rootInfo = viewModel.rootFileInfo {
                    TreeNodeView(
                        file: rootInfo,
                        viewModel: viewModel,
                        expandedPaths: $expandedPaths,
                        depth: 0
                    )
                    .onAppear {
                        // Auto-expand root folder on first load
                        if expandedPaths.isEmpty {
                            expandedPaths.insert(rootInfo.path)
                        }
                    }
                } else {
                    EmptyStateView()
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Tree Node View

struct TreeNodeView: View {
    let file: FileInfo
    @ObservedObject var viewModel: DiskAnalyzerViewModel
    @Binding var expandedPaths: Set<String>
    let depth: Int

    @State private var isHovering = false

    var isExpanded: Bool {
        expandedPaths.contains(file.path)
    }

    var isSelected: Bool {
        viewModel.selectedFiles.contains(file.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<depth, id: \.self) { _ in
                    Color.clear
                        .frame(width: 16)
                }

                // Expand/collapse button
                if file.isDirectory {
                    Button(action: toggleExpand) {
                        Image(systemName: isExpanded ? "minus.square" : "plus.square")
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 16, height: 16)
                }

                // Icon
                Image(systemName: file.iconName)
                    .foregroundColor(Color(hex: file.typeColor))
                    .frame(width: 16)

                // File name
                Text(file.name)
                    .font(.system(size: 12))
                    .foregroundColor(file.textColor)
                    .lineLimit(1)

                Spacer()

                // Percentage bar
                if let rootSize = viewModel.rootFileInfo?.totalSize, rootSize > 0 {
                    HStack(spacing: 6) {
                        // Percentage bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 12)

                                Rectangle()
                                    .fill(Color(hex: file.typeColor))
                                    .frame(
                                        width: geo.size.width * CGFloat(file.totalSize)
                                            / CGFloat(rootSize),
                                        height: 12
                                    )
                            }
                            .cornerRadius(2)
                        }
                        .frame(width: 150, height: 12)

                        // Percentage text
                        Text(
                            String(
                                format: "%.2f%%", Double(file.totalSize) * 100.0 / Double(rootSize))
                        )
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    }
                }

                // Size with loading indicator
                HStack(spacing: 4) {
                    if file.isLoadingSize {
                        Text("calculating...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                    } else {
                        Text(file.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, alignment: .trailing)

                // Permissions
                Text(file.permissions)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .trailing)

                // Delete button (visible on hover)
                if isHovering {
                    Button(action: {
                        viewModel.selectedFiles = [file.path]
                        Task {
                            await viewModel.deleteSelectedFiles()
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 16)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(backgroundColor)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                toggleSelection()
            }
            .contextMenu {
                contextMenuItems
            }

            // Children (if expanded)
            if isExpanded && !file.children.isEmpty {
                ForEach(file.children) { child in
                    TreeNodeView(
                        file: child,
                        viewModel: viewModel,
                        expandedPaths: $expandedPaths,
                        depth: depth + 1
                    )
                }
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Constants.Colors.primaryColor.opacity(0.3)
        } else if isHovering {
            return Color.secondary.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private var contextMenuItems: some View {
        Group {
            Button("Reveal in Finder") {
                revealInFinder()
            }

            Divider()

            Button("Delete", role: .destructive) {
                viewModel.selectedFiles = [file.path]
                Task {
                    await viewModel.deleteSelectedFiles()
                }
            }
        }
    }

    private func toggleExpand() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedPaths.remove(file.path)
            } else {
                expandedPaths.insert(file.path)

                // Lazy load children if directory is being expanded
                if file.isDirectory && file.children.isEmpty {
                    Task {
                        await viewModel.loadChildren(for: file)
                    }
                }
            }
        }
    }

    private func toggleSelection() {
        if isSelected {
            viewModel.selectedFiles.remove(file.path)
        } else {
            viewModel.selectedFiles.insert(file.path)
        }
    }

    private func revealInFinder() {
        let url = URL(fileURLWithPath: file.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No directory scanned")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Click 'Browse...' to select a directory")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// Preview not available in SPM
