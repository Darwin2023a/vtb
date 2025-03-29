import SwiftUI
import AVFoundation

struct RecordingRow: View {
    @Binding var recording: Recording
    @ObservedObject var audioService: AudioService
    @State private var isExpanded = false
    @State private var isSending = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var isEditingName = false
    @State private var editedName: String = ""
    @State private var isPlaying = false
    @State private var isPaused = false
    
    private var isPlayingThisRecording: Bool {
        audioService.isPlaying && audioService.currentPlayingURL == recording.audioURL
    }
    
    private var flomoService: FlomoService {
        FlomoService()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 基本信息行
            HStack {
                // 时间显示
                Text(recording.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // 文件名
                if isEditingName {
                    HStack {
                        TextField("输入文件名", text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                            .onAppear {
                                // 如果是默认的时间格式名称，则清空
                                if recording.name.hasPrefix("录音 ") {
                                    editedName = ""
                                } else {
                                    editedName = recording.name
                                }
                            }
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        // 确认按钮
                        Button(action: {
                            updateRecordingName()
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                        
                        // 取消按钮
                        Button(action: {
                            isEditingName = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    Text(recording.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // 编辑按钮
                    Button(action: {
                        isEditingName = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
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
                .buttonStyle(PlainButtonStyle())
            }
            
            // 展开后的详细信息
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // 播放控制按钮
                    HStack(spacing: 12) {
                        // 播放/暂停按钮
                        Button(action: {
                            audioService.togglePlayback(url: recording.audioURL)
                        }) {
                            HStack {
                                Image(systemName: isPlayingThisRecording ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(isPlayingThisRecording ? "暂停" : "播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 停止按钮
                        Button(action: {
                            audioService.stopPlayback()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                    .font(.title)
                                Text("停止")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
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
                            .buttonStyle(PlainButtonStyle())
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
                            .buttonStyle(PlainButtonStyle())
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
                    .buttonStyle(PlainButtonStyle())
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
    
    private func updateRecordingName() {
        if !editedName.isEmpty && editedName != recording.name {
            audioService.updateRecordingName(recording, newName: editedName)
            recording.name = editedName
        }
        isEditingName = false
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