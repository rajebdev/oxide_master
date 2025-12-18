//
//  CacheSettingsView.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI

struct CacheSettingsView: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newParentFolder = ""
    @State private var newCacheFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cache Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            
            Divider()
            
            // Settings content
            Form {
                // Parent folders
                Section("Parent Folders to Scan") {
                    List {
                        ForEach(Array(viewModel.settings.parentFolders.enumerated()), id: \.offset) { index, folder in
                            HStack {
                                Text(folder)
                                    .font(.caption)
                                Spacer()
                                Button(action: {
                                    viewModel.removeParentFolder(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add parent folder path", text: $newParentFolder)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            if !newParentFolder.isEmpty {
                                viewModel.addParentFolder(newParentFolder)
                                newParentFolder = ""
                            }
                        }
                        .disabled(newParentFolder.isEmpty)
                    }
                }
                
                // Cache folder names
                Section("Cache Folder Names to Match") {
                    List {
                        ForEach(Array(viewModel.settings.cacheFolderNames.enumerated()), id: \.offset) { index, name in
                            HStack {
                                Text(name)
                                Spacer()
                                Button(action: {
                                    viewModel.removeCacheFolderName(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add cache folder name", text: $newCacheFolderName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            if !newCacheFolderName.isEmpty {
                                viewModel.addCacheFolderName(newCacheFolderName)
                                newCacheFolderName = ""
                            }
                        }
                        .disabled(newCacheFolderName.isEmpty)
                    }
                }
                
                // Thresholds
                Section("Cleanup Thresholds") {
                    HStack {
                        Text("Age Threshold (hours):")
                        Spacer()
                        TextField("Hours", value: .init(
                            get: { viewModel.settings.ageThresholdHours },
                            set: { viewModel.updateAgeThreshold($0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }
                    
                    Text("Files older than this will be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Cleanup Interval (hours):")
                        Spacer()
                        TextField("Hours", value: .init(
                            get: { viewModel.settings.intervalHours },
                            set: { viewModel.updateInterval($0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }
                    
                    Text("How often to run automatic cleanup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 600, height: 600)
    }
}

