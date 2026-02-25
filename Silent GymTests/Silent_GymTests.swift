import XCTest
import CoreGraphics
@testable import Silent_Gym

@MainActor
final class Silent_GymTests: XCTestCase {
    private var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "SilentGymTests")!
        testDefaults.removePersistentDomain(forName: "SilentGymTests")
    }
    
    func testAppModuleLoads() {
        XCTAssertTrue(true)
    }
    
    func testFloatingBallStateRestUpdatesResetPause() {
        let result = FloatingBallState.restStateUpdate(
            isActive: false,
            remaining: 0,
            total: 0,
            wasPaused: true
        )
        XCTAssertFalse(result.isPaused)
        XCTAssertFalse(result.isResting)
    }
    
    func testFloatingBallStateExerciseInfoClamps() {
        let normalized = FloatingBallState.normalizedExerciseInfo(setIndex: -2, totalSets: -3)
        XCTAssertEqual(normalized.setIndex, 0)
        XCTAssertEqual(normalized.totalSets, 0)
    }
    
    func testFloatingBallPositionPersistAndRestore() {
        let point = CGPoint(x: 120, y: 240)
        FloatingBallState.persistPosition(point, storage: testDefaults)
        
        let restored = FloatingBallState.restorePosition(
            in: CGRect(x: 0, y: 0, width: 300, height: 600),
            storage: testDefaults
        )
        
        XCTAssertEqual(restored.x, point.x)
        XCTAssertEqual(restored.y, point.y)
    }
    
    func testSnapToEdges() {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        let leftPoint = CGPoint(x: 40, y: 200)
        let rightPoint = CGPoint(x: 260, y: 200)
        
        let snappedLeft = snapToEdges(point: leftPoint, in: frame)
        let snappedRight = snapToEdges(point: rightPoint, in: frame)
        
        XCTAssertLessThan(snappedLeft.x, frame.midX)
        XCTAssertGreaterThan(snappedRight.x, frame.midX)
    }
    
    func testRestTimerStartAndFinish() {
        let timer = RestTimerManager()
        let finishExpectation = expectation(description: "rest timer finishes")
        
        timer.onFinish = {
            finishExpectation.fulfill()
        }
        
        timer.start(seconds: 1)
        wait(for: [finishExpectation], timeout: 2.0)
        XCTAssertEqual(timer.state, .off)
    }
    
    func testRestTimerPauseResume() {
        let timer = RestTimerManager()
        let finishExpectation = expectation(description: "rest timer finishes after resume")
        
        timer.onFinish = {
            finishExpectation.fulfill()
        }
        
        timer.start(seconds: 2)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            timer.pause()
            XCTAssertEqual(timer.state, .paused(remaining: timer.remainingSeconds))
            timer.resume()
        }
        
        wait(for: [finishExpectation], timeout: 3.0)
        XCTAssertEqual(timer.state, .off)
    }
}
