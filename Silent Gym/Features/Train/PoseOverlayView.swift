//
//  PoseOverlayView.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//
//  Renders the skeleton wireframe + rep-count HUD on top of the camera preview.
//  Uses SwiftUI Canvas for GPU-efficient drawing at 30fps+.
//

#if os(iOS)
import SwiftUI
import Vision

// MARK: - Skeleton Connections

/// All joint pairs that should be connected by a line.
private let skeletonConnections: [(
    VNHumanBodyPoseObservation.JointName,
    VNHumanBodyPoseObservation.JointName
)] = [
    // Torso
    (.leftShoulder,  .rightShoulder),
    (.leftShoulder,  .leftHip),
    (.rightShoulder, .rightHip),
    (.leftHip,       .rightHip),
    // Left arm
    (.leftShoulder,  .leftElbow),
    (.leftElbow,     .leftWrist),
    // Right arm
    (.rightShoulder, .rightElbow),
    (.rightElbow,    .rightWrist),
    // Left leg
    (.leftHip,       .leftKnee),
    (.leftKnee,      .leftAnkle),
    // Right leg
    (.rightHip,      .rightKnee),
    (.rightKnee,     .rightAnkle),
    // Neck / head
    (.neck,          .leftShoulder),
    (.neck,          .rightShoulder),
]

// MARK: - PoseOverlayView

/// Canvas-based skeleton renderer.
/// `joints` are in Vision normalised space: (0,0)=bottom-left, (1,1)=top-right.
/// This view flips the Y axis and scales to its own size.
struct PoseOverlayView: View {

    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let phase: SquatPhase
    let repCount: Int
    let kneeAngle: Double
    let feedback: PoseFeedback

    var body: some View {
        ZStack {
            skeletonCanvas
            HUDCard
        }
    }

    // MARK: - Skeleton Canvas

    private var skeletonCanvas: some View {
        Canvas { ctx, size in
            // Vision → screen coordinate conversion
            func screenPoint(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let p = joints[joint] else { return nil }
                // Front camera is mirrored — flip X so left/right match user's view
                return CGPoint(x: (1 - p.x) * size.width, y: (1 - p.y) * size.height)
            }

            let lineColor = phaseColor.opacity(0.85)
            let dotColor  = Color.white.opacity(0.92)

            // Draw bone connections
            for (j1, j2) in skeletonConnections {
                guard let p1 = screenPoint(j1), let p2 = screenPoint(j2) else { continue }
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                ctx.stroke(path, with: .color(lineColor), lineWidth: 3)
            }

            // Draw joint dots
            for joint in joints.keys {
                guard let sp = screenPoint(joint) else { continue }
                let r: CGFloat = joint == .leftKnee || joint == .rightKnee ? 7 : 5
                let rect = CGRect(x: sp.x - r, y: sp.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
                // Highlight knees with accent ring
                if joint == .leftKnee || joint == .rightKnee {
                    ctx.stroke(
                        Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                        with: .color(phaseColor.opacity(0.7)),
                        lineWidth: 2
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - HUD card (rep counter + feedback)

    private var HUDCard: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                // Rep counter
                VStack(spacing: 4) {
                    Text("\(repCount)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: repCount)

                    Text("次")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(phaseColor.opacity(0.6), lineWidth: 1.5)
                )

                Spacer()

                // Feedback + angle
                VStack(alignment: .trailing, spacing: 6) {
                    if feedback != .none {
                        HStack(spacing: 6) {
                            Image(systemName: feedbackIcon)
                                .font(.caption.bold())
                                .foregroundStyle(feedbackColor)
                            Text(feedback.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(feedbackColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(feedbackColor.opacity(0.15), in: Capsule())
                        .transition(.opacity.combined(with: .scale))
                    }

                    Text("\(Int(kneeAngle))°")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Computed style helpers

    private var phaseColor: Color {
        switch phase {
        case .standing:   return .white
        case .descending: return .yellow
        case .squatting:  return .green
        case .ascending:  return .cyan
        }
    }

    private var feedbackColor: Color {
        switch feedback {
        case .good:              return .green
        case .insufficientDepth: return .orange
        case .kneesCaveIn:       return .red
        case .torsoLeaning:      return .yellow
        case .none:              return .clear
        }
    }

    private var feedbackIcon: String {
        switch feedback {
        case .good:              return "checkmark.circle.fill"
        case .insufficientDepth: return "arrow.down.circle"
        case .kneesCaveIn:       return "exclamationmark.triangle.fill"
        case .torsoLeaning:      return "figure.strengthtraining.traditional"
        case .none:              return "circle"
        }
    }
}
#endif
