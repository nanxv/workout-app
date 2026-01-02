//
//  CalendarManager.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import Combine
import EventKit
import EventKitUI

#if os(iOS)
import UIKit

@MainActor
class CalendarManager: NSObject, ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var defaultCalendar: EKCalendar?
    
    private override init() {
        super.init()
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        loadDefaultCalendar()
    }
    
    /// 请求日历访问权限
    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized, .fullAccess:
            authorizationStatus = status
            loadDefaultCalendar()
            return true
        case .notDetermined:
            // Use the new iOS 17+ API
            if #available(iOS 17.0, *) {
                do {
                    try await eventStore.requestFullAccessToEvents()
                    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    loadDefaultCalendar()
                    return true
                } catch {
                    print("Calendar access denied: \(error.localizedDescription)")
                    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    return false
                }
            } else {
                // Fallback for iOS 16 and earlier
                let granted = try? await eventStore.requestAccess(to: .event)
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted == true {
                    loadDefaultCalendar()
                }
                return granted == true
            }
        case .denied, .restricted, .writeOnly:
            authorizationStatus = status
            return false
        @unknown default:
            return false
        }
    }
    
    /// 加载默认日历
    private func loadDefaultCalendar() {
        let calendars = eventStore.calendars(for: .event)
        // 优先选择 "训练" 或 "Workout" 日历，否则使用默认日历
        defaultCalendar = calendars.first { $0.title.contains("训练") || $0.title.contains("Workout") }
            ?? eventStore.defaultCalendarForNewEvents
    }
    
    /// 创建训练事件（使用 EKEventEditViewController 让用户确认）
    /// - Parameters:
    ///   - session: 训练 Session
    ///   - presentingViewController: 用于展示 EKEventEditViewController 的视图控制器
    ///   - completion: 完成回调，返回创建的 eventId
    func createEventForSession(
        session: Session,
        presentingViewController: UIViewController,
        completion: @escaping (String?) -> Void
    ) {
        Task {
            // 检查权限
            guard await requestAccess() else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 创建事件
            let event = EKEvent(eventStore: eventStore)
            event.title = generateEventTitle(for: session)
            event.startDate = session.startAt
            event.endDate = session.endAt ?? Date()
            event.notes = generateEventNotes(for: session)
            event.calendar = defaultCalendar ?? eventStore.defaultCalendarForNewEvents
            
            // 使用 EKEventEditViewController 让用户确认
            DispatchQueue.main.async {
                let eventEditViewController = EKEventEditViewController()
                eventEditViewController.eventStore = self.eventStore
                eventEditViewController.event = event
                eventEditViewController.editViewDelegate = self
                
                // 保存 completion handler
                self.pendingCompletion = completion
                self.presentingViewController = presentingViewController
                
                // 展示编辑界面
                presentingViewController.present(eventEditViewController, animated: true)
            }
        }
    }
    
    /// 生成事件标题
    private func generateEventTitle(for session: Session) -> String {
        if let routineName = session.routine?.name {
            return "训练 - \(routineName)"
        }
        return "训练"
    }
    
    /// 生成事件备注
    private func generateEventNotes(for session: Session) -> String {
        var notes: [String] = []
        
        // 统计信息
        if let exercises = session.exercises {
            var totalSets = 0
            var totalReps = 0
            var totalRIR = 0
            var rirCount = 0
            
            for sessionExercise in exercises {
                if let sets = sessionExercise.sets {
                    totalSets += sets.count
                    for set in sets {
                        totalReps += set.reps
                        totalRIR += set.rir
                        rirCount += 1
                    }
                }
            }
            
            notes.append("总组数: \(totalSets)")
            notes.append("总次数: \(totalReps)")
            if rirCount > 0 {
                let avgRIR = Double(totalRIR) / Double(rirCount)
                notes.append("平均 RIR: \(String(format: "%.1f", avgRIR))")
            }
        }
        
        // 训练时长
        if let duration = session.duration {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            notes.append("时长: \(minutes)分\(seconds)秒")
        }
        
        return notes.joined(separator: "\n")
    }
    
    // MARK: - EKEventEditViewDelegate
    
    private var pendingCompletion: ((String?) -> Void)?
    private weak var presentingViewController: UIViewController?
}

extension CalendarManager: EKEventEditViewDelegate {
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        controller.dismiss(animated: true) {
            switch action {
            case .saved:
                // 事件已保存
                if let event = controller.event, let eventId = event.eventIdentifier {
                    self.pendingCompletion?(eventId)
                } else {
                    self.pendingCompletion?(nil)
                }
            case .canceled:
                // 用户取消
                self.pendingCompletion?(nil)
            case .deleted:
                // 事件被删除（不应该发生，因为我们创建的是新事件）
                self.pendingCompletion?(nil)
            @unknown default:
                self.pendingCompletion?(nil)
            }
            
            // 清理
            self.pendingCompletion = nil
            self.presentingViewController = nil
        }
    }
}
#endif

