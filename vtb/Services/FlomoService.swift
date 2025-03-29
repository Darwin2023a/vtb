import Foundation

class FlomoService {
    private let apiKey: String
    private let baseURL: String
    private let maxRetries = 3
    private let timeoutInterval: TimeInterval = 30
    private let retryDelay: TimeInterval = 1  // 添加重试延迟时间
    
    init(apiKey: String = UserDefaults.standard.string(forKey: "flomo_api_key") ?? "",
         baseURL: String = UserDefaults.standard.string(forKey: "flomo_api_url") ?? "https://flomoapp.com/iwh/MjI1MzMxNA/b837df1dfa9334ff7869a5f8745021db/") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func sendToFlomo(transcription: String, enhancedText: String, tags: [String]) async throws {
        // 构建内容
        var content = ""
        
        // 添加原始转写文本
        content += "原始转写：\n\(transcription)\n\n"
        
        // 添加润色后的文本
        content += "润色后：\n\(enhancedText)\n\n"
        
        // 添加标签
        if !tags.isEmpty {
            content += "标签：\n\(tags.joined(separator: " "))\n"
        }
        
        try await sendContent(content)
    }
    
    func sendOriginalText(_ text: String) async throws {
        let content = "原始转写：\n\(text)"
        try await sendContent(content)
    }
    
    func sendEnhancedText(_ text: String, tags: [String]) async throws {
        var content = "润色后：\n\(text)"
        if !tags.isEmpty {
            content += "\n\n标签：\n\(tags.joined(separator: " "))"
        }
        try await sendContent(content)
    }
    
    private func sendContent(_ content: String) async throws {
        // 构建请求
        guard let url = URL(string: baseURL) else {
            throw FlomoError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        
        // 构建请求体
        let body = ["content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 打印请求信息用于调试
        print("发送到 flomo 的请求：")
        print("URL: \(url)")
        print("Content: \(content)")
        
        // 重试机制
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 打印响应信息用于调试
                if let httpResponse = response as? HTTPURLResponse {
                    print("响应状态码：\(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("响应内容：\(responseString)")
                    }
                }
                
                // 检查响应
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw FlomoError.requestFailed
                }
                
                // 解析响应 JSON
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["code"] as? Int,
                   let message = json["message"] as? String {
                    
                    // 检查是否是 PRO 用户限制错误
                    if code == -1 && message.contains("PRO") {
                        throw FlomoError.proUserRequired
                    }
                    
                    // 其他错误情况
                    if code != 0 {
                        throw FlomoError.apiError(message: message)
                    }
                }
                
                // 检查 HTTP 状态码
                if httpResponse.statusCode != 200 {
                    throw FlomoError.requestFailed
                }
                
                // 请求成功，退出重试循环
                return
                
            } catch {
                lastError = error
                if attempt < maxRetries {
                    // 等待一段时间后重试
                    let delay = retryDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            }
        }
        
        // 所有重试都失败，抛出最后一个错误
        if let error = lastError {
            throw error
        }
        throw FlomoError.requestFailed
    }
}

enum FlomoError: Error {
    case requestFailed
    case invalidURL
    case proUserRequired
    case apiError(message: String)
    
    var localizedDescription: String {
        switch self {
        case .requestFailed:
            return "发送请求失败，请检查网络连接"
        case .invalidURL:
            return "无效的 API 地址"
        case .proUserRequired:
            return "此功能需要 Flomo PRO 会员"
        case .apiError(let message):
            return "API 错误：\(message)"
        }
    }
} 