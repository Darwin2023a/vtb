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
    @Published var permissionStatus: AudioService.PermissionStatus = .unknown
    
    private let audioService: AudioService
    
    init(audioService: AudioService) {
        self.audioService = audioService
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
    
    func startRecording() {
        Task {
            do {
                try await audioService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
} 