import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("language") private var language = "zh-CN"
    @AppStorage("autoTranscribe") private var autoTranscribe = true
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("API 设置")) {
                    NavigationLink(destination: APISettingsView()) {
                        Label("API Key 设置", systemImage: "key.fill")
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