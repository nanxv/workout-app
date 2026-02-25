//
//  StatusIndicatorView.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import Combine
#if os(iOS)
import HealthKit

struct StatusIndicatorView: View {
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var healthManager = HealthStatusManager.shared
    @State private var showPermissionGuide: PermissionType?
    
    var body: some View {
        HStack(spacing: 16) {
            // Watch 连接状态
            WatchStatusIndicator(
                isPaired: watchConnectivity.isWatchPaired,
                isReachable: watchConnectivity.isWatchReachable,
                isInstalled: watchConnectivity.isWatchAppInstalled
            )
            
            // Health 授权状态
            HealthStatusIndicator(
                authorizationStatus: healthManager.authorizationStatus,
                onTap: {
                    if healthManager.authorizationStatus != .sharingAuthorized {
                        showPermissionGuide = .healthKit
                    }
                }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .sheet(item: $showPermissionGuide) { permissionType in
            PermissionGuideView(permissionType: permissionType)
        }
    }
}

struct WatchStatusIndicator: View {
    let isPaired: Bool
    let isReachable: Bool
    let isInstalled: Bool
    
    var status: (color: Color, icon: String, text: String) {
        if isPaired && isInstalled && isReachable {
            return (.green, "applewatch", "Watch 已连接")
        } else if isPaired && isInstalled {
            return (.orange, "applewatch", "Watch 不可达")
        } else if isPaired {
            return (.orange, "applewatch.slash", "Watch 未安装")
        } else {
            return (.gray, "applewatch.slash", "未配对")
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.caption)
            Text(status.text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct HealthStatusIndicator: View {
    let authorizationStatus: HKAuthorizationStatus
    let onTap: () -> Void
    
    var status: (color: Color, icon: String, text: String) {
        switch authorizationStatus {
        case .sharingAuthorized:
            return (.green, "heart.fill", "Health 已授权")
        case .notDetermined:
            return (.gray, "heart.slash", "Health 未授权")
        case .sharingDenied:
            return (.orange, "heart.slash.fill", "Health 已拒绝")
        @unknown default:
            return (.gray, "heart.slash", "未知状态")
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .font(.caption)
                Text(status.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

@MainActor
class HealthStatusManager: ObservableObject {
    static let shared = HealthStatusManager()
    
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    private let healthStore = HKHealthStore()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .notDetermined
            return
        }
        
        let workoutType = HKObjectType.workoutType()
        authorizationStatus = healthStore.authorizationStatus(for: workoutType)
    }
    
    func refresh() {
        checkAuthorizationStatus()
    }
}
#endif

