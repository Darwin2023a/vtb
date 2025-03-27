import Foundation
import SwiftUI

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let audioService: AudioService
    private let coreDataManager = CoreDataManager.shared
    
    init(audioService: AudioService) {
        self.audioService = audioService
        loadRecordings()
    }
    
    func loadRecordings() {
        recordings = coreDataManager.fetchRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        audioService.deleteRecording(recording)
        loadRecordings()
    }
    
    func playRecording(_ recording: Recording) {
        audioService.playRecording(url: recording.audioURL)
    }
    
    func stopPlayback() {
        audioService.stopPlayback()
    }
} 