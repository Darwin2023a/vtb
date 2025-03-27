import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("用户名")
                                .font(.headline)
                            Text("点击登录")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("设置") {
                    NavigationLink {
                        Text("通用设置")
                    } label: {
                        Label("通用设置", systemImage: "gear")
                    }
                    
                    NavigationLink {
                        Text("隐私设置")
                    } label: {
                        Label("隐私设置", systemImage: "lock")
                    }
                    
                    NavigationLink {
                        Text("通知设置")
                    } label: {
                        Label("通知设置", systemImage: "bell")
                    }
                }
                
                Section("关于") {
                    NavigationLink {
                        Text("使用帮助")
                    } label: {
                        Label("使用帮助", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink {
                        Text("关于我们")
                    } label: {
                        Label("关于我们", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}

#Preview {
    ProfileView()
} 