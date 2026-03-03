import SwiftUI

// MARK: - Interactive Card

struct InteractiveCard: ViewModifier {
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = CornerRadius.card

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(settings.accentUITint.opacity(colorScheme == .dark ? 0.2 : 0.4), lineWidth: 1)
                )
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(settings.accentUITint.opacity(colorScheme == .dark ? 0.2 : 0.4), lineWidth: 1)
                )
        }
    }
}

extension View {
    func interactiveCard(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(InteractiveCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Material Clear

struct MaterialClear: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.card

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func materialClear(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(MaterialClear(cornerRadius: cornerRadius))
    }
}

// MARK: - Material Capsule

struct MaterialCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.regularMaterial, in: Capsule())
        }
    }
}

extension View {
    func materialCapsule() -> some View {
        modifier(MaterialCapsule())
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
        .materialClear()
    }
}
