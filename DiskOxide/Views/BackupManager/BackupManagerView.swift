//
//  BackupManagerView.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI

struct BackupManagerView: View {
    @StateObject private var viewModel = BackupManagerViewModel()
    @State private var showingSourcePicker = false
    @State private var showingDestinationPicker = false
    @State private var showingHistory = false
    
    var body: some View {
        HSplitView {
            // Left: Configuration
            VStack(alignment: .leading, spacing: 20) {
                Text("Backup Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Form {
                    // Source path
                    Section("Source Folder") {
                        HStack {
                            TextField("Source path", text: $viewModel.config.sourcePath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Browse...") {
                                showingSourcePicker = true
                            }
                        }
                    }
                    
                    // Destination path
                    Section("Destination Folder") {
                        HStack {
                            TextField("Destination path", text: $viewModel.config.destinationPath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Browse...") {
                                showingDestinationPicker = true
                            }
                        }
                    }
                    
                    // Age filter
                    Section("Filter Settings") {
                        HStack {
                            Text("Backup files modified within:")
                            TextField("Days", value: $viewModel.config.ageFilterDays, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("days")
                        }
                        
                        Text("Files older than \(viewModel.formattedCutoffDate) will be ignored")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Options
                    Section("Options") {
                        Toggle("Preserve folder structure", isOn: $viewModel.config.preserveStructure)
                    }
                }
                .formStyle(.grouped)
                
                // Progress
                if viewModel.isRunning {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress) {
                            Text(viewModel.statusMessage)
                        }
                        
                        Text("Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Constants.Colors.cardBackgroundColor)
                    .cornerRadius(Constants.UI.cornerRadius)
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: Constants.Icons.error)
                            .foregroundColor(Constants.Colors.errorColor)
                        Text(error)
                            .foregroundColor(Constants.Colors.errorColor)
                    }
                    .padding()
                    .background(Constants.Colors.errorColor.opacity(0.1))
                    .cornerRadius(Constants.UI.cornerRadius)
                }
                
                // Last backup info
                if let lastDate = viewModel.formattedLastBackupDate {
                    HStack {
                        Image(systemName: Constants.Icons.info)
                            .foregroundColor(Constants.Colors.infoColor)
                        Text("Last backup: \(lastDate)")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Constants.Colors.infoColor.opacity(0.1))
                    .cornerRadius(Constants.UI.cornerRadius)
                }
                
                // Action buttons
                HStack {
                    Button(action: {
                        Task {
                            await viewModel.runBackup()
                        }
                    }) {
                        Label("Run Backup", systemImage: "play.fill")
                    }
                    .disabled(!viewModel.isConfigValid || viewModel.isRunning)
                    .buttonStyle(.borderedProminent)
                    
                    Button("View History") {
                        showingHistory = true
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 400)
            
            // Right: Last backup results
            if let record = viewModel.lastBackupRecord {
                BackupResultView(record: record)
            } else {
                VStack {
                    Image(systemName: Constants.Icons.backup)
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("No backup run yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showingSourcePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.updateSourcePath(url.path)
            }
        }
        .fileImporter(
            isPresented: $showingDestinationPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.updateDestinationPath(url.path)
            }
        }
        .sheet(isPresented: $showingHistory) {
            BackupHistoryView(viewModel: viewModel)
        }
    }
}

// MARK: - Backup Result View

struct BackupResultView: View {
    let record: BackupRecord
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: record.statusIcon)
                .font(.system(size: 64))
                .foregroundColor(record.success ? Constants.Colors.successColor : Constants.Colors.errorColor)
            
            Text(record.success ? "Backup Complete" : "Backup Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Files Copied", value: "\(record.filesCopied)")
                InfoRow(label: "Total Size", value: record.formattedSize)
                InfoRow(label: "Duration", value: record.formattedDuration)
                InfoRow(label: "Timestamp", value: record.timestamp.dateTimeString())
                
                if let error = record.errorMessage {
                    InfoRow(label: "Error", value: error)
                        .foregroundColor(Constants.Colors.errorColor)
                }
            }
            .padding()
            .background(Constants.Colors.cardBackgroundColor)
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

