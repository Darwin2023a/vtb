import SwiftUI

struct HomeView: View {
    @StateObject private var audioService: AudioService
    @StateObject private var viewModel: HomeViewModel
    @State private var showingRecordingList = false
    @State private var showingSettings = false
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    
    init() {
        let audioService = AudioService()
        _audioService = StateObject(wrappedValue: audioService)
        _viewModel = StateObject(wrappedValue: HomeViewModel(audioService: audioService))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 录音按钮
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        if viewModel.permissionStatus == .granted {
                            viewModel.startRecording()
                        } else if viewModel.permissionStatus == .denied {
                            showingPermissionAlert = true
                        } else {
                            // 对于未知状态，先请求权限
                            Task {
                                let granted = await viewModel.requestMicrophoneAccess()
                                if granted {
                                    viewModel.startRecording()
                                } else {
                                    showingPermissionAlert = true
                                }
                            }
                        }
                    }
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                }
                .padding()
                
                // 录音时长
                Text(viewModel.isRecording ? "录音中: \(viewModel.formattedDuration)" : "点击开始录音")
                    .foregroundColor(.gray)
                
                // 转写状态
                if viewModel.isTranscribing {
                    ProgressView("正在转写...")
                        .padding()
                }
                
                // 转写结果
                if !viewModel.transcription.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("原始文本：")
                                .font(.headline)
                            Text(viewModel.transcription)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            if viewModel.isEnhancing {
                                ProgressView("正在润色...")
                                    .padding()
                            } else if !viewModel.enhancedText.isEmpty {
                                Text("润色后的文本：")
                                    .font(.headline)
                                Text(viewModel.enhancedText)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                if !viewModel.tags.isEmpty {
                                    Text("相关标签：")
                                        .font(.headline)
                                    FlowLayout(spacing: 8) {
                                        ForEach(viewModel.tags, id: \.self) { tag in
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
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("语音转文字")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingRecordingList = true
                    }) {
                        Image(systemName: "list.bullet")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingRecordingList) {
                HistoryView(audioService: audioService)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("需要麦克风权限", isPresented: $showingPermissionAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请在设置中允许访问麦克风，以便进行语音录制。")
            }
            .alert("操作失败", isPresented: .init(get: {
                viewModel.errorMessage != nil
            }, set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            })) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
            .onAppear {
                // 确保权限已经检查
                if viewModel.permissionStatus == .unknown {
                    Task {
                        await viewModel.checkMicrophonePermission()
                    }
                }
            }
        }
    }
}

// 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: Array(subviews))
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: Array(subviews))
        for (index, line) in result.lines.enumerated() {
            let y = bounds.minY + result.lineOffsets[index]
            var x = bounds.minX
            for item in line {
                let position = CGPoint(x: x, y: y)
                subviews[item.index].place(at: position, proposal: .unspecified)
                x += item.size.width + spacing
            }
        }
    }
    
    private struct FlowResult {
        struct Item {
            let index: Int
            let size: CGSize
        }
        
        struct Line {
            var items: [Item] = []
            var width: CGFloat = 0
            var height: CGFloat = 0
        }
        
        var lines: [[Item]] = []
        var lineOffsets: [CGFloat] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: [LayoutSubview]) {
            var currentLine = Line()
            var currentX: CGFloat = 0
            var maxY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth {
                    lines.append(currentLine.items)
                    lineOffsets.append(maxY)
                    maxY += lineHeight + spacing
                    currentLine = Line()
                    currentX = 0
                    lineHeight = 0
                }
                
                currentLine.items.append(Item(index: index, size: size))
                currentLine.width += size.width + spacing
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            if !currentLine.items.isEmpty {
                lines.append(currentLine.items)
                lineOffsets.append(maxY)
                maxY += lineHeight
            }
            
            size = CGSize(width: maxWidth, height: maxY)
        }
    }
}

#Preview {
    HomeView()
} 