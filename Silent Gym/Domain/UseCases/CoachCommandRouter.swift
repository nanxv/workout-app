//
//  CoachCommandRouter.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation

enum AppAction {
    case startRoutine(nameOrId: String)
    case endSession
    case updateExerciseConfig(exerciseName: String, sets: Int?, restSeconds: Int?)
    case extendRest(seconds: Int)
    case skipRest
    case addToCalendar(sessionId: UUID?)
    case summarize(period: String)
}

class CoachCommandRouter {
    static func parse(_ input: String) -> AppAction? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 开始训练
        if lowercased.contains("开始") || lowercased.contains("start") {
            if lowercased.contains("day a") || lowercased.contains("a") {
                return .startRoutine(nameOrId: "Day A")
            } else if lowercased.contains("day b") || lowercased.contains("b") {
                return .startRoutine(nameOrId: "Day B")
            } else if lowercased.contains("day c") || lowercased.contains("c") {
                return .startRoutine(nameOrId: "Day C")
            } else {
                // Try to extract routine name
                let pattern = #"(?:开始|start)\s*(.+)"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
                   let nameRange = Range(match.range(at: 1), in: lowercased) {
                    let name = String(lowercased[nameRange]).trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        return .startRoutine(nameOrId: name)
                    }
                }
            }
        }
        
        // 结束训练
        if lowercased.contains("结束") || lowercased.contains("end") || lowercased.contains("完成") {
            return .endSession
        }
        
        // 修改动作配置
        if lowercased.contains("改") || lowercased.contains("改成") || lowercased.contains("修改") {
            // 提取动作名、组数、休息时间
            let setsPattern = #"(\d+)\s*组"#
            let restPattern = #"(\d+)\s*秒"#
            let exercisePattern = #"(俯卧撑|深蹲|引体向上|平板支撑|卷腹|burpee|pushup|squat|pullup|plank)"#
            
            var exerciseName: String?
            var sets: Int?
            var restSeconds: Int?
            
            if let regex = try? NSRegularExpression(pattern: exercisePattern),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let nameRange = Range(match.range(at: 1), in: lowercased) {
                exerciseName = String(lowercased[nameRange])
            }
            
            if let regex = try? NSRegularExpression(pattern: setsPattern),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let setsRange = Range(match.range(at: 1), in: lowercased),
               let setsValue = Int(String(lowercased[setsRange])) {
                sets = setsValue
            }
            
            if let regex = try? NSRegularExpression(pattern: restPattern),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let restRange = Range(match.range(at: 1), in: lowercased),
               let restValue = Int(String(lowercased[restRange])) {
                restSeconds = restValue
            }
            
            if let exerciseName = exerciseName {
                return .updateExerciseConfig(exerciseName: exerciseName, sets: sets, restSeconds: restSeconds)
            }
        }
        
        // 延长休息
        if lowercased.contains("休息") && (lowercased.contains("+") || lowercased.contains("加") || lowercased.contains("延长")) {
            let pattern = #"(\+|\+|加|延长)\s*(\d+)\s*(秒|s|second)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let secondsRange = Range(match.range(at: 2), in: lowercased),
               let seconds = Int(String(lowercased[secondsRange])) {
                return .extendRest(seconds: seconds)
            }
        }
        
        // 跳过休息
        if lowercased.contains("跳过") || lowercased.contains("skip") {
            return .skipRest
        }
        
        // 添加到日历
        if lowercased.contains("日历") || lowercased.contains("calendar") || lowercased.contains("加到") {
            return .addToCalendar(sessionId: nil)
        }
        
        // 总结
        if lowercased.contains("总结") || lowercased.contains("总结") || lowercased.contains("summary") {
            var period = "最近两周"
            if lowercased.contains("周") {
                period = "最近一周"
            } else if lowercased.contains("月") {
                period = "最近一月"
            }
            return .summarize(period: period)
        }
        
        return nil
    }
}

