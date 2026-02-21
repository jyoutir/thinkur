import SwiftUI
import AppKit

private enum FeedbackType: String {
    case bug = "Bug Report"
    case feature = "Feature Request"
}

struct SupportView: View {
    @State private var appeared = false
    @State private var activeFeedback: FeedbackType?
    @State private var descriptionText = ""
    @State private var attachedImage: NSImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Get help or share feedback.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "About") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "info.circle", title: "Version") {
                            Text("1.0.0")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Divider()

                        SettingsRowView(icon: "envelope", title: "Contact") {
                            Link("support@thinkur.app", destination: URL(string: "mailto:support@thinkur.app")!)
                                .font(Typography.body)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                GroupedSettingsSection(title: "Feedback") {
                    VStack(spacing: 0) {
                        feedbackRow(
                            icon: "ladybug",
                            title: "Report a Bug",
                            type: .bug
                        )

                        Divider()

                        feedbackRow(
                            icon: "lightbulb",
                            title: "Request a Feature",
                            type: .feature
                        )
                    }
                }

                if let activeFeedback {
                    feedbackForm(type: activeFeedback)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Support")
        .onAppear { appeared = true }
    }

    // MARK: - Feedback Row

    private func feedbackRow(icon: String, title: String, type: FeedbackType) -> some View {
        Button {
            withAnimation(Animations.glassMorph) {
                if activeFeedback == type {
                    activeFeedback = nil
                } else {
                    activeFeedback = type
                    descriptionText = ""
                    attachedImage = nil
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(width: 20)

                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .rotationEffect(.degrees(activeFeedback == type ? 90 : 0))
                    .animation(Animations.glassMorph, value: activeFeedback)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feedback Form

    private func feedbackForm(type: FeedbackType) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(type == .bug ? "Describe the bug" : "Describe your idea")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            TextEditor(text: $descriptionText)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.field)
                        .fill(.quaternary.opacity(0.5))
                )

            // Image attachment area
            if let image = attachedImage {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))

                    Spacer()

                    Button {
                        attachedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.xs)
            } else {
                Button {
                    pasteImageFromClipboard()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 12))
                        Text("Paste Screenshot")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()

                Button {
                    sendFeedback(type: type)
                } label: {
                    Label("Send via Email", systemImage: "paperplane")
                        .font(Typography.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    // MARK: - Image Paste

    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard) else { return }
        attachedImage = image
    }

    // MARK: - Send

    private func sendFeedback(type: FeedbackType) {
        let subject = "[thinkur] \(type.rawValue)"
        let body = composeBody(type: type)

        // Use NSSharingService to compose email (supports attachments)
        guard let service = NSSharingService(named: .composeEmail) else {
            // Fallback to mailto if Mail isn't available
            openMailto(subject: subject, body: body)
            return
        }

        service.recipients = ["support@thinkur.app"]
        service.subject = subject

        var items: [Any] = [body]
        if let image = attachedImage, let tiffData = image.tiffRepresentation {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("thinkur-feedback-screenshot.png")
            if let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: tempURL)
                items.append(tempURL)
            }
        }

        service.perform(withItems: items)
    }

    private func openMailto(subject: String, body: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@thinkur.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func composeBody(type: FeedbackType) -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let ramGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)

        var lines = [
            "Description:",
            descriptionText,
            "",
            "---",
            "System Info (auto-generated)",
            "App Version: 1.0.0",
            "macOS: \(osVersion)",
            "Model: \(Constants.whisperModel)",
            "RAM: \(ramGB) GB",
        ]

        if attachedImage != nil {
            lines.insert("(Screenshot attached)", at: 2)
        }

        return lines.joined(separator: "\n")
    }
}
