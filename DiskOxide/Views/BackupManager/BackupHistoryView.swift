//
//  BackupHistoryView.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI

struct BackupHistoryView: View {
    @ObservedObject var viewModel: BackupManagerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Backup History")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Clear History") {
                    viewModel.clearHistory()
                }
                .disabled(viewModel.history.isEmpty)

                Button("Close") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // History list
            if viewModel.history.isEmpty {
                VStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("No backup history")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.history) { record in
                    BackupHistoryRow(record: record)
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Backup History Row

struct BackupHistoryRow: View {
    let record: BackupRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: record.statusIcon)
                    .foregroundColor(
                        record.success ? Constants.Colors.successColor : Constants.Colors.errorColor
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.timestamp.dateTimeString())
                        .fontWeight(.semibold)

                    HStack(spacing: 4) {
                        if record.reposMoved > 0 {
                            Text("\(record.reposMoved) repo\(record.reposMoved > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        if record.reposMoved > 0 && record.filesMoved > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if record.filesMoved > 0 {
                            Text("\(record.filesMoved) file\(record.filesMoved > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(record.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source: \(record.sourcePath)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Destination: \(record.destinationPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Duration: \(record.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let error = record.errorMessage {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.errorColor)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 8)
    }
}
