import SwiftUI

struct HomeView: View {
    @StateObject private var audioService = AudioService()
    @StateObject private var viewModel: HomeViewModel
    @State private var showingRecordingList = false
    @State private var showingSettings = false
    @State private var showingPermissionAlert = false
    @State private var isSending = false
    
    private var flomoService: FlomoService {
        FlomoService()
    }
    
    init() {
        let audioService = AudioService()
        _audioService = StateObject(wrappedValue: audioService)
        _viewModel = StateObject(wrappedValue: HomeViewModel(audioService: audioService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                RecordingButton(viewModel: viewModel, showingPermissionAlert: $showingPermissionAlert)
                RecordingStatus(viewModel: viewModel)
                TranscriptionContent(viewModel: viewModel, isSending: $isSending, sendToFlomo: sendToFlomo)
            }
            .navigationTitle("语音转文字")
            .toolbar {
                ToolbarItems(showingRecordingList: $showingRecordingList, showingSettings: $showingSettings)
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
            .alert("错误", isPresented: $viewModel.showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
            .alert("成功", isPresented: $viewModel.showingSuccess) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .onAppear {
                if viewModel.permissionStatus == .unknown {
                    Task {
                        await viewModel.checkMicrophonePermission()
                    }
                }
            }
        }
    }
    
    private func sendToFlomo() async {
        isSending = true
        do {
            try await viewModel.sendToFlomo()
            await MainActor.run {
                isSending = false
                viewModel.successMessage = "发送成功！"
                viewModel.showingSuccess = true
            }
        } catch let error as FlomoError {
            await MainActor.run {
                viewModel.errorMessage = error.localizedDescription
                viewModel.showingError = true
                isSending = false
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "发送失败：\(error.localizedDescription)"
                viewModel.showingError = true
                isSending = false
            }
        }
    }
}

// MARK: - 子视图
struct RecordingButton: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var showingPermissionAlert: Bool
    
    var body: some View {
        Button(action: {
            if viewModel.isRecording {
                viewModel.stopRecording()
            } else {
                if viewModel.permissionStatus == .granted {
                    Task {
                        do {
                            try await viewModel.startRecording()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                            viewModel.showingError = true
                        }
                    }
                } else if viewModel.permissionStatus == .denied {
                    showingPermissionAlert = true
                } else {
                    Task {
                        let granted = await viewModel.requestMicrophoneAccess()
                        if granted {
                            do {
                                try await viewModel.startRecording()
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                                viewModel.showingError = true
                            }
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
    }
}

struct RecordingStatus: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        Text(viewModel.isRecording ? "录音中: \(viewModel.formattedDuration)" : "点击开始录音")
            .foregroundColor(.gray)
        
        if viewModel.isTranscribing {
            ProgressView("正在转写...")
                .padding()
        }
    }
}

struct TranscriptionContent: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var isSending: Bool
    let sendToFlomo: () async -> Void
    
    private var flomoService: FlomoService {
        let apiKey = UserDefaults.standard.string(forKey: "flomo_api_key") ?? ""
        let apiUrl = UserDefaults.standard.string(forKey: "flomo_api_url") ?? "https://flomoapp.com/iwh/MjI1MzMxNA/b837df1dfa9334ff7869a5f8745021db/"
        return FlomoService(apiKey: apiKey, baseURL: apiUrl)
    }
    
    var body: some View {
        if !viewModel.transcription.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TranscriptionText(title: "原始文本：", text: viewModel.transcription)
                        
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
                    
                    if viewModel.isEnhancing {
                        ProgressView("正在润色...")
                            .padding()
                    } else if !viewModel.enhancedText.isEmpty {
                        EnhancedContent(viewModel: viewModel, isSending: $isSending, sendToFlomo: sendToFlomo)
                    } else if viewModel.enhancementError != nil {
                        EnhancementErrorView(viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
    }
    
    private func sendOriginalText() async {
        isSending = true
        do {
            try await flomoService.sendOriginalText(viewModel.transcription)
            await MainActor.run {
                isSending = false
                viewModel.successMessage = "原始文本发送成功！"
                viewModel.showingSuccess = true
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "发送失败：\(error.localizedDescription)"
                viewModel.showingError = true
                isSending = false
            }
        }
    }
}

struct TranscriptionText: View {
    let title: String
    let text: String
    
    var body: some View {
        Text(title)
            .font(.headline)
        Text(text)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

struct EnhancedContent: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var isSending: Bool
    let sendToFlomo: () async -> Void
    
    private var flomoService: FlomoService {
        let apiKey = UserDefaults.standard.string(forKey: "flomo_api_key") ?? ""
        let apiUrl = UserDefaults.standard.string(forKey: "flomo_api_url") ?? "https://flomoapp.com/iwh/MjI1MzMxNA/b837df1dfa9334ff7869a5f8745021db/"
        return FlomoService(apiKey: apiKey, baseURL: apiUrl)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                TranscriptionText(title: "润色后的文本：", text: viewModel.enhancedText)
                
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
    }
    
    private func sendEnhancedText() async {
        isSending = true
        do {
            try await flomoService.sendEnhancedText(viewModel.enhancedText, tags: viewModel.tags)
            await MainActor.run {
                isSending = false
                viewModel.successMessage = "润色文本发送成功！"
                viewModel.showingSuccess = true
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "发送失败：\(error.localizedDescription)"
                viewModel.showingError = true
                isSending = false
            }
        }
    }
}

struct EnhancementErrorView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("润色失败")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(viewModel.enhancementError ?? "未知错误")
                .foregroundColor(.red)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Button(action: {
                Task {
                    await viewModel.retryEnhancement()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新润色")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Menu {
                ForEach(TextEnhancementService.Model.allCases, id: \.self) { model in
                    Button(action: {
                        Task {
                            await viewModel.retryEnhancement(with: model)
                        }
                    }) {
                        HStack {
                            Text(model.displayName)
                            if model == viewModel.selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("选择其他模型")
                    Spacer()
                    Text(viewModel.selectedModel.displayName)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct ToolbarItems: ToolbarContent {
    @Binding var showingRecordingList: Bool
    @Binding var showingSettings: Bool
    
    var body: some ToolbarContent {
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