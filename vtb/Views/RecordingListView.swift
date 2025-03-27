import SwiftUI

struct RecordingListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService: AudioService
    @StateObject private var viewModel: HistoryViewModel
    
    init() {
        let audioService = AudioService()
        _audioService = StateObject(wrappedValue: audioService)
        _viewModel = StateObject(wrappedValue: HistoryViewModel(audioService: audioService))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.recordings) { recording in
                    RecordingRow(recording: recording, audioService: audioService)
                }
            }
            .navigationTitle("录音列表")
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
        }
    }
}

#Preview {
    RecordingListView()
} 