//
//  WatchConnectivityManager.swift
//  Silent Gym  (shared iOS + watchOS)
//
//  Phase 4 rewrite — offline-first, priority-based delivery.
//
//  Delivery tiers
//  ┌──────────────────────┬───────────────────────────────────────────────┐
//  │ Priority             │ Transport                                     │
//  ├──────────────────────┼───────────────────────────────────────────────┤
//  │ .realtime            │ sendMessage (dropped if not reachable)        │
//  │ .reliable            │ Queue first → try sendMessage → fallback to   │
//  │                      │ transferUserInfo; drained on reconnect         │
//  └──────────────────────┴───────────────────────────────────────────────┘
//
//  Thread safety
//  • @MainActor class — all @Published writes happen on main thread.
//  • WCSessionDelegate callbacks arrive on an arbitrary thread; wrapped in
//    DispatchQueue.main.async (safe because the body only enqueues a Task).
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    // MARK: - Published state

    @Published var isWatchReachable   = false
    @Published var isWatchAppInstalled = false
    @Published var isWatchPaired      = false
    @Published var pendingQueueCount: Int = 0  // badge for UI

    // MARK: - Callback

    var onMessageReceived: ((WatchMessage) -> Void)?

    // MARK: - Private

    private var wcSession: WCSession?

    override init() {
        super.init()
        Task { @MainActor in
            guard WCSession.isSupported() else { return }
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }

    // MARK: - Public send API

    /// Route a message according to its delivery priority.
    func send(_ message: WatchMessage) {
        switch message.type.priority {
        case .realtime:
            sendRealtime(message)
        case .reliable:
            sendReliable(message)
        }
    }

    // MARK: Convenience senders

    func sendStartWorkout(sessionId: UUID, activityType: Int, routineName: String? = nil) {
        send(WatchMessage(type: .startWorkout, sessionId: sessionId,
                          activityType: activityType, routineName: routineName))
    }

    func sendStopWorkout(sessionId: UUID) {
        send(WatchMessage(type: .stopWorkout, sessionId: sessionId))
    }

    func sendUpdateNow(sessionId: UUID, exerciseName: String, setIndex: Int, totalSets: Int) {
        send(WatchMessage(type: .updateNow, sessionId: sessionId,
                          exerciseName: exerciseName, setIndex: setIndex, totalSets: totalSets))
    }

    // Legacy alias (used by existing call sites)
    func sendMessage(_ message: WatchMessage) { send(message) }

    // MARK: Watch-side: completed set (offline-capable)
    // Called from watchOS only — enqueued when disconnected.
    func sendSetEntry(_ payload: SetEntryPayload) {
        send(WatchMessage(type: .setEntryCompleted, sessionId: payload.sessionId,
                          setEntry: payload))
    }

    // MARK: Watch-side: heart rate (realtime, OK to drop)
    func sendHeartRate(_ bpm: Double, sessionId: UUID) {
        send(WatchMessage(type: .heartRateUpdate, sessionId: sessionId, heartRate: bpm))
    }

    // MARK: - Private routing

    private func sendRealtime(_ message: WatchMessage) {
        guard let session = wcSession, session.isReachable else { return }
        transmitViaMessage(message, session: session)
    }

    private func sendReliable(_ message: WatchMessage) {
        #if os(watchOS)
        // On Watch: always queue first to guarantee persistence
        WatchSyncQueue.shared.enqueue(message)
        updateQueueBadge()
        if let session = wcSession, session.isReachable {
            flushQueue(session: session)
        }
        #else
        // On iPhone: try sendMessage first; fall back to transferUserInfo
        guard let session = wcSession else { return }
        if session.isReachable {
            transmitViaMessage(message, session: session)
        } else {
            transmitViaUserInfo(message, session: session)
        }
        #endif
    }

    /// Drain the Watch-side offline queue via transferUserInfo.
    private func flushQueue(session: WCSession) {
        #if os(watchOS)
        let pending = WatchSyncQueue.shared.drainAll()
        for message in pending {
            transmitViaUserInfo(message, session: session)
        }
        updateQueueBadge()
        if !pending.isEmpty {
            print("✅ WatchSyncQueue: flushed \(pending.count) queued messages")
        }
        #endif
    }

    private func updateQueueBadge() {
        #if os(watchOS)
        let count = WatchSyncQueue.shared.count
        DispatchQueue.main.async { self.pendingQueueCount = count }
        #endif
    }

    // MARK: - Low-level transport helpers

    private func transmitViaMessage(_ message: WatchMessage, session: WCSession) {
        guard let payload = try? JSONEncoder().encode(message) else { return }
        let dict: [String: Any] = ["type": message.type.rawValue, "data": payload]
        session.sendMessage(dict, replyHandler: nil) { error in
            print("⚠️ sendMessage failed: \(error.localizedDescription)")
            // Reliable messages — re-enqueue on Watch for retry
            #if os(watchOS)
            if message.type.priority == .reliable {
                WatchSyncQueue.shared.enqueue(message)
                self.updateQueueBadge()
            }
            #endif
        }
    }

    private func transmitViaUserInfo(_ message: WatchMessage, session: WCSession) {
        guard let payload = try? JSONEncoder().encode(message) else { return }
        session.transferUserInfo(["type": message.type.rawValue, "data": payload])
    }

    // MARK: - Inbound handler

    private func handleInbound(_ dict: [String: Any]) {
        guard let typeStr = dict["type"] as? String,
              let data    = dict["data"] as? Data,
              let message = try? JSONDecoder().decode(WatchMessage.self, from: data)
        else { return }
        _ = typeStr
        DispatchQueue.main.async { self.onMessageReceived?(message) }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        if let e = error { print("WCSession activation error: \(e)"); return }
        DispatchQueue.main.async {
            #if os(iOS)
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchPaired       = session.isPaired
            #else
            self.isWatchAppInstalled = true
            self.isWatchPaired       = true
            #endif
            self.isWatchReachable = session.isReachable
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        // When connection returns, flush any offline-queued messages
        if session.isReachable {
            #if os(watchOS)
            DispatchQueue.main.async { self.flushQueue(session: session) }
            #endif
        }
    }

    // sendMessage (high-priority, immediate)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let captured = message
        Task { @MainActor in self.handleInbound(captured) }
    }
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let captured = message
        Task { @MainActor in self.handleInbound(captured) }
        replyHandler(["status": "ok"])
    }

    // transferUserInfo (reliable, background delivery)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let captured = userInfo
        Task { @MainActor in self.handleInbound(captured) }
    }
}
