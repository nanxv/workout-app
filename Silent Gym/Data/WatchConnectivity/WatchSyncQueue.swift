//
//  WatchSyncQueue.swift
//  Silent Gym Watch App
//
//  Created by CHY5TK on 2026/02/25.
//
//  Thread-safe, UserDefaults-backed offline queue.
//
//  When the Watch cannot reach the iPhone (isReachable == false), reliable
//  WatchMessages are persisted here.  As soon as connectivity returns, the
//  WatchConnectivityManager drains this queue via transferUserInfo so that
//  no set-entry or session-state data is ever lost.
//

import Foundation

/// Offline queue — compiled for all platforms but only active on watchOS.
#if os(watchOS)
final class WatchSyncQueue {

    static let shared = WatchSyncQueue()

    // MARK: - Constants

    private let storageKey = "silentGym.watchSyncQueue.v2"
    /// Hard cap to prevent unbounded growth during extended offline periods.
    private let maxQueueSize = 500

    // MARK: - State

    private let lock = NSLock()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Public API

    /// Number of pending messages.
    var count: Int {
        lock.withLock { load().count }
    }

    var isEmpty: Bool {
        lock.withLock { load().isEmpty }
    }

    /// Append a message to the back of the queue.
    func enqueue(_ message: WatchMessage) {
        lock.withLock {
            var q = load()
            guard q.count < maxQueueSize else {
                print("⚠️ WatchSyncQueue: queue full (\(maxQueueSize)), dropping oldest entry")
                q.removeFirst()
                return
            }
            q.append(message)
            save(q)
        }
    }

    /// Remove and return all queued messages (FIFO order), clearing the store.
    func drainAll() -> [WatchMessage] {
        lock.withLock {
            let q = load()
            save([])
            return q
        }
    }

    /// Peek at the queue without removing (for logging / UI badge).
    func peek() -> [WatchMessage] {
        lock.withLock { load() }
    }

    /// Clear all pending messages (e.g. after a failed session that the user discards).
    func clear() {
        lock.withLock { save([]) }
    }

    // MARK: - Storage

    private func load() -> [WatchMessage] {
        guard let data = defaults.data(forKey: storageKey),
              let messages = try? JSONDecoder().decode([WatchMessage].self, from: data)
        else { return [] }
        return messages
    }

    private func save(_ messages: [WatchMessage]) {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

// MARK: - NSLock convenience
private extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
#endif
