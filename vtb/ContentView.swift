//
//  ContentView.swift
//  vtb
//
//  Created by Darwin on 2025/3/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioService: AudioService
    @State private var selectedTab = 0
    
    init() {
        let audioService = AudioService(apiKey: "YOUR_API_KEY") // 替换为实际的 API Key
        _audioService = StateObject(wrappedValue: audioService)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            HistoryView(audioService: audioService)
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
