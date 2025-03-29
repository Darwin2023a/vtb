import SwiftUI

struct RecordingListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService: AudioService
    @StateObject private var viewModel: HistoryViewModel
    @State private var recordings: [Recording] = []
    
    init() {
        let audioService = AudioService()
        _audioService = StateObject(wrappedValue: audioService)
        _viewModel = StateObject(wrappedValue: HistoryViewModel(audioService: audioService))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recordings) { recording in
                    RecordingRow(recording: Binding(
                        get: { recording },
                        set: { updatedRecording in
                            if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
                                recordings[index] = updatedRecording
                                audioService.updateRecording(updatedRecording)
                            }
                        }
                    ), audioService: audioService)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("录音列表")
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
            .onAppear {
                recordings = audioService.getRecordings()
            }
            .refreshable {
                recordings = audioService.getRecordings()
            }
        }
    }
}

#Preview {
    RecordingListView()
} 