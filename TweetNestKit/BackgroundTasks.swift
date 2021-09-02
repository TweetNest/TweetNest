//
//  BackgroundTasks.swift
//  BackgroundTasks
//
//  Created by Jaehong Kang on 2021/08/30.
//

import Foundation
import UnifiedLogging

#if os(macOS)
@inlinable
public func withExtendedBackgroundExecution<T>(function: String = #function, fileID: String = #fileID, line: Int = #line, body: @escaping () async throws -> T) async rethrows -> T {
    try await withExtendedBackgroundExecution(identifier: "\(function) (\(fileID):\(line))", body: body)
}

public func withExtendedBackgroundExecution<T>(identifier: String, body: @escaping () async throws -> T) async rethrows -> T {
    let token = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: identifier)
    defer {
        ProcessInfo.processInfo.endActivity(token)
    }

    logger.notice("\(identifier, privacy: .public): Starting process activity")
    defer {
        logger.notice("\(identifier, privacy: .public): Process activity finished with cancelled: \(Task.isCancelled)")
    }

    return try await body()
}
#else
private func handleExtendedBackgroundExecution<T>(identifier: String, expirationHandler: @escaping @Sendable () -> Void, body: @escaping () async throws -> T) async rethrows -> T {
    let logger = Logger(subsystem: Bundle.module.bundleIdentifier!, category: "process-activity")

    let taskSemaphore = DispatchSemaphore(value: 0)
    defer {
        taskSemaphore.signal()
    }

    ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
        if expired {
            logger.notice("\(identifier, privacy: .public): Canceling process activity")
            expirationHandler()
            logger.notice("\(identifier, privacy: .public): Process activity cancelled")
        } else {
            taskSemaphore.wait()
        }
    }

    logger.notice("\(identifier, privacy: .public): Starting process activity")
    defer {
        logger.notice("\(identifier, privacy: .public): Process activity finished with cancelled: \(Task.isCancelled)")
    }

    return try await body()
}

@inlinable
public func withExtendedBackgroundExecution<T>(function: String = #function, fileID: String = #fileID, line: Int = #line, body: @escaping () async throws -> T) async throws -> T {
    try await withExtendedBackgroundExecution(identifier: "\(function) (\(fileID):\(line))", body: body)
}

public func withExtendedBackgroundExecution<T>(identifier: String, body: @escaping () async throws -> T) async throws -> T {
    try await withTaskExpirationHandler { expirationHandler in
        return try await handleExtendedBackgroundExecution(identifier: identifier, expirationHandler: expirationHandler, body: body)
    }
}

@inlinable
public func withExtendedBackgroundExecution<T>(function: String = #function, fileID: String = #fileID, line: Int = #line, body: @escaping () async -> T) async -> T {
    await withExtendedBackgroundExecution(identifier: "\(function) (\(fileID):\(line))", body: body)
}

public func withExtendedBackgroundExecution<T>(identifier: String, body: @escaping () async -> T) async -> T {
    await withTaskExpirationHandler { expirationHandler in
        return await handleExtendedBackgroundExecution(identifier: identifier, expirationHandler: expirationHandler, body: body)
    }
}
#endif
