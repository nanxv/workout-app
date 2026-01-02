//
//  OpenAICommandClient.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation

#if os(iOS)
/// OpenAI Function Calling 客户端
/// 
/// ⚠️ 注意：此实现需要后端代理来保护 API Key
/// 当前版本为占位实现，展示如何集成 OpenAI function calling
class OpenAICommandClient {
    static let shared = OpenAICommandClient()
    
    // 后端代理 URL（需要替换为实际的后端地址）
    private let apiBaseURL = "https://your-backend.com/api"
    
    private init() {}
    
    /// 发送命令到 OpenAI 并获取结构化响应
    /// - Parameters:
    ///   - userMessage: 用户输入的自然语言命令
    ///   - context: 当前应用上下文（可选）
    /// - Returns: AppAction 或 nil
    func processCommand(_ userMessage: String, context: AppContext? = nil) async -> AppAction? {
        // TODO: 实现实际的 API 调用
        // 1. 构建请求体，包含 function definitions
        // 2. 发送到后端代理
        // 3. 解析响应中的 function_call
        // 4. 转换为 AppAction
        
        // 当前实现：降级到本地解析
        return CoachCommandRouter.parse(userMessage)
    }
    
    /// 定义可用的函数（用于 OpenAI function calling）
    static var functionDefinitions: [[String: Any]] {
        return [
            [
                "name": "start_routine",
                "description": "开始一个训练计划",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "routine_name": [
                            "type": "string",
                            "description": "训练计划名称，如 'Day A', 'Day B', 'Day C'"
                        ]
                    ],
                    "required": ["routine_name"]
                ]
            ],
            [
                "name": "end_session",
                "description": "结束当前训练会话",
                "parameters": [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ],
            [
                "name": "update_exercise_config",
                "description": "更新动作配置（组数或休息时间）",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "exercise_name": [
                            "type": "string",
                            "description": "动作名称"
                        ],
                        "sets": [
                            "type": "integer",
                            "description": "目标组数"
                        ],
                        "rest_seconds": [
                            "type": "integer",
                            "description": "休息时间（秒）"
                        ]
                    ],
                    "required": ["exercise_name"]
                ]
            ],
            [
                "name": "extend_rest",
                "description": "延长当前休息时间",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "seconds": [
                            "type": "integer",
                            "description": "延长的秒数"
                        ]
                    ],
                    "required": ["seconds"]
                ]
            ],
            [
                "name": "skip_rest",
                "description": "跳过当前休息",
                "parameters": [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ],
            [
                "name": "add_to_calendar",
                "description": "将训练添加到日历",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "session_id": [
                            "type": "string",
                            "description": "训练会话 ID（可选，默认当前会话）"
                        ]
                    ],
                    "required": []
                ]
            ],
            [
                "name": "summarize_training",
                "description": "总结训练数据",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "period": [
                            "type": "string",
                            "description": "时间周期，如 '最近一周', '最近两周', '最近一月'"
                        ]
                    ],
                    "required": ["period"]
                ]
            ]
        ]
    }
}

/// 应用上下文（用于传递给 AI 的上下文信息）
struct AppContext {
    let currentState: String
    let currentRoutine: String?
    let currentExercise: String?
    let availableRoutines: [String]
}

/// 将 OpenAI function call 转换为 AppAction
extension AppAction {
    static func fromOpenAIFunctionCall(_ functionName: String, arguments: [String: Any]) -> AppAction? {
        switch functionName {
        case "start_routine":
            if let routineName = arguments["routine_name"] as? String {
                return .startRoutine(nameOrId: routineName)
            }
        case "end_session":
            return .endSession
        case "update_exercise_config":
            if let exerciseName = arguments["exercise_name"] as? String {
                let sets = arguments["sets"] as? Int
                let restSeconds = arguments["rest_seconds"] as? Int
                return .updateExerciseConfig(exerciseName: exerciseName, sets: sets, restSeconds: restSeconds)
            }
        case "extend_rest":
            if let seconds = arguments["seconds"] as? Int {
                return .extendRest(seconds: seconds)
            }
        case "skip_rest":
            return .skipRest
        case "add_to_calendar":
            if let sessionIdString = arguments["session_id"] as? String,
               let sessionId = UUID(uuidString: sessionIdString) {
                return .addToCalendar(sessionId: sessionId)
            } else {
                return .addToCalendar(sessionId: nil)
            }
        case "summarize_training":
            if let period = arguments["period"] as? String {
                return .summarize(period: period)
            }
        default:
            return nil
        }
        return nil
    }
}
#endif

