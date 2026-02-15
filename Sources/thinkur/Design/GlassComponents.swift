import SwiftUI

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.card

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
