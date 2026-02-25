import SwiftUI
import Foundation

public struct FloatingRadialTabMenu: View {
    public enum Constants {
        static let radius: CGFloat = 100
        static let buttonSize: CGFloat = 44
        static let highlightedScale: CGFloat = 1.3
        static let overlayOpacity: Double = 0.5
    }

    private let currentTab: AppTab
    private let center: CGPoint
    @Binding private var highlightedTab: AppTab?
    private let onSelect: (AppTab) -> Void
    private let onCancel: () -> Void

    private let allTabs: [AppTab]

    // MARK: - Init

    init(
        currentTab: AppTab,
        center: CGPoint,
        highlightedTab: Binding<AppTab?>,
        onSelect: @escaping (AppTab) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentTab = currentTab
        self.center = center
        self._highlightedTab = highlightedTab
        self.onSelect = onSelect
        self.onCancel = onCancel
        self.allTabs = FloatingRadialTabMenu.computeAllTabs(currentTab: currentTab)
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(Constants.overlayOpacity)
                    .edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCancel()
                    }

                // The center hub (invisible, for gesture reference)
                Circle()
                    .fill(Color.clear)
                    .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    .position(center)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateHighlight(relativeDragLocation: value.location, in: geo.size)
                            }
                            .onEnded { _ in
                                if let selected = highlightedTab {
                                    onSelect(selected)
                                } else {
                                    onCancel()
                                }
                            }
                    )

                ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                    let angle = angleForIndex(index: index, totalCount: allTabs.count)
                    let buttonCenter = CGPoint(
                        x: center.x + Constants.radius * cos(angle),
                        y: center.y + Constants.radius * sin(angle)
                    )

                    Button(action: {
                        onSelect(tab)
                    }) {
                        tabButtonContent(for: tab)
                            .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                            .scaleEffect(highlightedTab == tab ? Constants.highlightedScale : 1)
                            .overlay(
                                Circle()
                                    .stroke(highlightedTab == tab ? Color.accentColor : Color.clear, lineWidth: 3)
                            )
                            .animation(.easeInOut(duration: 0.15), value: highlightedTab == tab)
                            .accessibilityLabel(tabAccessibilityLabel(tab))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .position(buttonCenter)
                }
            }
        }
    }

    // MARK: - Helpers

    private func updateHighlight(relativeDragLocation location: CGPoint, in size: CGSize) {
        // Calculate vector from center to current drag location
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let distance = hypot(vector.dx, vector.dy)

        // Threshold: consider only if drag is outside a small inner circle to avoid immediate highlight
        guard distance > Constants.buttonSize / 2 else {
            highlightedTab = nil
            return
        }

        // Calculate angle from center to drag location, normalized to 0..2pi with 0 at +x axis
        var dragAngle = atan2(vector.dy, vector.dx)
        if dragAngle < 0 {
            dragAngle += 2 * .pi
        }

        // Find closest tab by comparing dragAngle to tab angles
        var closestTab: AppTab? = nil
        var minAngleDiff = CGFloat.greatestFiniteMagnitude

        for (index, tab) in allTabs.enumerated() {
            let tabAngle = angleForIndex(index: index, totalCount: allTabs.count)
            // Compute shortest angular distance
            let diff = abs(shortestAngleBetween(tabAngle, dragAngle))
            if diff < minAngleDiff {
                minAngleDiff = diff
                closestTab = tab
            }
        }

        // Consider highlight only if angle difference is within a certain threshold (~π/ (number of tabs))
        if let closest = closestTab {
            let threshold = .pi / CGFloat(allTabs.count)
            if minAngleDiff < threshold {
                highlightedTab = closest
            } else {
                highlightedTab = nil
            }
        } else {
            highlightedTab = nil
        }
    }

    private func angleForIndex(index: Int, totalCount: Int) -> CGFloat {
        // Distribute tabs evenly around circle starting from -90 degrees (top)
        let startAngle = -CGFloat.pi / 2
        let angleIncrement = 2 * CGFloat.pi / CGFloat(max(totalCount, 1))
        return startAngle + angleIncrement * CGFloat(index)
    }

    private func shortestAngleBetween(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
        let twoPi = 2 * CGFloat.pi
        var angle = (a1 - a2).truncatingRemainder(dividingBy: twoPi)
        if angle >= CGFloat.pi {
            angle -= twoPi
        }
        if angle <= -CGFloat.pi {
            angle += twoPi
        }
        return angle
    }

    @ViewBuilder
    private func tabButtonContent(for tab: AppTab) -> some View {
        Image(systemName: tab.icon)
            .resizable()
            .scaledToFit()
            .foregroundColor(tab == currentTab ? .accentColor : .primary)
            .padding(8)
    }

    private func tabAccessibilityLabel(_ tab: AppTab) -> Text {
        Text("Switch to \(tab.rawValue) tab")
    }

    // MARK: - allTabs Computation

    /// Reorder allCases so that currentTab is in the center of the fan.
    /// For 4 tabs with currentTab at index 2: reorder to [1, 2, 3, 0] so index 2 is at position 1 (center-ish).
    private static func computeAllTabs(currentTab: AppTab) -> [AppTab] {
        let cases = Array(AppTab.allCases)
        guard let currentIndex = cases.firstIndex(of: currentTab) else {
            return cases
        }
        
        let count = cases.count
        // Calculate offset to center currentTab in the array
        // For even count, center is at count/2 - 1 or count/2
        let centerIndex = (count - 1) / 2
        let shift = currentIndex - centerIndex
        
        // Rotate array so currentTab ends up at centerIndex
        var result: [AppTab] = []
        for i in 0..<count {
            let sourceIndex = (i + shift + count) % count
            result.append(cases[sourceIndex])
        }
        return result
    }

    // MARK: - Static helper for external use

    static func closestTab(
        location: CGPoint,
        center: CGPoint,
        currentTab: AppTab
    ) -> AppTab? {
        let allTabs = computeAllTabs(currentTab: currentTab)
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let distance = hypot(vector.dx, vector.dy)
        
        guard distance > Constants.buttonSize / 2 else {
            return nil
        }
        
        var dragAngle = atan2(vector.dy, vector.dx)
        if dragAngle < 0 {
            dragAngle += 2 * .pi
        }
        
        var closestTab: AppTab? = nil
        var minAngleDiff = CGFloat.greatestFiniteMagnitude
        let count = allTabs.count
        
        for (index, tab) in allTabs.enumerated() {
            let startAngle = -CGFloat.pi / 2
            let angleIncrement = 2 * CGFloat.pi / CGFloat(max(count, 1))
            let tabAngle = startAngle + angleIncrement * CGFloat(index)
            
            var normalizedTabAngle = tabAngle
            if normalizedTabAngle < 0 {
                normalizedTabAngle += 2 * .pi
            }
            
            let twoPi = 2 * CGFloat.pi
            var angleDiff = (normalizedTabAngle - dragAngle).truncatingRemainder(dividingBy: twoPi)
            if angleDiff >= CGFloat.pi {
                angleDiff -= twoPi
            }
            if angleDiff <= -CGFloat.pi {
                angleDiff += twoPi
            }
            
            let diff = abs(angleDiff)
            if diff < minAngleDiff {
                minAngleDiff = diff
                closestTab = tab
            }
        }
        
        let threshold = CGFloat.pi / CGFloat(count)
        if minAngleDiff < threshold {
            return closestTab
        }
        return nil
    }
}
