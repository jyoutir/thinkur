import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "Bug Report"
    case feature = "Feature Request"
    case question = "Question"

    var id: String { rawValue }
}

/// Delegate to detect when the user actually sends the email from Mail.app.
private class SharingDelegate: NSObject, NSSharingServiceDelegate {
    var onSent: (() -> Void)?

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        onSent?()
    }
}

struct SupportView: View {
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false
    @State private var showForm = false
    @State private var selectedCategory: FeedbackCategory = .bug
    @State private var descriptionText = ""
    @State private var attachedImage: NSImage?
    @State private var feedbackSent = false
    @State private var pasteMonitor: Any?
    @State private var sharingDelegate: SharingDelegate?

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
                            Link("jyo@thinkur.app", destination: URL(string: "mailto:jyo@thinkur.app")!)
                                .font(Typography.body)
                                .foregroundStyle(settings.accentUITint)
                        }
                    }
                }

                GroupedSettingsSection(title: "Feedback") {
                    feedbackRow()
                }

                if showForm {
                    if feedbackSent {
                        thankYouView()
                    } else {
                        feedbackForm()
                    }
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

    private func feedbackRow() -> some View {
        Button {
            withAnimation(Animations.glassMorph) {
                showForm.toggle()
                if showForm {
                    descriptionText = ""
                    attachedImage = nil
                    feedbackSent = false
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 14))
                    .foregroundStyle(settings.accentUITint)
                    .frame(width: 20)

                Text("Send Feedback")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .rotationEffect(.degrees(showForm ? 90 : 0))
                    .animation(Animations.glassMorph, value: showForm)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Thank You

    private func thankYouView() -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("Your feedback has been sent.")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Thank you for helping improve thinkur.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .glassCard()
    }

    // MARK: - Feedback Form

    private func feedbackForm() -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Category")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            Picker("Category", selection: $selectedCategory) {
                ForEach(FeedbackCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)

            Text("Description")
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

            // Image attachment preview
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
            }

            HStack(spacing: Spacing.sm) {
                Button {
                    attachScreenshot()
                } label: {
                    Label("Attach Screenshot", systemImage: "paperclip")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button {
                    sendFeedback()
                } label: {
                    Label("Send via Email", systemImage: "paperplane.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Spacing.md)
        .glassCard()
        .onAppear { installPasteMonitor() }
        .onDisappear { removePasteMonitor() }
    }

    // MARK: - Paste Monitor

    /// Intercepts Cmd+V when the pasteboard contains an image so pasting
    /// screenshots works even while the TextEditor has focus.
    private func installPasteMonitor() {
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers == "v" else { return event }
            let pb = NSPasteboard.general
            guard let image = NSImage(pasteboard: pb) else { return event }
            attachedImage = image
            return nil // consume the event
        }
    }

    private func removePasteMonitor() {
        if let monitor = pasteMonitor {
            NSEvent.removeMonitor(monitor)
            pasteMonitor = nil
        }
    }

    // MARK: - Attach Screenshot

    private func attachScreenshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a screenshot to attach"
        guard panel.runModal() == .OK, let url = panel.url,
              let image = NSImage(contentsOf: url) else { return }
        attachedImage = image
    }

    // MARK: - Send

    private func sendFeedback() {
        let subject = "[thinkur] \(selectedCategory.rawValue)"
        let body = composeBody()

        guard let service = NSSharingService(named: .composeEmail) else {
            openMailto(subject: subject, body: body)
            return
        }

        let delegate = SharingDelegate()
        delegate.onSent = {
            withAnimation(Animations.glassMorph) {
                feedbackSent = true
            }
        }
        self.sharingDelegate = delegate
        service.delegate = delegate

        service.recipients = ["jyo@thinkur.app"]
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
        components.path = "jyo@thinkur.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func composeBody() -> String {
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
            "Model: Parakeet TDT 0.6B",
            "RAM: \(ramGB) GB",
        ]

        if attachedImage != nil {
            lines.insert("(Screenshot attached)", at: 2)
        }

        return lines.joined(separator: "\n")
    }
}
