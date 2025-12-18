//
//  SchedulerService.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Foundation
import Combine

/// Service for scheduling automatic cache cleanup
class SchedulerService: ObservableObject {
    @Published var isSchedulerRunning = false
    @Published var nextCleanupDate: Date?
    
    private var timer: Timer?
    private let cacheService: CacheCleanerService
    
    init(cacheService: CacheCleanerService = CacheCleanerService()) {
        self.cacheService = cacheService
    }
    
    /// Start the scheduler
    func startScheduler() {
        guard !isSchedulerRunning else { return }
        
        isSchedulerRunning = true
        
        // Check every hour
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.checkAndRunCleanup()
            }
        }
        
        // Also check immediately
        Task {
            await checkAndRunCleanup()
        }
        
        updateNextCleanupDate()
    }
    
    /// Stop the scheduler
    func stopScheduler() {
        timer?.invalidate()
        timer = nil
        isSchedulerRunning = false
        nextCleanupDate = nil
    }
    
    /// Check if cleanup should run and execute if needed
    private func checkAndRunCleanup() async {
        let settings = cacheService.loadSettings()
        
        guard settings.shouldRunCleanup else {
            updateNextCleanupDate()
            return
        }
        
        print("Running scheduled cache cleanup...")
        
        do {
            let summary = try await cacheService.runCleanup(settings: settings) { progress, message in
                print("[\(Int(progress * 100))%] \(message)")
            }
            
            print("Cleanup complete: \(summary.totalDeleted) files deleted, \(summary.formattedSize) freed")
        } catch {
            print("Scheduled cleanup failed: \(error)")
        }
        
        updateNextCleanupDate()
    }
    
    /// Update next cleanup date
    private func updateNextCleanupDate() {
        let settings = cacheService.loadSettings()
        
        if let lastDate = settings.lastCleanupDate {
            nextCleanupDate = Calendar.current.date(
                byAdding: .hour,
                value: settings.intervalHours,
                to: lastDate
            )
        } else {
            nextCleanupDate = Date()
        }
    }
    
    /// Force run cleanup now
    func runCleanupNow() async throws -> CleanupSummary {
        let settings = cacheService.loadSettings()
        
        return try await cacheService.runCleanup(settings: settings) { progress, message in
            print("[\(Int(progress * 100))%] \(message)")
        }
    }
}
