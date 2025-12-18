//
//  CacheManagerView.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import SwiftUI

struct CacheManagerView: View {
    @StateObject private var viewModel = CacheManagerViewModel()
    @State private var showingSettings = false
    @State private var showingHistory = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            CacheManagerHeader(
                viewModel: viewModel,
                showingSettings: $showingSettings,
                showingHistory: $showingHistory
            )
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Status card
                    CacheStatusCard(viewModel: viewModel)
                    
                    // Progress
                    if viewModel.isRunning {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.progress) {
                                Text(viewModel.statusMessage)
                            }
                            
                            Text("Cleaning up caches...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Constants.Colors.cardBackgroundColor)
                        .cornerRadius(Constants.UI.cornerRadius)
                    }
                    
                    // Last cleanup summary
                    if let summary = viewModel.lastSummary {
                        CleanupSummaryCard(summary: summary)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Constants.Colors.errorColor.opacity(0.1))
                        .cornerRadius(Constants.UI.cornerRadius)
                    }
                    
                    // Action button
                    Button(action: {
                        Task {
                            await viewModel.runCleanup()
                        }
                    }) {
                        Label("Run Cleanup Now", systemImage: "play.fill")
                            .frame(maxWidth: 300)
                    }
                    .disabled(viewModel.isRunning || !viewModel.settings.enabled)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // Quick settings
                    QuickSettingsView(viewModel: viewModel)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingSettings) {
            CacheSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingHistory) {
            CacheHistoryView(viewModel: viewModel)
        }
    }
}

// MARK: - Cache Manager Header

struct CacheManagerHeader: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    @Binding var showingSettings: Bool
    @Binding var showingHistory: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cache Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Automatically clean up old cache files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("History") {
                showingHistory = true
            }
            
            Button("Settings") {
                showingSettings = true
            }
        }
        .padding()
    }
}

// MARK: - Cache Status Card

struct CacheStatusCard: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Cleanup Status")
                        .font(.headline)
                    Text(viewModel.settings.enabled ? "Enabled" : "Disabled")
                        .foregroundColor(viewModel.settings.enabled ? Constants.Colors.successColor : Constants.Colors.errorColor)
                }
                
                Spacer()
                
                Toggle("", isOn: .init(
                    get: { viewModel.settings.enabled },
                    set: { _ in viewModel.toggleEnabled() }
                ))
            }
            
            Divider()
            
            VStack(spacing: 8) {
                InfoRow(label: "Age Threshold", value: viewModel.formattedAgeThreshold)
                InfoRow(label: "Cleanup Interval", value: viewModel.formattedInterval)
                
                if let lastCleanup = viewModel.formattedLastCleanupDate {
                    InfoRow(label: "Last Cleanup", value: lastCleanup)
                }
                
                if let nextCleanup = viewModel.formattedNextCleanupDate {
                    InfoRow(label: "Next Cleanup", value: nextCleanup)
                }
                
                InfoRow(label: "Total Freed", value: viewModel.formattedTotalSizeFreed)
            }
        }
        .padding()
        .background(Constants.Colors.cardBackgroundColor)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Cleanup Summary Card

struct CleanupSummaryCard: View {
    let summary: CleanupSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: Constants.Icons.success)
                    .foregroundColor(Constants.Colors.successColor)
                Text("Last Cleanup Results")
                    .font(.headline)
            }
            
            Divider()
            
            InfoRow(label: "Files Deleted", value: "\(summary.totalDeleted)")
            InfoRow(label: "Space Freed", value: summary.formattedSize)
            InfoRow(label: "Duration", value: String(format: "%.1f seconds", summary.duration))
            InfoRow(label: "Success Rate", value: String(format: "%.0f%%", summary.successRate * 100))
        }
        .padding()
        .background(Constants.Colors.successColor.opacity(0.1))
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Quick Settings View

struct QuickSettingsView: View {
    @ObservedObject var viewModel: CacheManagerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Settings")
                .font(.headline)
            
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
        }
        .padding()
        .background(Constants.Colors.cardBackgroundColor)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

