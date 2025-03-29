import SwiftUI
import AVFoundation

struct RecordingRow: View {
    let recording: Recording
    let audioService: AudioService
    @State private var isExpanded = false
    @State private var isSending = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    private var flomoService: FlomoService {
        FlomoService()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 基本信息行
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    Text(recording.audioURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 播放按钮
                Button(action: {
                    audioService.playRecording(url: recording.audioURL)
                }) {
                    Image(systemName: audioService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.blue)
                }
            }
            
            // 展开/收起按钮
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(isExpanded ? "收起详情" : "查看详情")
                        .foregroundColor(.blue)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            // 展开后的详细信息
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if !recording.transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("转写文本：")
                                .font(.headline)
                            Text(recording.transcription)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button(action: {
                                Task {
                                    await sendOriginalText()
                                }
                            }) {
                                HStack {
                                    if isSending {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(isSending ? "发送中..." : "发送原始文本到 flomo")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isSending)
                        }
                    }
                    
                    if !recording.enhancedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("润色后的文本：")
                                .font(.headline)
                            Text(recording.enhancedText)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button(action: {
                                Task {
                                    await sendEnhancedText()
                                }
                            }) {
                                HStack {
                                    if isSending {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(isSending ? "发送中..." : "发送润色文本到 flomo")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isSending)
                        }
                    }
                    
                    if !recording.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("相关标签：")
                                .font(.headline)
                            FlowLayout(spacing: 8) {
                                ForEach(recording.tags, id: \.self) { tag in
                                    Text(tag)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await sendToFlomo()
                        }
                    }) {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSending ? "发送中..." : "发送全部内容到 flomo")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isSending)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .alert("成功", isPresented: $showingSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("发送成功！")
        }
    }
    
    private func sendToFlomo() async {
        isSending = true
        do {
            try await flomoService.sendToFlomo(
                transcription: recording.transcription,
                enhancedText: recording.enhancedText,
                tags: recording.tags
            )
            await MainActor.run {
                isSending = false
                showingSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "发送失败：\(error.localizedDescription)"
                showingError = true
                isSending = false
            }
        }
    }
    
    private func sendOriginalText() async {
        isSending = true
        do {
            try await flomoService.sendOriginalText(recording.transcription)
            await MainActor.run {
                isSending = false
                showingSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "发送失败：\(error.localizedDescription)"
                showingError = true
                isSending = false
            }
        }
    }
    
    private func sendEnhancedText() async {
        isSending = true
        do {
            try await flomoService.sendEnhancedText(recording.enhancedText, tags: recording.tags)
            await MainActor.run {
                isSending = false
                showingSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "发送失败：\(error.localizedDescription)"
                showingError = true
                isSending = false
            }
        }
    }
} 