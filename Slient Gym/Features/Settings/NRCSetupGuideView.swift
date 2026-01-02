//
//  NRCSetupGuideView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI

struct NRCSetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importManager = HealthImportManager.shared
    @State private var hasNRC = false
    @State private var isChecking = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nike Run Club 同步设置")
                            .font(.title2)
                            .bold()
                        Text("将 NRC 跑步记录同步到 Apple 健康，然后在此应用中查看")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Status
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if isChecking {
                                ProgressView()
                            } else {
                                Image(systemName: hasNRC ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(hasNRC ? .green : .orange)
                            }
                            Text(hasNRC ? "NRC 已连接" : "未检测到 NRC 数据")
                                .font(.headline)
                        }
                        
                        if !hasNRC && !isChecking {
                            Text("请按照以下步骤设置 NRC 同步")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Steps
                    if !hasNRC {
                        VStack(alignment: .leading, spacing: 16) {
                            StepView(
                                number: 1,
                                title: "打开 Nike Run Club App",
                                description: "在 iPhone 上打开 Nike Run Club 应用"
                            )
                            
                            StepView(
                                number: 2,
                                title: "进入设置",
                                description: "点击右下角"我" → 设置"
                            )
                            
                            StepView(
                                number: 3,
                                title: "连接 Apple 健康",
                                description: "找到"健康"或"Health"选项，开启同步"
                            )
                            
                            StepView(
                                number: 4,
                                title: "授权数据共享",
                                description: "确保勾选：训练、心率、距离、活动能量"
                            )
                            
                            StepView(
                                number: 5,
                                title: "返回此应用",
                                description: "点击下方"检查连接"按钮验证设置"
                            )
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("NRC 设置指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("检查连接") {
                        checkNRCConnection()
                    }
                    .disabled(isChecking)
                }
            }
            .onAppear {
                checkNRCConnection()
            }
        }
    }
    
    private func checkNRCConnection() {
        isChecking = true
        Task {
            hasNRC = await importManager.checkNRCConnection()
            isChecking = false
        }
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NRCSetupGuideView()
}

