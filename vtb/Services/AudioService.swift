import Foundation
import AVFoundation
import Speech
import SwiftUI

enum AudioError: LocalizedError {
    case recordingError
    case playbackError
    case transcriptionError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .recordingError:
            return "录音失败"
        case .playbackError:
            return "播放失败"
        case .transcriptionError:
            return "转写失败"
        case .permissionDenied:
            return "需要麦克风权限"
        }
    }
}

class AudioService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isTranscribing = false
    @Published var isEnhancing = false
    @Published var transcription = ""
    @Published var enhancedText = ""
    @Published var tags: [String] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var formattedDuration = "00:00"
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var errorMessage: String?
    @Published var currentPlayingURL: URL?
    @Published var recordings: [Recording] = []
    @Published var enhancementError: String?
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let transcriptionService: TranscriptionService
    private let textEnhancementService: TextEnhancementService
    private var timer: Timer?
    private var audioSessionConfigured = false
    
    init(apiKey: String = UserDefaults.standard.string(forKey: "siliconflow_api_key") ?? "") {
        self.transcriptionService = TranscriptionService(apiKey: apiKey)
        self.textEnhancementService = TextEnhancementService(apiKey: apiKey)
        super.init()
        setupAudioSession()
        
        // 确保在主线程上加载录音
        Task { @MainActor in
            self.recordings = getRecordings()
        }
        
        // 先检查麦克风权限
        Task {
            await checkMicrophonePermission()
        }
    }
    
    // MARK: - 权限检查
    func checkMicrophonePermission() async {
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            await MainActor.run {
                switch status {
                case .granted:
                    permissionStatus = .granted
                case .denied:
                    permissionStatus = .denied
                case .undetermined:
                    permissionStatus = .unknown
                @unknown default:
                    permissionStatus = .unknown
                }
            }
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            await MainActor.run {
                switch status {
                case .granted:
                    permissionStatus = .granted
                case .denied:
                    permissionStatus = .denied
                case .undetermined:
                    permissionStatus = .unknown
                @unknown default:
                    permissionStatus = .unknown
                }
            }
        }
    }
    
    func requestMicrophoneAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                permissionStatus = granted ? .granted : .denied
            }
            return granted
        } else {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            await MainActor.run {
                permissionStatus = granted ? .granted : .denied
            }
            return granted
        }
    }
    
    // MARK: - 录音功能
    func startRecording() async throws {
        guard permissionStatus == .granted else {
            throw AudioError.permissionDenied
        }
        
        setupAudioSession()
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000,  // 增加比特率
            AVEncoderBitDepthHintKey: 16,  // 设置位深度
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true  // 启用音量计量
            audioRecorder?.record()
            await MainActor.run {
                isRecording = true
                startTimer()
            }
        } catch {
            print("录音启动失败: \(error)")
            throw AudioError.recordingError
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        Task { @MainActor in
            isRecording = false
            
            // 保存录音信息
            if let url = audioRecorder?.url {
                let recording = Recording(
                    id: UUID(),
                    audioURL: url,
                    transcription: transcription,
                    enhancedText: enhancedText,
                    tags: tags,
                    createdAt: Date()
                )
                saveRecording(recording)
                
                // 清空当前状态
                transcription = ""
                enhancedText = ""
                tags = []
                
                // 开始转写
                await transcribeAudio(url: url)
            }
        }
    }
    
    private func saveRecording(_ recording: Recording) {
        var recordings = getRecordings()
        recordings.insert(recording, at: 0)
        if let encoded = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(encoded, forKey: "recordings")
            UserDefaults.standard.synchronize()
            
            // 立即更新 recordings 数组
            Task { @MainActor in
                self.recordings = recordings
            }
        }
    }
    
    // MARK: - 播放功能
    func playRecording(url: URL) {
        do {
            // 如果已经在播放其他录音，先停止
            if isPlaying {
                stopPlayback()
            }
            
            // 设置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 创建新的播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // 设置播放器音量
            audioPlayer?.volume = 1.0
            
            // 开始播放
            audioPlayer?.play()
            Task { @MainActor in
                isPlaying = true
                isPaused = false
                currentPlayingURL = url
            }
        } catch {
            print("播放失败: \(error.localizedDescription)")
            Task { @MainActor in
                errorMessage = error.localizedDescription
                stopPlayback()
            }
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        Task { @MainActor in
            isPaused = true
        }
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        Task { @MainActor in
            isPaused = false
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        Task { @MainActor in
            isPlaying = false
            isPaused = false
            currentPlayingURL = nil
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("停止播放失败: \(error.localizedDescription)")
        }
    }
    
    func togglePlayback(url: URL) {
        if isPlaying {
            if isPaused {
                resumePlayback()
            } else {
                pausePlayback()
            }
        } else {
            playRecording(url: url)
        }
    }
    
    // MARK: - 转写功能
    func transcribeAudio(url: URL) async {
        await MainActor.run {
            isTranscribing = true
            errorMessage = nil
        }
        
        do {
            let text = try await transcriptionService.transcribeAudio(fileURL: url)
            await MainActor.run {
                self.transcription = text
                self.isTranscribing = false
            }
            
            // 转写完成后自动进行文字润色
            do {
                _ = try await enhanceText()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isTranscribing = false
            }
        }
    }
    
    func enhanceText(model: TextEnhancementService.Model = .qwen) async throws -> String {
        guard !transcription.isEmpty else { return "" }
        
        await MainActor.run {
            isEnhancing = true
            errorMessage = nil
        }
        
        do {
            let result = try await textEnhancementService.enhanceText(transcription, model: model)
            
            // 解析返回的结果
            let components = result.components(separatedBy: "\n\n")
            let enhancedTextResult = components.first { $0.starts(with: "优化后的文本：") }?
                .replacingOccurrences(of: "优化后的文本：", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? result
            
            let tagsResult = components.first { $0.starts(with: "相关标签：") }?
                .replacingOccurrences(of: "相关标签：", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ")
                .filter { $0.hasPrefix("#") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
            
            await MainActor.run {
                self.enhancedText = enhancedTextResult
                self.tags = tagsResult
                isEnhancing = false
                
                // 更新最新的录音记录
                var recordings = getRecordings()
                if var firstRecording = recordings.first {
                    firstRecording.transcription = self.transcription
                    firstRecording.enhancedText = self.enhancedText
                    firstRecording.tags = self.tags
                    recordings[0] = firstRecording
                    if let encoded = try? JSONEncoder().encode(recordings) {
                        UserDefaults.standard.set(encoded, forKey: "recordings")
                        UserDefaults.standard.synchronize()
                        
                        // 立即更新 recordings 数组
                        Task { @MainActor in
                            self.recordings = recordings
                        }
                    }
                }
            }
            
            return enhancedTextResult
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                isEnhancing = false
            }
            throw error
        }
    }
    
    // MARK: - 辅助功能
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            audioSessionConfigured = true
        } catch {
            errorMessage = "音频会话设置失败：\(error.localizedDescription)"
        }
    }
    
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
            self?.updateFormattedDuration()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateFormattedDuration() {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        formattedDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - 录音管理
    func getRecordings() -> [Recording] {
        if let data = UserDefaults.standard.data(forKey: "recordings"),
           let recordings = try? JSONDecoder().decode([Recording].self, from: data) {
            return recordings
        }
        return []
    }
    
    func updateRecording(_ recording: Recording) {
        var recordings = getRecordings()
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            if let encoded = try? JSONEncoder().encode(recordings) {
                UserDefaults.standard.set(encoded, forKey: "recordings")
                UserDefaults.standard.synchronize()
                
                // 立即更新 recordings 数组
                Task { @MainActor in
                    self.recordings = recordings
                }
            }
        }
    }
    
    func updateRecordingName(_ recording: Recording, newName: String) {
        var updatedRecording = recording
        updatedRecording.name = newName
        updateRecording(updatedRecording)
    }
    
    func deleteRecording(_ recording: Recording) {
        do {
            // 删除音频文件
            if FileManager.default.fileExists(atPath: recording.audioURL.path) {
                try FileManager.default.removeItem(at: recording.audioURL)
            }
            
            // 从 UserDefaults 中删除记录
            var recordings = getRecordings()
            recordings.removeAll { $0.id == recording.id }
            if let encoded = try? JSONEncoder().encode(recordings) {
                UserDefaults.standard.set(encoded, forKey: "recordings")
                UserDefaults.standard.synchronize()
                
                // 立即更新 recordings 数组
                Task { @MainActor in
                    self.recordings = recordings
                }
            }
        } catch {
            print("删除录音文件失败: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadRecordings() {
        recordings = getRecordings()
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "录音失败"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
            self.currentPlayingURL = nil
        }
    }
} 