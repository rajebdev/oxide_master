//
//  CacheHistoryView.swift
//  OxideMaster
//
//  Created on 2025-12-17.
//

import SwiftUI

struct CacheHistoryView: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cleanup History")
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
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Constants.Colors.cardBackgroundColor)
            .cornerRadius(Constants.UI.cornerRadius)
            .padding()
            
            // History list
            if viewModel.history.isEmpty {
                VStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("No cleanup history")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let filteredHistory = searchText.isEmpty ? viewModel.history : viewModel.history.filter {
                    $0.filePath.localizedCaseInsensitiveContains(searchText)
                }
                
                List(filteredHistory) { record in
                    CacheHistoryRow(record: record)
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - Cache History Row

struct CacheHistoryRow: View {
    let record: CleanupRecord
    
    var body: some View {
        HStack {
            Image(systemName: record.deletedSuccessfully ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(record.deletedSuccessfully ? Constants.Colors.successColor : Constants.Colors.errorColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.filePath.lastPathComponent)
                    .fontWeight(.medium)
                
                Text(record.filePath.directoryPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(record.timestamp.dateTimeString())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

