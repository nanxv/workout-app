//
//  RestTimerManagerTests.swift
//  Slient GymTests
//
//  Created by CHY5TK on 2026/01/02.
//

import XCTest
@testable import Slient_Gym

final class RestTimerManagerTests: XCTestCase {
    var timerManager: RestTimerManager!
    
    override func setUp() {
        super.setUp()
        timerManager = RestTimerManager()
    }
    
    override func tearDown() {
        timerManager = nil
        super.tearDown()
    }
    
    func testStartTimer() {
        let expectation = XCTestExpectation(description: "Timer starts")
        
        timerManager.onTick = { remaining in
            if remaining < 5 {
                expectation.fulfill()
            }
        }
        
        timerManager.start(seconds: 5)
        
        wait(for: [expectation], timeout: 6.0)
    }
    
    func testTimerAccuracy() {
        let startTime = Date()
        var tickCount = 0
        
        timerManager.onTick = { _ in
            tickCount += 1
        }
        
        timerManager.start(seconds: 3)
        
        let expectation = XCTestExpectation(description: "Timer finishes")
        timerManager.onFinish = {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 4.0)
        
        let elapsed = Date().timeIntervalSince(startTime)
        // 允许 0.5 秒误差
        XCTAssertEqual(elapsed, 3.0, accuracy: 0.5, "Timer should be accurate within 0.5 seconds")
    }
    
    func testExtendTimer() {
        var finalRemaining = 0
        
        timerManager.onTick = { remaining in
            finalRemaining = remaining
        }
        
        timerManager.start(seconds: 5)
        
        // 等待 1 秒后延长
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.timerManager.extend(by: 3)
        }
        
        let expectation = XCTestExpectation(description: "Timer finishes")
        timerManager.onFinish = {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // 应该延长了 3 秒，总共约 8 秒
        XCTAssertGreaterThan(finalRemaining, 0, "Timer should have been extended")
    }
    
    func testSkipTimer() {
        var finished = false
        
        timerManager.onFinish = {
            finished = true
        }
        
        timerManager.start(seconds: 10)
        
        // 立即跳过
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.timerManager.skip()
        }
        
        let expectation = XCTestExpectation(description: "Timer skipped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if finished {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(finished, "Timer should be skipped immediately")
    }
    
    func testPauseAndResume() {
        var pausedRemaining = 0
        var resumedRemaining = 0
        
        timerManager.start(seconds: 10)
        
        // 等待 2 秒后暂停
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if case .running(let remaining) = self.timerManager.state {
                pausedRemaining = remaining
            }
            self.timerManager.pause()
        }
        
        // 再等待 2 秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if case .paused(let remaining) = self.timerManager.state {
                resumedRemaining = remaining
                self.timerManager.resume()
            }
        }
        
        let expectation = XCTestExpectation(description: "Timer finishes after resume")
        timerManager.onFinish = {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // 暂停时的剩余时间应该等于恢复时的剩余时间
        XCTAssertEqual(pausedRemaining, resumedRemaining, "Paused and resumed remaining time should be equal")
    }
}

