import SwiftUI

/// Reusable pulsing dots animation — used in the floating panel and menu bar
/// to indicate the app is processing/transcribing.
struct ThinkingDotsView: View {
    var dotSize: CGFloat = 6
    var color: Color = .white
    var spacing: CGFloat = 4

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.4)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}
