import SwiftUI

struct HistoryView: View {
    @ObservedObject var audioService: AudioService
    @Environment(\.dismiss) private var dismiss
    @State private var recordings: [Recording] = []
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: Recording?
    @State private var showingErrorAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recordings) { recording in
                    RecordingRow(recording: recording, audioService: audioService)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        recordingToDelete = recordings[index]
                        showingDeleteAlert = true
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("录音历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("删除录音", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {
                    recordingToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let recording = recordingToDelete {
                        audioService.deleteRecording(recording)
                        recordings.removeAll { $0.id == recording.id }
                    }
                }
            } message: {
                Text("确定要删除这条录音吗？此操作无法撤销。")
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                recordings = audioService.getRecordings()
            }
            .refreshable {
                recordings = audioService.getRecordings()
            }
        }
    }
    
    func playRecording(_ recording: Recording) {
        audioService.playRecording(url: recording.audioURL)
    }
    
    func stopPlayback() {
        audioService.stopPlayback()
    }
}

#Preview {
    HistoryView(audioService: AudioService())
} 