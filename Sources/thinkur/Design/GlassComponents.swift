import SwiftUI

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = CornerRadius.card

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(settings.accentUITint.opacity(colorScheme == .dark ? 0.2 : 0.4), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Clear

struct GlassClear: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.card

    func body(content: Content) -> some View {
        content
            .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassClear(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(GlassClear(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Capsule

struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .capsule)
    }
}

extension View {
    func glassCapsule() -> some View {
        modifier(GlassCapsule())
    }
}

// MARK: - Glass Empty State

struct GlassEmptyState: View {
    @Environment(SettingsManager.self) private var settings
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(settings.accentUITint.opacity(0.3))

            Text(title)
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .glassClear()
    }
}
