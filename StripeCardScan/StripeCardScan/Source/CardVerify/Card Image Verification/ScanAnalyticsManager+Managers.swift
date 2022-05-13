//
//  ScanAnalyticsManager+Managers.swift
//  StripeCardScan
//
//  Created by Jaime Park on 12/13/21.
//

import Foundation

/// Manager used to aggregate all non-repeating tasks
struct NonRepeatingTasksManager {
    /// Default unknown values
    var cameraPermissionTask: TrackableTask = TrackableTask()
    var torchSupportedTask: TrackableTask = TrackableTask()
    var scanActivityTasks: [TrackableTask] = []

    /// Create API model
    func generateNonRepeatingTasks() -> NonRepeatingTasks {
        func unwrapTaskOrDefault(_ task: TrackableTask) -> ScanAnalyticsNonRepeatingTask {
            return task.toAPIModel() ?? .init(result: ScanAnalyticsEvent.unknown.rawValue, startedAtMs: -1, durationMs: -1)
        }

        return .init(
            cameraPermissionTask: unwrapTaskOrDefault(cameraPermissionTask),
            torchSupportedTask: unwrapTaskOrDefault(torchSupportedTask),
            scanActivityTasks: scanActivityTasks.compactMap { $0.toAPIModel() }
        )
    }
}

/// Manager used to aggregate all repeating tasks
struct RepeatingTasksManager {
    /// Default to negative number frames processed
    var mainLoopImagesProcessed: ScanAnalyticsRepeatingTask = .init(executions: -1)

    /// Create API model
    func generateRepeatingTasks() -> RepeatingTasks {
        return .init(mainLoopImagesProcessed: mainLoopImagesProcessed)
    }
}
