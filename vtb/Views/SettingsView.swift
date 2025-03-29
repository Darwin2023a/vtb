import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("language") private var language = "zh-CN"
    @AppStorage("autoTranscribe") private var autoTranscribe = true
    @AppStorage("siliconflow_api_key") private var siliconflowApiKey = ""
    @AppStorage("flomo_api_key") private var flomoApiKey = ""
    @AppStorage("flomo_api_url") private var flomoApiUrl = "https://flomoapp.com/iwh/MjI1MzMxNA/b837df1dfa9334ff7869a5f8745021db/"
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("API 设置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文本转写和润色 API Key")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        SecureField("输入 SiliconFlow API Key", text: $siliconflowApiKey)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flomo API Key")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        SecureField("输入 Flomo API Key", text: $flomoApiKey)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flomo API URL")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        TextField("输入 Flomo API URL", text: $flomoApiUrl)
                    }
                }
                
                Section(header: Text("基本设置")) {
                    Picker("语言", selection: $language) {
                        Text("中文").tag("zh-CN")
                        Text("English").tag("en-US")
                    }
                    
                    Toggle("自动转写", isOn: $autoTranscribe)
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
        }
    }
}

#Preview {
    SettingsView()
} 