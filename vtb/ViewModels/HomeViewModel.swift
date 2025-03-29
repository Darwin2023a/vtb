import Foundation
import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isTranscribing = false
    @Published var isEnhancing = false
    @Published var transcription = ""
    @Published var enhancedText = ""
    @Published var tags: [String] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var formattedDuration = "00:00"
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var successMessage: String?
    @Published var showingSuccess = false
    @Published var permissionStatus: AudioService.PermissionStatus = .unknown
    @Published var enhancementError: String?
    @Published var selectedModel: TextEnhancementService.Model = .qwen
    
    private let audioService: AudioService
    private let flomoService: FlomoService
    
    init(audioService: AudioService) {
        self.audioService = audioService
        let apiKey = UserDefaults.standard.string(forKey: "flomo_api_key") ?? ""
        let apiUrl = UserDefaults.standard.string(forKey: "flomo_api_url") ?? "https://flomoapp.com/iwh/MjI1MzMxNA/b837df1dfa9334ff7869a5f8745021db/"
        self.flomoService = FlomoService(apiKey: apiKey, baseURL: apiUrl)
        setupBindings()
    }
    
    private func setupBindings() {
        // 绑定录音状态
        audioService.$isRecording
            .assign(to: &$isRecording)
        
        // 绑定播放状态
        audioService.$isPlaying
            .assign(to: &$isPlaying)
        
        // 绑定转写状态
        audioService.$isTranscribing
            .assign(to: &$isTranscribing)
        
        // 绑定润色状态
        audioService.$isEnhancing
            .assign(to: &$isEnhancing)
        
        // 绑定转写结果
        audioService.$transcription
            .assign(to: &$transcription)
        
        // 绑定润色结果
        audioService.$enhancedText
            .assign(to: &$enhancedText)
        
        // 绑定标签
        audioService.$tags
            .assign(to: &$tags)
        
        // 绑定录音时长
        audioService.$recordingDuration
            .assign(to: &$recordingDuration)
        
        // 绑定格式化时长
        audioService.$formattedDuration
            .assign(to: &$formattedDuration)
        
        // 绑定错误信息
        audioService.$errorMessage
            .assign(to: &$errorMessage)
        
        // 绑定权限状态
        audioService.$permissionStatus
            .assign(to: &$permissionStatus)
    }
    
    func checkMicrophonePermission() async {
        await audioService.checkMicrophonePermission()
    }
    
    func requestMicrophoneAccess() async -> Bool {
        await audioService.requestMicrophoneAccess()
    }
    
    func startRecording() async throws {
        try await audioService.startRecording()
    }
    
    func stopRecording() {
        audioService.stopRecording()
    }
    
    func playRecording(url: URL) {
        audioService.playRecording(url: url)
    }
    
    func stopPlayback() {
        audioService.stopPlayback()
    }
    
    func getRecordings() -> [Recording] {
        audioService.getRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        audioService.deleteRecording(recording)
    }
    
    func retryEnhancement(with model: TextEnhancementService.Model? = nil) async {
        if let model = model {
            selectedModel = model
        }
        
        isEnhancing = true
        enhancementError = nil
        
        do {
            let result = try await audioService.enhanceText(model: selectedModel)
            enhancedText = result
            isEnhancing = false
        } catch {
            enhancementError = error.localizedDescription
            isEnhancing = false
        }
    }
    
    // MARK: - Flomo 相关方法
    func sendToFlomo() async throws {
        try await flomoService.sendToFlomo(
            transcription: transcription,
            enhancedText: enhancedText,
            tags: tags
        )
    }
    
    func sendOriginalTextToFlomo() async throws {
        try await flomoService.sendOriginalText(transcription)
    }
    
    func sendEnhancedTextToFlomo() async throws {
        try await flomoService.sendEnhancedText(enhancedText, tags: tags)
    }
    
    func updateFlomoCredentials(apiKey: String, apiUrl: String) {
        UserDefaults.standard.set(apiKey, forKey: "flomo_api_key")
        UserDefaults.standard.set(apiUrl, forKey: "flomo_api_url")
    }
} 