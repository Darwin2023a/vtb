import SwiftUI

struct HistoryView: View {
    @ObservedObject var audioService: AudioService
    @Environment(\.dismiss) private var dismiss
    @State private var recordings: [Recording] = []
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: Recording?
    @State private var showingErrorAlert = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    @State private var selectedRecordings: Set<UUID> = []
    
    private var isAllSelected: Bool {
        !recordings.isEmpty && selectedRecordings.count == recordings.count
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
                    .overlay(
                        isEditing ? selectionOverlay(for: recording) : nil
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("录音历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditing {
                            Button("全选") {
                                if isAllSelected {
                                    selectedRecordings.removeAll()
                                } else {
                                    selectedRecordings = Set(recordings.map { $0.id })
                                }
                            }
                            .foregroundColor(.blue)
                            
                            Button("删除") {
                                if !selectedRecordings.isEmpty {
                                    showingDeleteAlert = true
                                }
                            }
                            .foregroundColor(.red)
                        }
                        Button(isEditing ? "完成" : "编辑") {
                            withAnimation {
                                isEditing.toggle()
                                if !isEditing {
                                    selectedRecordings.removeAll()
                                }
                            }
                        }
                    }
                }
            }
            .alert("删除录音", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {
                    selectedRecordings.removeAll()
                }
                Button("删除", role: .destructive) {
                    deleteSelectedRecordings()
                }
            } message: {
                Text("确定要删除选中的 \(selectedRecordings.count) 条录音吗？此操作无法撤销。")
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                loadRecordings()
            }
            .refreshable {
                loadRecordings()
            }
        }
    }
    
    private func selectionOverlay(for recording: Recording) -> some View {
        HStack {
            Spacer()
            Button(action: {
                if selectedRecordings.contains(recording.id) {
                    selectedRecordings.remove(recording.id)
                } else {
                    selectedRecordings.insert(recording.id)
                }
            }) {
                Image(systemName: selectedRecordings.contains(recording.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedRecordings.contains(recording.id) ? .blue : .gray)
                    .font(.title2)
                    .padding(.trailing, 8)
            }
        }
        .contentShape(Rectangle())
    }
    
    private func loadRecordings() {
        recordings = audioService.getRecordings()
    }
    
    private func deleteSelectedRecordings() {
        for id in selectedRecordings {
            if let recording = recordings.first(where: { $0.id == id }) {
                audioService.deleteRecording(recording)
            }
        }
        selectedRecordings.removeAll()
        isEditing = false
        loadRecordings()
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