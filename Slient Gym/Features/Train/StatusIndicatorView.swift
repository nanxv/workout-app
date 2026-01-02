//
//  StatusIndicatorView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
#if os(iOS)
import HealthKit
#endif

struct StatusIndicatorView: View {
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var healthManager = HealthImportManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Watch 连接状态
            WatchStatusIndicator()
            
            // Health 授权状态
            HealthStatusIndicator()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct WatchStatusIndicator: View {
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text("Watch")
                .font(.caption)
            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        if watchConnectivity.isWatchReachable {
            return .green
        } else if watchConnectivity.isWatchPaired {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if watchConnectivity.isWatchReachable {
            return "已连接"
        } else if watchConnectivity.isWatchPaired {
            return "已配对"
        } else {
            return "未连接"
        }
    }
}

struct HealthStatusIndicator: View {
    @StateObject private var healthManager = HealthImportManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text("Health")
                .font(.caption)
            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch healthManager.authorizationStatus {
        case .sharingAuthorized:
            return .green
        case .sharingDenied:
            return .orange
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch healthManager.authorizationStatus {
        case .sharingAuthorized:
            return "已授权"
        case .sharingDenied:
            return "已拒绝"
        case .notDetermined:
            return "未授权"
        @unknown default:
            return "未知"
        }
    }
}

#Preview {
    StatusIndicatorView()
}

