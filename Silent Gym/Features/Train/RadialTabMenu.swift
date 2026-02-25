import SwiftUI

struct RadialTabMenu: View {
    let tabs: [AppTab]
    let currentTab: AppTab
    let center: CGPoint
    @Binding var highlightedTab: AppTab?
    let onSelect: (AppTab) -> Void
    let onCancel: () -> Void

    @State private var touchLocation: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }

                ZStack {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        let angle = Angle(degrees: Double(index) / Double(max(1, tabs.count)) * 360.0)
                        let radius: CGFloat = 80
                        let pos = CGPoint(
                            x: center.x + CGFloat(cos(angle.radians)) * radius,
                            y: center.y + CGFloat(sin(angle.radians)) * radius
                        )

                        VStack(spacing: 6) {
                            Image(systemName: tabSystemImage(tab))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(circleBackground(for: tab))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                                .onTapGesture { onSelect(tab) }

                            Text(tabTitle(tab))
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .padding(4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .position(pos)
                    }
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touchLocation = value.location
                        highlightedTab = nearestTab(to: value.location)
                    }
                    .onEnded { _ in
                        if let selected = highlightedTab {
                            onSelect(selected)
                        } else {
                            onCancel()
                        }
                        highlightedTab = nil
                        touchLocation = nil
                    }
                )
            }
        }
    }

    private func circleBackground(for tab: AppTab) -> some ShapeStyle {
        let isHighlighted = (highlightedTab != nil && areTabsEqual(highlightedTab!, tab)) || areTabsEqual(currentTab, tab)
        return isHighlighted ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color.black.opacity(0.7))
    }

    private func areTabsEqual(_ lhs: AppTab, _ rhs: AppTab) -> Bool {
        // Try to use Equatable conformance, fallback to String comparison
        if let lhsEquatable = lhs as? any Equatable,
           let rhsEquatable = rhs as? any Equatable {
            return String(describing: lhsEquatable) == String(describing: rhsEquatable)
        } else {
            return String(describing: lhs) == String(describing: rhs)
        }
    }

    private func nearestTab(to point: CGPoint) -> AppTab? {
        guard !tabs.isEmpty else { return nil }
        let radius: CGFloat = 80
        var best: (tab: AppTab, dist: CGFloat)? = nil
        for (index, tab) in tabs.enumerated() {
            let angle = Angle(degrees: Double(index) / Double(max(1, tabs.count)) * 360.0)
            let pos = CGPoint(
                x: center.x + CGFloat(cos(angle.radians)) * radius,
                y: center.y + CGFloat(sin(angle.radians)) * radius
            )
            let d = hypot(pos.x - point.x, pos.y - point.y)
            if best == nil || d < best!.dist { best = (tab, d) }
        }
        if let best, best.dist < 44 { return best.tab }
        return nil
    }

    private func tabTitle(_ tab: AppTab) -> String {
        // Try best known tab titles, fallback to description
        let desc = String(describing: tab).lowercased()
        switch desc {
        case "home":
            return "Home"
        case "train":
            return "Train"
        case "stats":
            return "Stats"
        case "settings":
            return "Settings"
        default:
            return String(describing: tab)
        }
    }

    private func tabSystemImage(_ tab: AppTab) -> String {
        // Map known tabs to system images, fallback generic
        let desc = String(describing: tab).lowercased()
        switch desc {
        case "home":
            return "house.fill"
        case "train":
            return "tram.fill"
        case "stats":
            return "chart.bar.fill"
        case "settings":
            return "gearshape.fill"
        default:
            return "circle.fill"
        }
    }

    // Usage: RadialTabMenu(tabs: AppTab.allCases, currentTab: ..., center: ..., highlightedTab: ..., onSelect: ..., onCancel: ...)
}

#if DEBUG && !canImport(AppTab)
// Preview shim for AppTab if not available
struct RadialTabMenu_Previews: PreviewProvider {
    enum MockTab: String, CaseIterable {
        case home, train, stats, settings
    }
    struct PreviewWrapper: View {
        @State var current: MockTab = .home
        @State var highlighted: MockTab? = nil
        var body: some View {
            GeometryReader { geo in
                RadialTabMenuMock(
                    currentTab: current,
                    center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                    tabs: RadialTabMenu_Previews.MockTab.allCases,
                    highlightedTab: $highlighted,
                    onSelect: { current = $0 },
                    onCancel: {}
                )
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}

fileprivate struct RadialTabMenuMock: View {
    let currentTab: RadialTabMenu_Previews.MockTab
    let center: CGPoint
    let tabs: [RadialTabMenu_Previews.MockTab]
    @Binding var highlightedTab: RadialTabMenu_Previews.MockTab?
    let onSelect: (RadialTabMenu_Previews.MockTab) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

            ZStack {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    let angle = Angle(degrees: Double(index) / Double(max(1, tabs.count)) * 360)
                    let radius: CGFloat = 80
                    let pos = CGPoint(
                        x: center.x + CGFloat(cos(angle.radians)) * radius,
                        y: center.y + CGFloat(sin(angle.radians)) * radius
                    )

                    VStack(spacing: 6) {
                        Image(systemName: tabSystemImage(tab))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(circleBackground(for: tab))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .onTapGesture { onSelect(tab) }

                        Text(tabTitle(tab))
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .padding(4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .position(pos)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    highlightedTab = nearestTab(to: value.location)
                }
                .onEnded { _ in
                    if let selected = highlightedTab {
                        onSelect(selected)
                    } else {
                        onCancel()
                    }
                    highlightedTab = nil
                }
            )
        }
    }

    private func circleBackground(for tab: RadialTabMenu_Previews.MockTab) -> some ShapeStyle {
        let isHighlighted = highlightedTab == tab || currentTab == tab
        return isHighlighted ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color.black.opacity(0.7))
    }

    private func nearestTab(to point: CGPoint) -> RadialTabMenu_Previews.MockTab? {
        let radius: CGFloat = 80
        var best: (tab: RadialTabMenu_Previews.MockTab, dist: CGFloat)? = nil
        for (index, tab) in tabs.enumerated() {
            let angle = Angle(degrees: Double(index) / Double(max(1, tabs.count)) * 360.0)
            let pos = CGPoint(
                x: center.x + CGFloat(cos(angle.radians)) * radius,
                y: center.y + CGFloat(sin(angle.radians)) * radius
            )
            let d = hypot(pos.x - point.x, pos.y - point.y)
            if best == nil || d < best!.dist { best = (tab, d) }
        }
        if let best, best.dist < 44 { return best.tab }
        return nil
    }

    private func tabTitle(_ tab: RadialTabMenu_Previews.MockTab) -> String {
        switch tab {
        case .home: return "Home"
        case .train: return "Train"
        case .stats: return "Stats"
        case .settings: return "Settings"
        }
    }

    private func tabSystemImage(_ tab: RadialTabMenu_Previews.MockTab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .train: return "tram.fill"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
#endif
