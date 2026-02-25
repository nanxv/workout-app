//
//  OpenAICommandClient.swift
//  Silent Gym
//
//  Phase 5 rewrite — SSE streaming via AsyncThrowingStream.
//
//  Architecture:
//  ┌── streamChat(…) → AsyncThrowingStream<String, Error> ──────────────┐
//  │   URLSession.bytes → async line iterator → SSE parser → yield chunk │
//  │   Each chunk is a partial text delta (already decoded from JSON)    │
//  └────────────────────────────────────────────────────────────────────┘
//  ┌── processCommand(…) → AppAction? ────────────────────────────────── ┐
//  │   Non-streaming, uses function calling to extract structured action  │
//  │   Falls back to local CoachCommandRouter if AI is not configured     │
//  └────────────────────────────────────────────────────────────────────┘
//
//  API Key storage:
//  UserDefaults (development).  Production apps should use the Keychain.
//  Call `OpenAICommandClient.configure(apiKey:baseURL:model:)` at startup.
//

import Foundation

#if os(iOS)

// MARK: - Configuration

extension OpenAICommandClient {
    struct Config {
        /// Direct OpenAI endpoint or your backend proxy.
        var baseURL: String = "https://api.openai.com/v1"
        var model: String   = "gpt-4o-mini"
        var apiKey: String  = ""

        static let defaultsKey = "silentGym.openai.config.v1"

        static func load() -> Config {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let c = try? JSONDecoder().decode(Config.self, from: data)
            else { return Config() }
            return c
        }

        func save() {
            if let data = try? JSONEncoder().encode(self) {
                UserDefaults.standard.set(data, forKey: Config.defaultsKey)
            }
        }
    }
}

extension OpenAICommandClient.Config: Codable {}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case notConfigured
    case httpError(Int, String)
    case parseError(String)
    case streamTerminated

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中配置 OpenAI API Key。"
        case .httpError(let code, let msg):
            return "API 错误 \(code): \(msg)"
        case .parseError(let msg):
            return "解析错误: \(msg)"
        case .streamTerminated:
            return "流式传输意外终止。"
        }
    }
}

// MARK: - Message types

struct OpenAIMessage: Codable {
    let role: String    // "system" | "user" | "assistant"
    let content: String
}

// MARK: - OpenAICommandClient

/// Thread-safe.  All heavy work runs in `Task` / background;
/// callers consume the returned `AsyncThrowingStream` or `async` function.
final class OpenAICommandClient {

    static let shared = OpenAICommandClient()

    private(set) var config: Config

    private init() {
        config = Config.load()
    }

    // MARK: - Public configuration

    func configure(apiKey: String, baseURL: String? = nil, model: String? = nil) {
        config.apiKey = apiKey
        if let u = baseURL { config.baseURL = u }
        if let m = model   { config.model   = m }
        config.save()
    }

    var isConfigured: Bool { !config.apiKey.isEmpty }

    // MARK: - Streaming chat (Phase 5 main feature)

