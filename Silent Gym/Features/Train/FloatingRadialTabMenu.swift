//
//  FloatingRadialTabMenu.swift
//  Silent Gym
//
//  Phase 2: staggered spring entrance, selection haptics, improved highlight animation.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

public struct FloatingRadialTabMenu: View {

    // MARK: - Constants

    public enum Constants {
        static let radius: CGFloat = 108
        static let buttonSize: CGFloat = 46
        static let highlightedScale: CGFloat = 1.28
        static let overlayOpacity: Double = 0.45
    }

    // MARK: - State

    private let currentTab: AppTab
    private let center: CGPoint
    @Binding private var highlightedTab: AppTab?
    private let onSelect: (AppTab) -> Void
    private let onCancel: () -> Void

    private let allTabs: [AppTab]

    /// Drives the staggered entrance animation.
    @State private var appeared = false
    /// Tracks previous highlight to fire haptic only on change.
    @State private var lastHighlighted: AppTab? = nil

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
                // Dimmed backdrop
                Color.black.opacity(appeared ? Constants.overlayOpacity : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }
                    .animation(.easeOut(duration: 0.22), value: appeared)

                // Tab buttons — spring in with staggered delay
                ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                    let angle = angleForIndex(index: index, totalCount: allTabs.count)
                    let dest = CGPoint(
                        x: center.x + Constants.radius * cos(angle),
                        y: center.y + Constants.radius * sin(angle)
                    )
                    let isHighlighted = highlightedTab == tab
                    let isCurrent = tab == currentTab

                    Button { onSelect(tab) } label: {
                        tabButtonContent(for: tab, highlighted: isHighlighted, current: isCurrent)
                            .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(
                        appeared
                            ? (isHighlighted ? Constants.highlightedScale : 1.0)
                            : 0.05
                    )
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.68)
                            .delay(appeared ? Double(index) * 0.055 : 0),
                        value: appeared
                    )
                    .animation(
                        .spring(response: 0.25, dampingFraction: 0.65),
                        value: isHighlighted
                    )
                    .position(dest)
                    .accessibilityLabel(tabAccessibilityLabel(tab))
                }

                // Invisible gesture layer covering the full radial area
                gestureOverlay(in: geo.size)
            }
        }
        .onAppear {
            // Tiny async to let the view settle before triggering entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                appeared = true
            }
        }
        .onChange(of: highlightedTab) { _, newTab in
            guard newTab != lastHighlighted else { return }
            lastHighlighted = newTab
            if newTab != nil {
                #if os(iOS)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
            }
        }
    }

    // MARK: - Gesture overlay

    @ViewBuilder
    private func gestureOverlay(in size: CGSize) -> some View {
        Circle()
            .fill(Color.clear)
            .frame(width: Constants.buttonSize, height: Constants.buttonSize)
            .position(center)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateHighlight(location: value.location)
                    }
                    .onEnded { _ in
                        if let selected = highlightedTab {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            onSelect(selected)
                        } else {
                            onCancel()
                        }
                    }
            )
    }

    // MARK: - Button content

    @ViewBuilder
    private func tabButtonContent(for tab: AppTab, highlighted: Bool, current: Bool) -> some View {
        ZStack {
            Circle()
                .fill(highlighted ? Color.accentColor : Color.black.opacity(0.72))
                .overlay(
                    Circle()
                        .stroke(
                            current ? Color.accentColor : Color.white.opacity(0.18),
                            lineWidth: current ? 2.5 : 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

            Image(systemName: tab.icon)
                .resizable()
                .scaledToFit()
                .foregroundColor(highlighted || current ? .white : .white.opacity(0.85))
                .padding(highlighted ? 10 : 11)
        }
    }

    // MARK: - Highlight logic

    private func updateHighlight(location: CGPoint) {
        let vec = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let dist = hypot(vec.dx, vec.dy)
        guard dist > Constants.buttonSize / 2 else {
            highlightedTab = nil
            return
        }
        var angle = atan2(vec.dy, vec.dx)
        if angle < 0 { angle += 2 * .pi }

        var closest: AppTab? = nil
        var minDiff = CGFloat.greatestFiniteMagnitude
        for (idx, tab) in allTabs.enumerated() {
            let tabAngle = angleForIndex(index: idx, totalCount: allTabs.count)
            let diff = abs(shortestAngle(tabAngle, angle))
            if diff < minDiff { minDiff = diff; closest = tab }
        }
        let threshold = CGFloat.pi / CGFloat(allTabs.count)
        highlightedTab = (minDiff < threshold) ? closest : nil
    }

    // MARK: - Angle math

    private func angleForIndex(index: Int, totalCount: Int) -> CGFloat {
        let start = -CGFloat.pi / 2
        let step = 2 * CGFloat.pi / CGFloat(max(totalCount, 1))
        return start + step * CGFloat(index)
    }

    private func shortestAngle(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
        let twoPi = 2 * CGFloat.pi
        var a = (a1 - a2).truncatingRemainder(dividingBy: twoPi)
        if a >= .pi { a -= twoPi }
        if a <= -.pi { a += twoPi }
        return a
    }

    // MARK: - Accessibility

    private func tabAccessibilityLabel(_ tab: AppTab) -> Text {
        Text("切换到\(tab.rawValue)页")
    }

    // MARK: - Tab ordering

    private static func computeAllTabs(currentTab: AppTab) -> [AppTab] {
        let cases = Array(AppTab.allCases)
        guard let idx = cases.firstIndex(of: currentTab) else { return cases }
        let center = (cases.count - 1) / 2
        let shift = idx - center
        return (0..<cases.count).map { cases[($0 + shift + cases.count) % cases.count] }
    }

    // MARK: - Static helper for MainTabViewWireframe gesture

    static func closestTab(location: CGPoint, center: CGPoint, currentTab: AppTab) -> AppTab? {
        let tabs = computeAllTabs(currentTab: currentTab)
        let vec = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let dist = hypot(vec.dx, vec.dy)
        guard dist > Constants.buttonSize / 2 else { return nil }

        var angle = atan2(vec.dy, vec.dx)
        if angle < 0 { angle += 2 * .pi }

        let step = 2 * CGFloat.pi / CGFloat(max(tabs.count, 1))
        let start = -CGFloat.pi / 2

        var best: AppTab? = nil
        var minDiff = CGFloat.greatestFiniteMagnitude
        for (i, tab) in tabs.enumerated() {
            var tabAngle = start + step * CGFloat(i)
            if tabAngle < 0 { tabAngle += 2 * .pi }
            let twoPi = 2 * CGFloat.pi
            var diff = (tabAngle - angle).truncatingRemainder(dividingBy: twoPi)
            if diff >= .pi { diff -= twoPi }
            if diff <= -.pi { diff += twoPi }
            let d = abs(diff)
            if d < minDiff { minDiff = d; best = tab }
        }
        return minDiff < (.pi / CGFloat(tabs.count)) ? best : nil
    }
}
