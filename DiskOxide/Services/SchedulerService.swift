//
//  SchedulerService.swift
//  DiskOxide
//
//  Created on 2025-12-17.
//

import Combine
import Foundation
import UserNotifications

/// Service for scheduling automatic cache cleanup
class SchedulerService: ObservableObject {
    @Published var isSchedulerRunning = false
    @Published var nextCleanupDate: Date?
    @Published var pendingCacheItems: [CacheItem] = []

    private var timer: Timer?
    private let cacheService: CacheCleanerService

    init(cacheService: CacheCleanerService = CacheCleanerService()) {
        self.cacheService = cacheService
        setupNotificationDelegate()
    }

    /// Setup notification delegate for handling user responses
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
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

        print("Scheduled cache cleanup triggered...")

        do {
            // Scan first
            let items = try await cacheService.scanCacheItems(settings: settings) {
                progress, message in
                print("[\(Int(progress * 100))%] \(message)")
            }

            guard !items.isEmpty else {
                print("No cache items found to clean")
                updateNextCleanupDate()
                return
            }

            // Check if confirmation required
            if settings.requireConfirmationForScheduledCleanup {
                // Request confirmation via notification
                await requestCleanupConfirmation(items: items)
            } else {
                // Auto cleanup without confirmation
                await performCleanup(items: items)
            }
        } catch {
            print("Scheduled cleanup failed: \(error)")
        }

        updateNextCleanupDate()
    }

    /// Request user confirmation via notification
    private func requestCleanupConfirmation(items: [CacheItem]) async {
        let totalSize = items.reduce(0) { $0 + $1.sizeBytes }
        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

        // Store pending items
        await MainActor.run {
            self.pendingCacheItems = items
        }

        let content = UNMutableNotificationContent()
        content.title = "Cache Cleanup Ready"
        content.body =
            "Found \(items.count) cache folders (\(formattedSize)). Open app to review and confirm."
        content.sound = .default
        content.categoryIdentifier = "CACHE_CLEANUP_CONFIRMATION"
        content.userInfo = ["itemCount": items.count, "totalSize": totalSize]

        let request = UNNotificationRequest(
            identifier: "scheduled-cleanup-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Confirmation notification sent: \(items.count) items, \(formattedSize)")
        } catch {
            print("Failed to send notification: \(error)")
        }
    }

    /// Perform cleanup automatically
    private func performCleanup(items: [CacheItem]) async {
        do {
            let summary = try await cacheService.runCleanup(items: items) { progress, message in
                print("[\(Int(progress * 100))%] \(message)")
            }

            print(
                "Auto cleanup complete: \(summary.totalDeleted) items deleted, \(summary.formattedSize) freed"
            )

            // Send completion notification
            await sendCompletionNotification(summary: summary)
        } catch {
            print("Auto cleanup failed: \(error)")
        }
    }

    /// Send cleanup completion notification
    private func sendCompletionNotification(summary: CleanupSummary) async {
        let content = UNMutableNotificationContent()
        content.title = "Cache Cleanup Complete"
        content.body = "Deleted \(summary.totalDeleted) items, freed \(summary.formattedSize)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cleanup-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send completion notification: \(error)")
        }
    }

    /// Confirm and run pending cleanup (called from app when user opens from notification)
    func confirmAndRunPendingCleanup() async throws -> CleanupSummary {
        guard !pendingCacheItems.isEmpty else {
            throw CacheCleanupError.noItemsSelected
        }

        let items = pendingCacheItems
        pendingCacheItems = []

        let summary = try await cacheService.runCleanup(items: items) { progress, message in
            print("[\(Int(progress * 100))%] \(message)")
        }

        await sendCompletionNotification(summary: summary)
        return summary
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

        // Scan first, then cleanup all items
        let items = try await cacheService.scanCacheItems(settings: settings) { progress, message in
            print("[\(Int(progress * 100))%] \(message)")
        }

        return try await cacheService.runCleanup(items: items) { progress, message in
            print("[\(Int(progress * 100))%] \(message)")
        }
    }
}
