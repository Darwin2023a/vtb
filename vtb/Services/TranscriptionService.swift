import Foundation

enum TranscriptionError: LocalizedError {
    case invalidFile
    case networkError
    case apiError(String)
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "无效的音频文件"
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

struct TranscriptionResponse: Codable {
    let text: String
}

class TranscriptionService {
    private let apiKey: String
    private let baseURL = "https://api.siliconflow.cn/v1/audio/transcriptions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("文件不存在: \(fileURL.path)")
            throw TranscriptionError.invalidFile
        }
        
        // 创建 multipart/form-data 请求
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 创建 multipart/form-data 边界
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var bodyData = Data()
        
        // 添加文件数据
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            print("文件大小: \(fileData.count) 字节")
            bodyData.append(fileData)
            bodyData.append("\r\n".data(using: .utf8)!)
        } catch {
            print("读取文件失败: \(error)")
            throw TranscriptionError.invalidFile
        }
        
        // 添加模型参数
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("FunAudioLLM/SenseVoiceSmall\r\n".data(using: .utf8)!)
        
        // 结束边界
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("无效的响应类型")
                throw TranscriptionError.invalidResponse
            }
            
            print("API响应状态码: \(httpResponse.statusCode)")
            
            // 打印响应头
            print("响应头:")
            for (key, value) in httpResponse.allHeaderFields {
                print("\(key): \(value)")
            }
            
            // 打印响应体
            if let responseString = String(data: data, encoding: .utf8) {
                print("响应体: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("错误响应: \(errorJson)")
                    if let errorMessage = errorJson["error"] as? [String: Any],
                       let message = errorMessage["message"] as? String {
                        print("API错误: \(message)")
                        throw TranscriptionError.apiError(message)
                    }
                }
                print("未知API错误")
                throw TranscriptionError.apiError("未知错误")
            }
            
            do {
                let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                return result.text
            } catch {
                print("解析响应数据失败: \(error)")
                throw TranscriptionError.decodingError
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            print("网络请求失败: \(error)")
            throw TranscriptionError.networkError
        }
    }
} 