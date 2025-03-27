import SwiftUI

struct RecordingAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 外圈动画
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.0 : 1.0)
            
            // 内圈动画
            Circle()
                .stroke(Color.red.opacity(0.5), lineWidth: 2)
                .frame(width: 90, height: 90)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .opacity(isAnimating ? 0.0 : 1.0)
            
            // 中心圆
            Circle()
                .fill(Color.red)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 0.9 : 1.0)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    RecordingAnimationView()
} 