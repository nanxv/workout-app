//
//  PermissionGuideView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI

enum PermissionType: Identifiable {
    case healthKit
    case calendar
    case nrc
    
    var id: String {
        switch self {
        case .healthKit: return "healthKit"
        case .calendar: return "calendar"
        case .nrc: return "nrc"
        }
    }
    
    var title: String {
        switch self {
        case .healthKit:
            return "需要健康权限"
        case .calendar:
            return "需要日历权限"
        case .nrc:
            return "导入 Nike Run Club 跑步记录"
        }
    }
    
    var content: String {
        switch self {
        case .healthKit:
            return """
            为了记录您的训练数据并同步到 Apple 健康，我们需要访问健康数据。
            
            请按以下步骤开启权限：
            
            1. 打开 iPhone 设置
            2. 进入"隐私与安全性"
            3. 选择"健康"
            4. 找到"Silent Gym"
            5. 开启以下权限：
               • 允许读取数据（用于导入跑步记录）
               • 允许写入数据（用于保存训练记录）
            """
        case .calendar:
            return """
            为了将训练记录添加到您的日历，我们需要访问日历。
            
            请按以下步骤开启权限：
            
            1. 打开 iPhone 设置
            2. 进入"隐私与安全性"
            3. 选择"日历"
            4. 找到"Silent Gym"
            5. 开启"允许访问日历"
            """
        case .nrc:
            return """
            要查看您的 NRC 跑步记录，需要先在 Nike Run Club 中开启与 Apple 健康的同步。
            
            请按以下步骤设置：
            
            1. 打开 Nike Run Club App
            2. 进入"我" → "设置"
            3. 找到"健康"或"Health"选项
            4. 开启同步以下数据：
               • 训练
               • 心率
               • 距离
               • 活动能量
            
            设置完成后，返回此应用，点击"导入跑步记录"即可。
            """
        }
    }
    
    var settingsURL: URL? {
        switch self {
        case .healthKit:
            // iOS 16+ 可以打开健康设置
            if #available(iOS 16.0, *) {
                return URL(string: "x-apple-health://")
            }
            return URL(string: UIApplication.openSettingsURLString)
        case .calendar, .nrc:
            return URL(string: UIApplication.openSettingsURLString)
        }
    }
}

struct PermissionGuideView: View {
    let permissionType: PermissionType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(permissionType.content)
                        .font(.body)
                        .padding()
                    
                    Button(action: {
                        if let url = permissionType.settingsURL {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("前往设置")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(permissionType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PermissionGuideView(permissionType: .healthKit)
}

