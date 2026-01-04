//
//  RestTimerManager.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

enum RestTimerState: Equatable {
    case off
    case running(remaining: Int)
    case paused(remaining: Int)
}

extension RestTimerState {
    static func == (lhs: RestTimerState, rhs: RestTimerState) -> Bool {
        switch (lhs, rhs) {
        case (.off, .off):
            return true
        case (.running(let l), .running(let r)):
            return l == r
        case (.paused(let l), .paused(let r)):
            return l == r
        default:
            return false
        }
    }
}

class RestTimerManager: ObservableObject {
    @Published var state: RestTimerState = .off
    @Published var remainingSeconds: Int = 0
    
    private var timer: DispatchSourceTimer?
    private var expectedEnd: Date? // 使用预期结束时间，而不是开始时间
    private var pausedRemaining: Int = 0
    
    var onTick: ((Int) -> Void)?
    var onFinish: (() -> Void)?
    
    init() {
        // 监听应用前后台切换，校正时间
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidBecomeActive() {
        // 前后台切换时，重新计算剩余时间
        if case .running = state, expectedEnd != nil {
            tick()
        }
    }
    
    func start(seconds: Int) {
        stop()
        remainingSeconds = seconds
        pausedRemaining = seconds
        // 使用预期结束时间，而不是开始时间（时间戳校正）
        expectedEnd = Date().addingTimeInterval(TimeInterval(seconds))
        state = .running(remaining: seconds)
        
        // 使用 DispatchSourceTimer 更精确
        timer?.cancel()
        let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        newTimer.schedule(deadline: .now(), repeating: .milliseconds(200))
        newTimer.setEventHandler { [weak self] in
            self?.tick()
        }
        newTimer.resume()
        timer = newTimer
        
        // 立即执行一次 tick
        tick()
    }
    
    func pause() {
        guard case .running(let remaining) = state else { return }
        timer?.cancel()
        timer = nil
        pausedRemaining = remaining
        state = .paused(remaining: remaining)
        expectedEnd = nil // 暂停时清除预期结束时间
    }
    
    func resume() {
        guard case .paused(let remaining) = state else { return }
        // 恢复时，基于当前剩余时间重新计算预期结束时间
        expectedEnd = Date().addingTimeInterval(TimeInterval(remaining))
        state = .running(remaining: remaining)
        remainingSeconds = remaining
        
        // 重新启动定时器
        timer?.cancel()
        let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        newTimer.schedule(deadline: .now(), repeating: .milliseconds(200))
        newTimer.setEventHandler { [weak self] in
            self?.tick()
        }
        newTimer.resume()
        timer = newTimer
        tick()
    }
    
    func extend(by seconds: Int) {
        if case .running(let remaining) = state {
            // 延长时，更新预期结束时间
            let newRemaining = remaining + seconds
            expectedEnd = Date().addingTimeInterval(TimeInterval(newRemaining))
            remainingSeconds = newRemaining
            pausedRemaining = newRemaining
            state = .running(remaining: newRemaining)
        } else if case .paused(let remaining) = state {
            let newRemaining = remaining + seconds
            pausedRemaining = newRemaining
            state = .paused(remaining: newRemaining)
        }
    }
    
    func skip() {
        stop()
        onFinish?()
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
        expectedEnd = nil
        remainingSeconds = 0
        pausedRemaining = 0
        state = .off
    }
    
    private func tick() {
        guard let end = expectedEnd else { return }
        
        // 使用时间戳校正：基于预期结束时间和当前时间计算剩余时间
        let remaining = max(0, end.timeIntervalSinceNow)
        let remainingInt = Int(remaining)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.remainingSeconds = remainingInt
            
            if case .running = self.state {
                self.state = .running(remaining: remainingInt)
            }
            
            self.onTick?(remainingInt)
            
            if remainingInt <= 0 {
                self.stop()
                self.onFinish?()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stop()
    }
}

