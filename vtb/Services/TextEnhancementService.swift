import Foundation

enum TextEnhancementError: LocalizedError {
    case networkError
    case apiError(String)
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "网络连接错误"
        case .apiError(let message):
            return "API错误: \(message)"
        case .invalidResponse:
            return "无效的服务器响应"
        case .decodingError:
            return "解析响应数据失败"
        }
    }
}

class TextEnhancementService {
    private let apiKey: String
    private let baseURL = "https://api.siliconflow.cn/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func enhanceText(_ text: String) async throws -> String {
        let prompt = """
        请对以下文本进行润色和优化，使其更加流畅自然，同时保持原意不变。同时，请为这段文本生成三个相关的标签（hashtag）。
        
        原文：
        \(text)
        
        请按照以下格式输出：
        优化后的文本：
        [优化后的文本内容]
        
        相关标签：
        #标签1 #标签2 #标签3
        """
        
        let request = ChatRequest(
            model: "Qwen/QwQ-32B",
            messages: [
                Message(role: "user", content: prompt)
            ],
            temperature: 0.7,
            max_tokens: 1024,
            top_p: 0.7,
            frequency_penalty: 0.5
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("无效的响应类型")
                throw TextEnhancementError.invalidResponse
            }
            
            print("API响应状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("错误响应: \(errorJson)")
                    if let errorMessage = errorJson["error"] as? [String: Any],
                       let message = errorMessage["message"] as? String {
                        print("API错误: \(message)")
                        throw TextEnhancementError.apiError(message)
                    }
                }
                print("未知API错误")
                throw TextEnhancementError.apiError("未知错误")
            }
            
            do {
                let result = try JSONDecoder().decode(ChatResponse.self, from: data)
                return result.choices.first?.message.content ?? ""
            } catch {
                print("解析响应数据失败: \(error)")
                throw TextEnhancementError.decodingError
            }
        } catch let error as TextEnhancementError {
            throw error
        } catch {
            print("网络请求失败: \(error)")
            throw TextEnhancementError.networkError
        }
    }
} 