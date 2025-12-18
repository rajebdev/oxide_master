import SwiftUI

struct OrphanedFilesView: View {
    @ObservedObject var viewModel: AppUninstallerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedOrphaned: Set<OrphanedFiles.ID> = []
    @State private var showingCleanConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView

                Divider()

                // Content
                if viewModel.isScanning {
                    scanningView
                } else if viewModel.orphanedFiles.isEmpty {
                    emptyView
                } else {
                    orphanedListView
                }
            }
            .navigationTitle("Orphaned Files")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.scanOrphaned()
                        }
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .alert("Clean Selected Files", isPresented: $showingCleanConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clean", role: .destructive) {
                    cleanSelected()
                }
            } message: {
                Text(
                    "This will move \(selectedOrphaned.count) item(s) to Trash. You can restore them from Trash if needed."
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            if viewModel.orphanedFiles.isEmpty {
                await viewModel.scanOrphaned()
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.orphanedFiles.count) Orphaned Items")
                    .font(.headline)
                Text(viewModel.totalOrphanedSize.formatted(.byteCount(style: .file)))
                    .font(.title2)
                    .bold()
                    .foregroundColor(.orange)
            }

            Spacer()

            if !selectedOrphaned.isEmpty {
                Button {
                    showingCleanConfirm = true
                } label: {
                    Label("Clean Selected (\(selectedOrphaned.count))", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
    }

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(viewModel.scanProgress)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Orphaned Files",
            systemImage: "checkmark.circle",
            description: Text(
                "Your system is clean! No leftover files from uninstalled apps were found.")
        )
    }

    private var orphanedListView: some View {
        List(viewModel.orphanedFiles, selection: $selectedOrphaned) { orphaned in
            OrphanedItemRow(orphaned: orphaned) {
                Task {
                    await viewModel.cleanOrphanedFiles(orphaned)
                }
            }
        }
        .listStyle(.plain)
    }

    private func cleanSelected() {
        Task {
            for id in selectedOrphaned {
                if let orphaned = viewModel.orphanedFiles.first(where: { $0.id == id }) {
                    await viewModel.cleanOrphanedFiles(orphaned)
                }
            }
            selectedOrphaned.removeAll()
        }
    }
}

struct OrphanedItemRow: View {
    let orphaned: OrphanedFiles
    let onClean: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.app.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(orphaned.appName)
                        .font(.headline)

                    Text(orphaned.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(
                        "\(orphaned.files.count) files • \(orphaned.totalSize.formatted(.byteCount(style: .file)))"
                    )
                    .font(.caption)
                    .foregroundColor(.blue)
                }

                Spacer()

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onClean()
                } label: {
                    Label("Clean", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(orphaned.files) { file in
                        HStack {
                            Image(systemName: file.category.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 15)

                            Text(file.path.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(file.size.formatted(.byteCount(style: .file)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 40)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}
