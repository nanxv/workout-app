//
//  CalendarManager.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import Combine

#if os(iOS)
import EventKit
import EventKitUI
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
    
    /// 创建训练计划事件（用于提前安排训练）
    /// - Parameters:
    ///   - routine: 训练计划 Routine
    ///   - startDate: 计划的开始日期和时间
    ///   - presentingViewController: 用于展示 EKEventEditViewController 的视图控制器
    ///   - completion: 完成回调，返回创建的 eventId
    func createEventForRoutine(
        routine: Routine,
        startDate: Date,
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
            
            // 估算训练时长（分钟）
            let estimatedMinutes = estimateRoutineDuration(routine: routine)
            let endDate = startDate.addingTimeInterval(TimeInterval(estimatedMinutes * 60))
            
            // 创建事件
            let event = EKEvent(eventStore: eventStore)
            event.title = "训练 - \(routine.name)"
            event.startDate = startDate
            event.endDate = endDate
            event.notes = generateRoutineNotes(routine: routine)
            event.calendar = defaultCalendar ?? eventStore.defaultCalendarForNewEvents
            
            // 使用 EKEventEditViewController 让用户确认和编辑
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
    
    /// 估算训练计划时长（分钟）
    private func estimateRoutineDuration(routine: Routine) -> Int {
        guard let exercises = routine.exercises else { return 60 }
        
        var totalSeconds = 0
        for re in exercises {
            let exerciseTime: Int
            if re.isHoldType, let holdSec = re.holdSecDefault {
                // 计时动作：组数 × (时长 + 休息)
                exerciseTime = re.targetSets * (holdSec + re.restSecondsDefault)
            } else {
                // 计次动作：假设每次 rep 6 秒
                let repTime = 6
                let reps = re.repTarget ?? 10
                exerciseTime = re.targetSets * (re.restSecondsDefault + reps * repTime)
            }
            totalSeconds += exerciseTime
        }
        
        // 转换为分钟，最少 20 分钟，最多 120 分钟
        return max(20, min(120, totalSeconds / 60))
    }
    
    /// 生成训练计划备注
    private func generateRoutineNotes(routine: Routine) -> String {
        var notes: [String] = []
        notes.append("训练计划: \(routine.name)")
        
        if let exercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
            notes.append("")
            notes.append("动作:")
            for re in exercises {
                let exerciseName = re.exercise?.name ?? "未知动作"
                var detail = "  - \(exerciseName): \(re.targetSets)组"
                
                if re.isHoldType, let holdSec = re.holdSecDefault {
                    detail += " × \(holdSec)秒"
                } else if let repTarget = re.repTarget {
                    detail += " × \(repTarget)次"
                }
                
                detail += "，休息 \(re.restSecondsDefault)秒"
                notes.append(detail)
            }
        }
        
        let estimatedMinutes = estimateRoutineDuration(routine: routine)
        notes.append("")
        notes.append("预计时长: 约 \(estimatedMinutes) 分钟")
        
        return notes.joined(separator: "\n")
    }
    
    /// 生成事件标题
    private func generateEventTitle(for session: Session) -> String {
        let routineName = session.routineNameSnapshot
        return routineName.isEmpty ? "训练" : "训练 - \(routineName)"
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

