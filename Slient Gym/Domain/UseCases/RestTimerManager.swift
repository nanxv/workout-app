//
//  RestTimerManager.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import Combine

enum RestTimerState {
    case off
    case running(remaining: Int)
    case paused(remaining: Int)
}

class RestTimerManager: ObservableObject {
    @Published var state: RestTimerState = .off
    @Published var remainingSeconds: Int = 0
    
    private var timer: Timer?
    private var startTime: Date?
    private var pausedRemaining: Int = 0
    
    var onTick: ((Int) -> Void)?
    var onFinish: (() -> Void)?
    
    func start(seconds: Int) {
        stop()
        remainingSeconds = seconds
        pausedRemaining = seconds
        startTime = Date()
        state = .running(remaining: seconds)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.current.add(self.timer!, forMode: .common)
        }
    }
    
    func pause() {
        guard case .running(let remaining) = state else { return }
        timer?.invalidate()
        timer = nil
        pausedRemaining = remaining
        state = .paused(remaining: remaining)
    }
    
    func resume() {
        guard case .paused(let remaining) = state else { return }
        startTime = Date()
        state = .running(remaining: remaining)
        remainingSeconds = remaining
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.current.add(self.timer!, forMode: .common)
        }
    }
    
    func extend(by seconds: Int) {
        if case .running(let remaining) = state {
            let newRemaining = remaining + seconds
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
        timer?.invalidate()
        timer = nil
        startTime = nil
        remainingSeconds = 0
        pausedRemaining = 0
        state = .off
    }
    
    private func tick() {
        guard let startTime = startTime else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let elapsed = Int(Date().timeIntervalSince(startTime))
            let newRemaining = max(0, self.pausedRemaining - elapsed)
            
            self.remainingSeconds = newRemaining
            
            if case .running = self.state {
                self.state = .running(remaining: newRemaining)
            }
            
            self.onTick?(newRemaining)
            
            if newRemaining <= 0 {
                self.stop()
                self.onFinish?()
            }
        }
    }
    
    deinit {
        stop()
    }
}

