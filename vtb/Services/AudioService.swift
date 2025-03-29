import Foundation
import AVFoundation
import Speech

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
    @Published var isTranscribing = false
    @Published var isEnhancing = false
    @Published var transcription = ""
    @Published var enhancedText = ""
    @Published var tags: [String] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var formattedDuration = "00:00"
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var errorMessage: String?
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioSessionConfigured = false
    private let transcriptionService: TranscriptionService
    private let textEnhancementService: TextEnhancementService
    
    init(apiKey: String = UserDefaults.standard.string(forKey: "siliconflow_api_key") ?? "") {
        self.transcriptionService = TranscriptionService(apiKey: apiKey)
        self.textEnhancementService = TextEnhancementService(apiKey: apiKey)
        super.init()
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
        
        try await setupAudioSession()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(Date().timeIntervalSince1970).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
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
            Task {
                await transcribeAudio(url: url)
            }
        }
    }
    
    private func saveRecording(_ recording: Recording) {
        var recordings = getRecordings()
        recordings.insert(recording, at: 0)
        UserDefaults.standard.set(recordings.map { $0.toDictionary() }, forKey: "recordings")
    }
    
    // MARK: - 播放功能
    func playRecording(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            isPlaying = true
        } catch {
            print("播放失败: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("停止播放失败: \(error)")
        }
    }
    
    // MARK: - 转写功能
    private func transcribeAudio(url: URL) async {
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
        
        isEnhancing = true
        errorMessage = nil
        
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
                    UserDefaults.standard.set(recordings.map { $0.toDictionary() }, forKey: "recordings")
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
    private func setupAudioSession() async throws {
        if !audioSessionConfigured {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            audioSessionConfigured = true
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
    
    // 获取所有录音文件
    func getRecordings() -> [Recording] {
        if let savedData = UserDefaults.standard.array(forKey: "recordings") as? [[String: Any]] {
            return savedData.compactMap { Recording.fromDictionary($0) }
        }
        return []
    }
    
    // 删除录音文件
    func deleteRecording(_ recording: Recording) {
        do {
            // 删除音频文件
            if FileManager.default.fileExists(atPath: recording.audioURL.path) {
                try FileManager.default.removeItem(at: recording.audioURL)
            }
            
            // 从 UserDefaults 中删除记录
            var recordings = getRecordings()
            recordings.removeAll { $0.id == recording.id }
            UserDefaults.standard.set(recordings.map { $0.toDictionary() }, forKey: "recordings")
            
            // 强制同步 UserDefaults
            UserDefaults.standard.synchronize()
        } catch {
            print("删除录音文件失败: \(error)")
            errorMessage = error.localizedDescription
        }
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
        isPlaying = false
    }
} 