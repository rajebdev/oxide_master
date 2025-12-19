import SwiftUI

struct AppDetailView: View {
    let app: AppInfo
    let onClose: () -> Void
    let onAction: (AppAction) -> Void

    @State private var showingUninstallConfirm = false
    @State private var uninstallOption: UninstallOption = .complete

    enum UninstallOption: String, CaseIterable {
        case complete = "Complete Uninstall"
        case appOnly = "App Only"
        case filesOnly = "Clean Files Only"

        var description: String {
            switch self {
            case .complete:
                return "Remove app bundle, related files, and login items"
            case .appOnly:
                return "Remove app bundle only, keep settings and files"
            case .filesOnly:
                return "Keep app, remove related files and login items"
            }
        }

        var icon: String {
            switch self {
            case .complete: return "trash.fill"
            case .appOnly: return "app.badge.minus"
            case .filesOnly: return "folder.badge.minus"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Scrollable Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    appHeader

                    Divider()

                    // Size Breakdown
                    sizeBreakdown

                    Divider()

                    // Related Files
                    if !app.relatedFiles.isEmpty {
                        relatedFilesSection
                        Divider()
                    }

                    // Login Items
                    if !app.loginItems.isEmpty {
                        loginItemsSection
                        Divider()
                    }

                    // Uninstall Options
                    uninstallSection
                }
                .padding()
            }

            // Floating close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .navigationTitle(app.name)
        .alert("Confirm Uninstall", isPresented: $showingUninstallConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) {
                performUninstall()
            }
        } message: {
            Text(uninstallConfirmMessage)
        }
    }

    private var appHeader: some View {
        VStack(spacing: 16) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 4) {
                Text(app.name)
                    .font(.title2)
                    .bold()

                Text("Version \(app.version)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            if app.isSystemApp {
                Label("System Application", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }

    private var sizeBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Size Breakdown")
                .font(.headline)

            // App Bundle
            SizeRow(
                icon: "app.fill",
                title: "App Bundle",
                size: app.appSize,
                color: Constants.Colors.primaryColor
            )

            // Related Files by Category
            let groupedFiles = Dictionary(grouping: app.relatedFiles) { $0.category }
            ForEach(RelatedFile.FileCategory.allCases, id: \.self) { category in
                if let files = groupedFiles[category] {
                    let totalSize = files.reduce(0) { $0 + $1.size }
                    SizeRow(
                        icon: category.icon,
                        title: category.rawValue,
                        size: totalSize,
                        color: .orange
                    )
                }
            }

            Divider()

            // Total
            SizeRow(
                icon: "sum",
                title: "Total Size",
                size: app.totalSize,
                color: .purple,
                bold: true
            )
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }

    private var relatedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Files (\(app.relatedFiles.count))")
                .font(.headline)

            ForEach(app.relatedFiles) { file in
                HStack {
                    Image(systemName: file.category.icon)
                        .foregroundColor(Constants.Colors.primaryColor)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.path.lastPathComponent)
                            .font(.body)
                        Text(file.path.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Text(file.size.formatted(.byteCount(style: .file)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }

    private var loginItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Login Items (\(app.loginItems.count))")
                    .font(.headline)
            }

            Text("This app runs automatically at login")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(app.loginItems) { item in
                HStack {
                    Image(systemName: "power")
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.type.rawValue)
                            .font(.body)
                        Text(item.path.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(item.isEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                .padding(8)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }

    private var uninstallSection: some View {
        VStack(spacing: 16) {
            Text("Uninstall Options")
                .font(.headline)

            ForEach(UninstallOption.allCases, id: \.self) { option in
                Button {
                    uninstallOption = option
                    showingUninstallConfirm = true
                } label: {
                    HStack {
                        Image(systemName: option.icon)
                            .font(.title3)
                            .foregroundColor(
                                option == .complete ? .red : Constants.Colors.primaryColor
                            )
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.rawValue)
                                .font(.headline)
                            Text(option.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(app.isSystemApp && option != .filesOnly)
            }

            if app.isSystemApp {
                Label("System apps can only have their files cleaned", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }

            if let lastUsed = app.lastUsedDate {
                Text("Last used: \(lastUsed.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var uninstallConfirmMessage: String {
        switch uninstallOption {
        case .complete:
            return
                "This will permanently remove \(app.name) and all related files (\(app.totalSize.formatted(.byteCount(style: .file)))). Items will be moved to Trash."
        case .appOnly:
            return
                "This will remove only the app bundle (\(app.appSize.formatted(.byteCount(style: .file)))). Settings and related files will be kept."
        case .filesOnly:
            let filesSize = app.relatedFiles.reduce(0) { $0 + $1.size }
            return
                "This will clean related files (\(filesSize.formatted(.byteCount(style: .file)))) but keep the app."
        }
    }

    private func performUninstall() {
        switch uninstallOption {
        case .complete:
            onAction(.uninstallComplete)
        case .appOnly:
            onAction(.uninstallAppOnly)
        case .filesOnly:
            onAction(.cleanFiles)
        }
    }
}

struct SizeRow: View {
    let icon: String
    let title: String
    let size: Int64
    let color: Color
    var bold: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(title)
                .font(bold ? .headline : .body)

            Spacer()

            Text(size.formatted(.byteCount(style: .file)))
                .font(bold ? .headline : .body)
                .foregroundColor(color)
        }
    }
}
