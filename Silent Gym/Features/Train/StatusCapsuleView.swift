//
//  StatusCapsuleView.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import Combine
#if os(iOS)
import HealthKit
import EventKit

struct StatusCapsuleView: View {
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var healthManager = HealthStatusManager.shared
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var isExpanded = false
    @State private var showPermissionGuide: PermissionType?
    @AppStorage("statusCapsuleMinimized") private var isMinimized = false
    @AppStorage("statusCapsuleDismissed") private var isDismissed = false
    
    var body: some View {
        if isDismissed && !isExpanded {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                // 紧凑胶囊
                HStack(spacing: 12) {
                    // Watch 状态点
                    StatusCapsuleDot(
                        color: watchStatusColor,
                        icon: "applewatch",
                        onTap: { isExpanded.toggle() }
                    )
                    
                    // Health 状态点
                    StatusCapsuleDot(
                        color: healthStatusColor,
                        icon: "heart.fill",
                        onTap: { isExpanded.toggle() }
                    )
                    
                    // Calendar 状态点
                    StatusCapsuleDot(
                        color: calendarStatusColor,
                        icon: "calendar",
                        onTap: { isExpanded.toggle() }
                    )
                    
                    Spacer()
                    
                    // 折叠/展开按钮
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // 展开抽屉
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        
                        // Watch 状态详情
                        StatusDetailRow(
                            title: "Apple Watch",
                            status: watchStatusText,
                            color: watchStatusColor,
                            actionTitle: watchActionTitle,
                            action: {
                                if !watchConnectivity.isWatchPaired || !watchConnectivity.isWatchAppInstalled {
                                    showPermissionGuide = .watch
                                }
                            }
                        )
                        
                        // Health 状态详情
                        StatusDetailRow(
                            title: "HealthKit",
                            status: healthStatusText,
                            color: healthStatusColor,
                            actionTitle: healthActionTitle,
                            action: {
                                if healthManager.authorizationStatus != .sharingAuthorized {
                                    showPermissionGuide = .healthKit
                                }
                            }
                        )
                        
                        // Calendar 状态详情
                        StatusDetailRow(
                            title: "Calendar",
                            status: calendarStatusText,
                            color: calendarStatusColor,
                            actionTitle: calendarActionTitle,
                            action: {
                                let status = calendarManager.authorizationStatus
                                if #available(iOS 17.0, *) {
                                    if status != .fullAccess {
                                        showPermissionGuide = .calendar
                                    }
                                } else {
                                    if status != .authorized {
                                        showPermissionGuide = .calendar
                                    }
                                }
                            }
                        )
                        
                        Divider()
                        
                        // 选项
                        HStack {
                            Button("本次不再提示") {
                                isDismissed = true
                                isExpanded = false
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Toggle("始终最小化", isOn: $isMinimized)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(item: $showPermissionGuide) { permissionType in
                PermissionGuideView(permissionType: permissionType)
            }
        }
    }
    
    // MARK: - Watch Status
    
    private var watchStatusColor: Color {
        if watchConnectivity.isWatchPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isWatchReachable {
            return .green
        } else if watchConnectivity.isWatchPaired && watchConnectivity.isWatchAppInstalled {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var watchStatusText: String {
        if watchConnectivity.isWatchPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isWatchReachable {
            return "已连接"
        } else if watchConnectivity.isWatchPaired && watchConnectivity.isWatchAppInstalled {
            return "不可达"
        } else if watchConnectivity.isWatchPaired {
            return "未安装应用"
        } else {
            return "未配对"
        }
    }
    
    private var watchActionTitle: String? {
        if !watchConnectivity.isWatchPaired || !watchConnectivity.isWatchAppInstalled {
            return "查看设置"
        }
        return nil
    }
    
    // MARK: - Health Status
    
    private var healthStatusColor: Color {
        switch healthManager.authorizationStatus {
        case .sharingAuthorized:
            return .green
        case .notDetermined:
            return .gray
        case .sharingDenied:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var healthStatusText: String {
        switch healthManager.authorizationStatus {
        case .sharingAuthorized:
            return "已授权"
        case .notDetermined:
            return "未授权"
        case .sharingDenied:
            return "已拒绝"
        @unknown default:
            return "未知"
        }
    }
    
    private var healthActionTitle: String? {
        if healthManager.authorizationStatus != .sharingAuthorized {
            return "去授权"
        }
        return nil
    }
    
    // MARK: - Calendar Status
    
    private var calendarStatusColor: Color {
        let status = calendarManager.authorizationStatus
        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess:
                return .green
            case .notDetermined:
                return .gray
            case .denied, .restricted, .writeOnly:
                return .orange
            @unknown default:
                return .gray
            }
        } else {
            // iOS 16 and earlier
            switch status {
            case .authorized:
                return .green
            case .notDetermined:
                return .gray
            case .denied:
                return .orange
            case .restricted:
                return .orange
            case .fullAccess:
                // iOS 17+ only, but included for completeness
                return .green
            case .writeOnly:
                // iOS 17+ only, but included for completeness
                return .orange
            @unknown default:
                return .gray
            }
        }
    }
    
    private var calendarStatusText: String {
        let status = calendarManager.authorizationStatus
        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess:
                return "已授权"
            case .notDetermined:
                return "未授权"
            case .denied, .restricted, .writeOnly:
                return "已拒绝"
            @unknown default:
                return "未知"
            }
        } else {
            // iOS 16 and earlier
            switch status {
            case .authorized:
                return "已授权"
            case .notDetermined:
                return "未授权"
            case .denied:
                return "已拒绝"
            case .restricted:
                return "已拒绝"
            case .fullAccess:
                // iOS 17+ only, but included for completeness
                return "已授权"
            case .writeOnly:
                // iOS 17+ only, but included for completeness
                return "已拒绝"
            @unknown default:
                return "未知"
            }
        }
    }
    
    private var calendarActionTitle: String? {
        let status = calendarManager.authorizationStatus
        if #available(iOS 17.0, *) {
            if status != .fullAccess {
                return "去授权"
            }
        } else {
            if status != .authorized {
                return "去授权"
            }
        }
        return nil
    }
}

struct StatusCapsuleDot: View {
    let color: Color
    let icon: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .buttonStyle(.plain)
    }
}

struct StatusDetailRow: View {
    let title: String
    let status: String
    let color: Color
    let actionTitle: String?
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: iconForTitle(title))
                .foregroundColor(color)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private func iconForTitle(_ title: String) -> String {
        switch title {
        case "Apple Watch":
            return "applewatch"
        case "HealthKit":
            return "heart.fill"
        case "Calendar":
            return "calendar"
        default:
            return "circle"
        }
    }
}
#endif

