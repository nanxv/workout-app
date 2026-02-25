//
//  VisionPoseTracker.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//
//  AVFoundation + Vision pipeline for real-time human body pose tracking.
//
//  Threading model:
//  ┌─ Main thread ─────────────────────────────────────────────────────────┐
//  │  @Published properties (jointPositions, repCount, …)                  │
//  │  Public start/stop/reset API                                          │
//  └───────────────────────────────────────────────────────────────────────┘
//  ┌─ videoOutputQueue (serial, QoS: userInteractive) ────────────────────┐
//  │  AVCaptureSession configuration & running                            │
//  │  VNDetectHumanBodyPoseRequest processing                             │
//  │  EMA filtering  +  State-machine update                              │
//  └───────────────────────────────────────────────────────────────────────┘
//

#if os(iOS)
import Foundation
import AVFoundation
import Vision
import CoreImage
import Combine

// MARK: - Supporting Types (pure value types, no shared mutable state)

/// Squat phase state machine stages.
enum SquatPhase: String, Equatable {
    case standing   = "站立"
    case descending = "下蹲"
    case squatting  = "深蹲"
    case ascending  = "起身"
}

/// Quality feedback categories emitted to the UI.
enum PoseFeedback: String {
    case good             = "动作标准"
    case insufficientDepth = "下蹲深度不足"
    case kneesCaveIn      = "膝盖内扣"
    case torsoLeaning     = "躯干过度前倾"
    case none             = ""
}

// MARK: - EMA Filter (per-joint smoother)

/// Exponential Moving Average filter for a 2-D joint coordinate.
/// α = 1 → no smoothing (raw); α → 0 → very heavy smoothing (laggy).
private struct EMAFilter {
    private(set) var smoothed: CGPoint?
    let alpha: Double   // Tuned to 0.30 — good balance for 30 fps

    init(alpha: Double = 0.30) { self.alpha = alpha }

    mutating func filter(_ raw: CGPoint) -> CGPoint {
        guard let s = smoothed else { smoothed = raw; return raw }
        let result = CGPoint(
            x: alpha * raw.x + (1 - alpha) * s.x,
            y: alpha * raw.y + (1 - alpha) * s.y
        )
        smoothed = result
        return result
    }

    mutating func reset() { smoothed = nil }
}

// MARK: - Squat State Machine

/// Pure-value state machine. Accessed only on `videoOutputQueue`.
private struct SquatStateMachine {
    private(set) var phase: SquatPhase = .standing
    private var prevAngle: Double = 180.0
    private var bottomAngle: Double = 180.0   // deepest point of current rep

    /// Descent starts when knee angle drops > 3° from standing.
    private static let descentThreshold: Double = 3
    /// "Squatting" counted when knee angle < 100° (configurable).
    private static let squatThreshold:   Double = 100
    /// Rep is completed when the user fully stands (angle > 155°) after squatting.
    private static let standThreshold:   Double = 155

    /// Returns whether a complete rep was detected.
    mutating func update(kneeAngle angle: Double) -> Bool {
        let delta = angle - prevAngle
        prevAngle = angle
        var repCompleted = false

        switch phase {
        case .standing:
            if delta < -Self.descentThreshold { phase = .descending }

        case .descending:
            bottomAngle = min(bottomAngle, angle)
            if angle < Self.squatThreshold {
                phase = .squatting
            } else if delta > Self.descentThreshold * 2 {
                // User reversed before reaching depth → back to standing
                phase = .standing
                bottomAngle = 180
            }

        case .squatting:
            bottomAngle = min(bottomAngle, angle)
            if delta > Self.descentThreshold { phase = .ascending }

        case .ascending:
            if angle > Self.standThreshold {
                phase = .standing
                bottomAngle = 180
                repCompleted = true
            }
        }

        return repCompleted
    }

    var reachedDepth: Bool { bottomAngle < SquatStateMachine.squatThreshold }

    mutating func reset() {
        phase = .standing
        prevAngle = 180
        bottomAngle = 180
    }
}

