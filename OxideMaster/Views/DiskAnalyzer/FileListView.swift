//
//  FileListView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: DiskAnalyzerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                FileListHeader(viewModel: viewModel)

                Divider()

                // Files
                ForEach(viewModel.displayedFiles) { file in
                    FileRow(
                        file: file,
                        isSelected: viewModel.selectedFiles.contains(file.path)
                    ) {
                        viewModel.toggleSelection(for: file.path)
                    } onDoubleClick: {
                        if file.isDirectory {
                            Task {
                                await viewModel.navigateToDirectory(file.path)
                            }
                        }
                    } onDelete: {
                        Task {
                            await viewModel.deleteFile(file.path)
                        }
                    } onReveal: {
                        viewModel.revealInFinder(file.path)
                    }

                    Divider()
                }
            }
        }
    }
}

// MARK: - File List Header

struct FileListHeader: View {
    @ObservedObject var viewModel: DiskAnalyzerViewModel

    var body: some View {
        HStack {
            Button(action: { viewModel.changeSortOrder(to: .name) }) {
                HStack {
                    Text("Name")
                        .fontWeight(.semibold)
                    if viewModel.sortOrder == .name {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { viewModel.changeSortOrder(to: .size) }) {
                HStack {
                    Text("Size")
                        .fontWeight(.semibold)
                    if viewModel.sortOrder == .size {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
            }
            .frame(width: 120, alignment: .trailing)

            Button(action: { viewModel.changeSortOrder(to: .date) }) {
                HStack {
                    Text("Modified")
                        .fontWeight(.semibold)
                    if viewModel.sortOrder == .date {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding()
        .background(Constants.Colors.cardBackgroundColor)
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: FileInfo
    let isSelected: Bool
    let onClick: () -> Void
    let onDoubleClick: () -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            // Icon and name
            HStack(spacing: 8) {
                Image(systemName: file.iconName)
                    .foregroundColor(Color(hex: file.typeColor))

                Text(file.name)
                    .foregroundColor(file.textColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Size with loading indicator
            HStack(spacing: 4) {
                if file.isLoadingSize {
                    if file.sizeStatus == .calculating {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                    Text("calculating...")
                        .foregroundColor(.orange)
                } else {
                    Text(file.formattedSize)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, alignment: .trailing)

            // Modified date
            Text(file.modifiedDate.shortDateString())
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Constants.Colors.primaryColor.opacity(0.1)
                : (isHovering ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            onClick()
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

            Divider()

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}
