import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
}

// API 响应模型
struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
    let top_p: Double
    let frequency_penalty: Double
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ChatResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

class APIService {
    static let shared = APIService(apiKey: UserDefaults.standard.string(forKey: "siliconflow_api_key") ?? "")
    private let apiKey: String
    private let baseURL = "https://api.siliconflow.cn/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // 语音转文字
    func transcribeAudio(audioData: Data) async throws -> String {
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var bodyData = Data()
        
        // 添加文件数据
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        bodyData.append(audioData)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // 添加模型参数
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("whisper-1\r\n".data(using: .utf8)!)
        
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = bodyData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? [String: Any],
               let message = errorMessage["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("Unknown error occurred")
        }
        
        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }
    
    // 文本优化
    func enhanceText(_ text: String) async throws -> (String, [String]) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        请对以下文本进行润色和优化，使其更加流畅自然，并纠正可能的错别字。同时，请提供三个相关的主题标签（以#开头）。

        原文：
        \(text)
        """
        
        let body = ChatRequest(
            model: "gpt-3.5-turbo",
            messages: [
                Message(role: "user", content: prompt)
            ],
            temperature: 0.7,
            max_tokens: 1024,
            top_p: 0.7,
            frequency_penalty: 0.5
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? [String: Any],
               let message = errorMessage["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("Unknown error occurred")
        }
        
        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = result.choices.first?.message.content ?? ""
        
        // 提取标签
        let tags = content.components(separatedBy: "\n")
            .filter { $0.hasPrefix("#") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // 移除标签部分，获取优化后的文本
        let enhancedText = content.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("#") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (enhancedText, tags)
    }
    
    func chatCompletion(messages: [Message]) async throws -> String {
        let request = ChatRequest(
            model: "Qwen/QwQ-32B",
            messages: messages,
            temperature: 0.7,
            max_tokens: 1024,
            top_p: 0.7,
            frequency_penalty: 0.5
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    throw APIError.serverError(message)
                }
                throw APIError.serverError("未知错误")
            }
            
            let result = try JSONDecoder().decode(ChatResponse.self, from: data)
            return result.choices.first?.message.content ?? ""
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
} 