// MARK: - VisionPoseTracker

/// Drives the Vision + AVFoundation pipeline.
/// All @Published properties are updated on the main thread.
/// All heavy computation runs on `videoOutputQueue`.
final class VisionPoseTracker: NSObject, ObservableObject {

    // MARK: - Published state (main-thread)

    /// Smoothed, normalised joint positions.
    /// Vision coords: (0,0) = bottom-left, (1,1) = top-right.
    @Published private(set) var jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published private(set) var repCount: Int = 0
    @Published private(set) var squatPhase: SquatPhase = .standing
    /// Angle in degrees at the left knee joint (0° = fully bent).
    @Published private(set) var kneeAngle: Double = 180
    @Published private(set) var feedback: PoseFeedback = .none
    /// True once a pose is detected in the current frame.
    @Published private(set) var poseDetected: Bool = false
    /// Authorisation / session running state.
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var cameraAuthorized: Bool = false
    @Published private(set) var authorizationDenied: Bool = false

    // MARK: - AVFoundation (shared; touched only on videoOutputQueue or main)

    let captureSession = AVCaptureSession()

    // MARK: - Private (accessed exclusively on videoOutputQueue)

    private let videoOutputQueue = DispatchQueue(
        label: "com.silentgym.visionpose",
        qos: .userInteractive
    )
    private var emaFilters: [VNHumanBodyPoseObservation.JointName: EMAFilter] = [:]
    private var stateMachine = SquatStateMachine()
    // Reuse the request across frames
    private let poseRequest = VNDetectHumanBodyPoseRequest()

    // MARK: - Public API (main-thread callers)

