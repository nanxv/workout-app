//
//  WatchConnectivityManager.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    
    private var session: WCSession?
    
    var onMessageReceived: ((WatchMessage) -> Void)?
    
    override init() {
        super.init()
        // Setup asynchronously to avoid blocking
        Task { @MainActor in
            setupWatchConnectivity()
        }
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity is not supported on this device")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func sendMessage(_ message: WatchMessage) {
        guard let session = session, session.isReachable else {
            print("Watch is not reachable, message will be queued")
            // Use sendMessage:replyHandler:errorHandler: for background delivery
            sendMessageInBackground(message)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let messageDict: [String: Any] = [
                "type": message.type.rawValue,
                "data": data
            ]
            
            session.sendMessage(messageDict, replyHandler: { reply in
                print("Message sent successfully, reply: \(reply)")
            }, errorHandler: { error in
                print("Error sending message: \(error.localizedDescription)")
            })
        } catch {
            print("Error encoding message: \(error.localizedDescription)")
        }
    }
    
    private func sendMessageInBackground(_ message: WatchMessage) {
        guard let session = session else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            let messageDict: [String: Any] = [
                "type": message.type.rawValue,
                "data": data
            ]
            
            session.transferUserInfo(messageDict)
        } catch {
            print("Error encoding message for background: \(error.localizedDescription)")
        }
    }
    
    func sendStartWorkout(sessionId: UUID, activityType: Int) {
        let message = WatchMessage(
            type: .startWorkout,
            sessionId: sessionId,
            activityType: activityType
        )
        sendMessage(message)
    }
    
    func sendStopWorkout(sessionId: UUID) {
        let message = WatchMessage(
            type: .stopWorkout,
            sessionId: sessionId
        )
        sendMessage(message)
    }
    
    func sendUpdateNow(sessionId: UUID, exerciseName: String, setIndex: Int, totalSets: Int) {
        let message = WatchMessage(
            type: .updateNow,
            sessionId: sessionId,
            exerciseName: exerciseName,
            setIndex: setIndex,
            totalSets: totalSets
        )
        sendMessage(message)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
                return
            }
            
            #if os(iOS)
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchPaired = session.isPaired
            #elseif os(watchOS)
            // On watchOS, we're always "installed" and "paired" (to ourselves)
            self.isWatchAppInstalled = true
            self.isWatchPaired = true
            #endif
            
            self.isWatchReachable = session.isReachable
            print("WCSession activated: reachable=\(session.isReachable)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated, reactivating...")
        session.activate()
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        handleReceivedMessage(userInfo)
    }
    
    private func handleReceivedMessage(_ message: [String : Any]) {
        guard let typeString = message["type"] as? String,
              WatchMessageType(rawValue: typeString) != nil,
              let data = message["data"] as? Data else {
            print("Invalid message format")
            return
        }
        
        do {
            let watchMessage = try JSONDecoder().decode(WatchMessage.self, from: data)
            DispatchQueue.main.async {
                self.onMessageReceived?(watchMessage)
            }
        } catch {
            print("Error decoding message: \(error.localizedDescription)")
        }
    }
}

