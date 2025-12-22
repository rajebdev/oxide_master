import SwiftUI

struct UninstallationLogsView: View {
    let logs: [String]
    let isCleaning: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Constants.Colors.primaryColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Uninstallation Log")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Real-time uninstallation progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isCleaning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)

                    Text("Uninstalling...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Log Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)

                                Text(log)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(logColor(for: log))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(index)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: logs.count) {
                    // Auto-scroll to bottom when new log is added
                    if let lastIndex = logs.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(logs.count) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    copyLogsToClipboard()
                }) {
                    Label("Copy Logs", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    dismiss()
                }) {
                    Text(isCleaning ? "Close" : "Done")
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.primaryColor)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
    }

    private func logColor(for log: String) -> Color {
        if log.contains("✅") || log.contains("✓") || log.contains("Successfully") {
            return .green
        } else if log.contains("❌") || log.contains("Error") || log.contains("failed") {
            return .red
        } else if log.contains("⚠️") || log.contains("Warning") {
            return .orange
        } else if log.contains("🗑️") || log.contains("📦") || log.contains("🧹") || log.contains("📂") || log.contains("📍") {
            return Constants.Colors.primaryColor
        } else {
            return .primary
        }
    }

    private func copyLogsToClipboard() {
        let logText = logs.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
    }
}