    /// Requests camera permission then starts the capture session on the background queue.
    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
            beginSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraAuthorized = granted
                    self?.authorizationDenied = !granted
                    if granted { self?.beginSession() }
                }
            }
        case .denied, .restricted:
            authorizationDenied = true
        @unknown default:
            authorizationDenied = true
        }
    }

    func stop() {
        videoOutputQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    func resetRepCount() {
        videoOutputQueue.async { [weak self] in
            self?.stateMachine.reset()
            DispatchQueue.main.async { [weak self] in
                self?.repCount = 0
                self?.squatPhase = .standing
            }
        }
    }

    // MARK: - Session setup (runs on videoOutputQueue)

    private func beginSession() {
        videoOutputQueue.async { [weak self] in
            guard let self else { return }
            self.configureCaptureSession()
            self.captureSession.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        // Front camera for pose estimation (user faces screen)
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)

        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(output)

        // Force portrait orientation on the connection
        output.connection(with: .video)?.videoRotationAngle = 90

        captureSession.commitConfiguration()
    }

    // MARK: - Frame processing (runs on videoOutputQueue)

    private func processFrame(_ buffer: CMSampleBuffer) {
        let handler = VNImageRequestHandler(
            cmSampleBuffer: buffer,
            orientation: .up,   // Portrait, front camera already rotated
            options: [:]
        )
        do {
            try handler.perform([poseRequest])
        } catch {
            publishEmpty()
            return
        }

        guard let observation = poseRequest.results?.first else {
            publishEmpty()
            return
        }

        let smoothed = applyEMA(to: observation)
        let angle    = kneeAngleFrom(joints: smoothed)
        let repDone  = stateMachine.update(kneeAngle: angle)
        let fb       = computeFeedback(joints: smoothed, angle: angle)

        // Capture values for main-thread dispatch
        let phase    = stateMachine.phase
        let reachedD = stateMachine.reachedDepth

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.jointPositions = smoothed
            self.kneeAngle      = angle
            self.squatPhase     = phase
            self.feedback       = fb
            self.poseDetected   = true
            if repDone { self.repCount += 1 }
            _ = reachedD // surfaced via feedback
        }
    }

    private func publishEmpty() {
        DispatchQueue.main.async { [weak self] in
            self?.poseDetected   = false
            self?.jointPositions = [:]
        }
    }

    // MARK: - EMA filtering

    private func applyEMA(
        to observation: VNHumanBodyPoseObservation
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var result: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        // Process all recognised joints
        guard let recognisedPoints = try? observation.recognizedPoints(.all) else { return result }

        for (name, point) in recognisedPoints where point.confidence > 0.35 {
            let raw = CGPoint(x: point.x, y: point.y)
            let filtered = emaFilters[name, default: EMAFilter()].filter(raw)
            emaFilters[name] = emaFilters[name] ?? EMAFilter()
            // Re-read and update (dict copy semantics)
            var f = emaFilters[name, default: EMAFilter()]
            let out = f.filter(raw)
            emaFilters[name] = f
            result[name] = out
            _ = filtered // first call discarded; second one stored
        }

        // Simplified — single-pass, readable version:
        result = [:]
        for (name, point) in recognisedPoints where point.confidence > 0.35 {
            let raw = CGPoint(x: point.x, y: point.y)
            var filter = emaFilters[name, default: EMAFilter()]
            result[name] = filter.filter(raw)
            emaFilters[name] = filter
        }

        return result
    }

    // MARK: - Geometry

    /// Angle (°) at the knee formed by hip–knee–ankle on the left side.
    /// Falls back to right side if left is unavailable.
    private func kneeAngleFrom(
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> Double {
        let sides: [(
            hip: VNHumanBodyPoseObservation.JointName,
            knee: VNHumanBodyPoseObservation.JointName,
            ankle: VNHumanBodyPoseObservation.JointName
        )] = [
            (.leftHip,  .leftKnee,  .leftAnkle),
            (.rightHip, .rightKnee, .rightAnkle)
        ]
        for side in sides {
            if let hip   = joints[side.hip],
               let knee  = joints[side.knee],
               let ankle = joints[side.ankle] {
                return angleDegrees(a: hip, b: knee, c: ankle)
            }
        }
        return 180
    }

    /// Angle at vertex B, formed by rays B→A and B→C.
    private func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ba = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let bc = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot   = ba.dx * bc.dx + ba.dy * bc.dy
        let magBA = sqrt(ba.dx * ba.dx + ba.dy * ba.dy)
        let magBC = sqrt(bc.dx * bc.dx + bc.dy * bc.dy)
        guard magBA > 0, magBC > 0 else { return 180 }
        let cosVal = max(-1, min(1, Double(dot / (magBA * magBC))))
        return acos(cosVal) * 180 / .pi
    }

    // MARK: - Quality Feedback

    private func computeFeedback(
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        angle: Double
    ) -> PoseFeedback {
        guard squatPhase == .squatting || squatPhase == .ascending else { return .none }

        // Insufficient depth check
        if squatPhase == .squatting && angle > 105 {
            return .insufficientDepth
        }

        // Knee cave-in: left knee x should be close to left ankle x in normalised coords
        if let lKnee  = joints[.leftKnee],
           let lAnkle = joints[.leftAnkle] {
            let lateralDeviation = abs(lKnee.x - lAnkle.x)
            if lateralDeviation > 0.07 { return .kneesCaveIn }
        }

        // Excessive torso lean: shoulder x vs hip x vs knee x
        if let lShoulder = joints[.leftShoulder],
           let lHip      = joints[.leftHip],
           let lKnee     = joints[.leftKnee] {
            // In Vision coords y=0 is bottom. Torso vector angle from vertical
            let trunkDx = lShoulder.x - lHip.x
            let trunkDy = lShoulder.y - lHip.y   // should be positive (shoulder above hip)
            if abs(trunkDy) > 0 {
                let leanAngle = abs(atan(trunkDx / trunkDy)) * 180 / .pi
                if leanAngle > 40 { return .torsoLeaning }
            }
            _ = lKnee
        }

        return .good
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VisionPoseTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called on `videoOutputQueue` for every captured frame.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processFrame(sampleBuffer)
    }
}
#endif