    /// Returns an `AsyncThrowingStream` that yields text deltas as they arrive.
    /// Each yielded `String` is a partial piece of the assistant reply.
    /// The stream finishes naturally when the model is done.
    ///
    /// Usage:
    /// ```swift
    /// for try await chunk in client.streamChat(...) {
    ///     reply += chunk   // update UI incrementally
    /// }
    /// ```
    func streamChat(
        userMessage: String,
        history: [OpenAIMessage] = [],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard isConfigured else {
                continuation.finish(throwing: OpenAIError.notConfigured)
                return
            }

            let cfg = self.config
            let messages = Self.buildMessages(
                system: systemPrompt,
                history: history,
                user: userMessage
            )

            let task = Task {
                do {
                    let request = try Self.buildRequest(
                        endpoint: "\(cfg.baseURL)/chat/completions",
                        apiKey: cfg.apiKey,
                        model: cfg.model,
                        messages: messages,
                        stream: true
                    )

                    let (asyncBytes, urlResponse) = try await URLSession.shared.bytes(for: request)

                    if let http = urlResponse as? HTTPURLResponse,
                       !(200...299).contains(http.statusCode) {
                        let bodyData = Data()
                        let bodyStr = String(data: bodyData, encoding: .utf8) ?? ""
                        continuation.finish(
                            throwing: OpenAIError.httpError(http.statusCode, bodyStr)
                        )
                        return
                    }

                    // SSE line-based parsing
                    var lineBuffer = ""
                    for try await byte in asyncBytes {
                        guard !Task.isCancelled else { break }
                        let scalar = Unicode.Scalar(byte)
                        let char   = Character(scalar)

                        if char == "\n" {
                            let line = lineBuffer
                            lineBuffer = ""
                            if let delta = Self.parseSSELine(line) {
                                continuation.yield(delta)
                            }
                        } else if char != "\r" {
                            lineBuffer.append(char)
                        }
                    }

                    // Process any remaining buffered line
                    if !lineBuffer.isEmpty, let delta = Self.parseSSELine(lineBuffer) {
                        continuation.yield(delta)
                    }

                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Non-streaming command extraction (function calling)

    /// Returns a structured `AppAction` by having the model choose a function.
    /// Falls back to the local `CoachCommandRouter` if AI is not configured.
    func processCommand(_ userMessage: String, context: AppContext? = nil) async -> AppAction? {
        guard isConfigured else {
            return CoachCommandRouter.parse(userMessage)
        }

        let systemPrompt = """
        你是一个健身 App 的 AI 助手，负责将用户的自然语言转换为结构化指令。
        当前状态：\(context?.currentState ?? "待机")
        当前训练：\(context?.currentRoutine ?? "无")
        可用计划：\(context?.availableRoutines.joined(separator: ", ") ?? "无")
        只能调用提供的 function，不要生成文本回复。
        """

        let messages = Self.buildMessages(
            system: systemPrompt,
            history: [],
            user: userMessage
        )

        guard let request = try? Self.buildRequest(
            endpoint: "\(config.baseURL)/chat/completions",
            apiKey: config.apiKey,
            model: config.model,
            messages: messages,
            stream: false,
            tools: Self.toolDefinitions
        ) else { return CoachCommandRouter.parse(userMessage) }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return Self.extractAction(from: data) ?? CoachCommandRouter.parse(userMessage)
        } catch {
            return CoachCommandRouter.parse(userMessage)
        }
    }

    // MARK: - Private helpers

    private static func buildMessages(
        system: String,
        history: [OpenAIMessage],
        user: String
    ) -> [OpenAIMessage] {
        var msgs: [OpenAIMessage] = [OpenAIMessage(role: "system", content: system)]
        msgs.append(contentsOf: history)
        msgs.append(OpenAIMessage(role: "user", content: user))
        return msgs
    }

    private static func buildRequest(
        endpoint: String,
        apiKey: String,
        model: String,
        messages: [OpenAIMessage],
        stream: Bool,
        tools: [[String: Any]]? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.parseError("Invalid URL: \(endpoint)")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": stream,
            "max_tokens": 1024,
            "temperature": 0.7
        ]
        if let tools { body["tools"] = tools }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: SSE line parser

    /// Parse a single `data: {...}` SSE line, returning the text delta or nil.
    private static func parseSSELine(_ line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let json = String(line.dropFirst(6))
        guard json != "[DONE]" else { return nil }

        guard let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first   = choices.first,
              let delta   = first["delta"] as? [String: Any],
              let content = delta["content"] as? String
        else { return nil }

        return content
    }

    // MARK: Function call extractor

    private static func extractAction(from data: Data) -> AppAction? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]],
              let first = toolCalls.first,
              let function = first["function"] as? [String: Any],
              let name = function["name"] as? String,
              let argsStr = function["arguments"] as? String,
              let argsData = argsStr.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
        else { return nil }
        return AppAction.fromOpenAIFunctionCall(name, arguments: args)
    }

    // MARK: - Tool definitions (function calling)

    static var toolDefinitions: [[String: Any]] {
        [
            makeTool("start_routine", "开始一个训练计划", [
                "routine_name": ("string", "训练计划名称，如 Day A")
            ], required: ["routine_name"]),
            makeTool("end_session", "结束当前训练会话", [:]),
            makeTool("skip_rest", "跳过当前休息", [:]),
            makeTool("extend_rest", "延长当前休息时间", [
                "seconds": ("integer", "延长的秒数")
            ], required: ["seconds"]),
            makeTool("add_to_calendar", "将训练添加到日历", [:]),
            makeTool("summarize_training", "总结训练数据", [
                "period": ("string", "时间周期，如最近一周")
            ], required: ["period"])
        ]
    }

    private static func makeTool(
        _ name: String,
        _ description: String,
        _ params: [String: (String, String)],
        required: [String] = []
    ) -> [String: Any] {
        var properties: [String: Any] = [:]
        for (key, (type, desc)) in params {
            properties[key] = ["type": type, "description": desc]
        }
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ]
            ]
        ]
    }

    // Legacy alias
    static var functionDefinitions: [[String: Any]] { toolDefinitions }
}

// MARK: - AppContext + AppAction helpers (unchanged)

struct AppContext {
    let currentState: String
    let currentRoutine: String?
    let currentExercise: String?
    let availableRoutines: [String]
}

extension AppAction {
    static func fromOpenAIFunctionCall(_ name: String, arguments: [String: Any]) -> AppAction? {
        switch name {
        case "start_routine":
            if let n = arguments["routine_name"] as? String { return .startRoutine(nameOrId: n) }
        case "end_session":      return .endSession
        case "skip_rest":        return .skipRest
        case "extend_rest":
            if let s = arguments["seconds"] as? Int { return .extendRest(seconds: s) }
        case "add_to_calendar":  return .addToCalendar(sessionId: nil)
        case "summarize_training":
            if let p = arguments["period"] as? String { return .summarize(period: p) }
        default: break
        }
        return nil
    }
}
#endif
