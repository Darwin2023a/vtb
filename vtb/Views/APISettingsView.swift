import SwiftUI

struct APISettingsView: View {
    @AppStorage("siliconflow_api_key") private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("API 设置")) {
                SecureField("SiliconFlow API Key", text: $apiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: {
                    if apiKey.isEmpty {
                        alertMessage = "请输入 API Key"
                        showingAlert = true
                    } else {
                        alertMessage = "API Key 已保存"
                        showingAlert = true
                    }
                }) {
                    Text("保存")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.blue)
                .cornerRadius(8)
            }
            
            Section(header: Text("说明")) {
                Text("请从 SiliconFlow 官网获取 API Key")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("API 设置")
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
} 