import AppKit
import SwiftUI

// MARK: - MCP App Data

private struct MCPApp: Identifiable {
    let id: String
    let name: String
    let bundleID: String?
    let sfSymbol: String
    let instruction: String
}

private let mcpApps: [MCPApp] = [
    MCPApp(id: "claude-desktop", name: "Claude Desktop", bundleID: "com.anthropic.claudefordesktop",
           sfSymbol: "desktopcomputer",
           instruction: "Settings \u{2192} Developer \u{2192} Edit Config \u{2192} paste"),
    MCPApp(id: "claude-code", name: "Claude Code", bundleID: nil,
           sfSymbol: "terminal",
           instruction: "Paste into .claude.json or project settings"),
    MCPApp(id: "cursor", name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92",
           sfSymbol: "cursorarrow.rays",
           instruction: "Cursor Settings \u{2192} MCP \u{2192} Add Server \u{2192} paste"),
    MCPApp(id: "windsurf", name: "Windsurf", bundleID: "com.codeium.windsurf",
           sfSymbol: "wind",
           instruction: "Cascade Settings \u{2192} MCP \u{2192} paste"),
    MCPApp(id: "chatgpt", name: "ChatGPT", bundleID: "com.openai.chat",
           sfSymbol: "bubble.left.and.text.bubble.right",
           instruction: "Settings \u{2192} MCP Servers \u{2192} Add \u{2192} paste"),
]

// MARK: - MCPView

struct MCPView: View {
    @Environment(IntegrationsViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @State private var selectedAppID = "claude-desktop"
    @State private var mcpConfigCopied = false
    @State private var copiedPromptIndex: Int?
    @State private var appeared = false

    private var selectedApp: MCPApp {
        mcpApps.first { $0.id == selectedAppID } ?? mcpApps[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Let AI assistants work with your transcription history.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                setupSection

                promptsSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.danger)
                }
            }
            .padding(Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("MCP")
        .onAppear { appeared = true }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Setup")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            appChips

            configCard

            HStack(spacing: Spacing.xs) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("Read-only. Nothing leaves your device.")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    @ViewBuilder
    private var appChips: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(mcpApps) { app in
                Button {
                    withAnimation(Animations.glassMorph) {
                        selectedAppID = app.id
                    }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        appChipIcon(app)
                        Text(app.name)
                            .font(Typography.caption)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background {
                        if selectedAppID == app.id {
                            Capsule().fill(.regularMaterial)
                        } else {
                            Capsule().strokeBorder(ColorTokens.border, lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    selectedAppID == app.id
                        ? ColorTokens.textPrimary
                        : ColorTokens.textSecondary
                )
            }
        }
    }

    @ViewBuilder
    private func appChipIcon(_ app: MCPApp) -> some View {
        if let bundleID = app.bundleID {
            AppIconView(bundleID: bundleID, appName: app.name, size: 14)
        } else {
            Image(systemName: app.sfSymbol)
                .font(.system(size: 10))
        }
    }

    private var mcpConfigJSON: String {
        let mcpPath = Bundle.main.bundlePath + "/Contents/MacOS/thinkur-mcp"
        return """
        {
          "mcpServers": {
            "thinkur": {
              "command": "\(mcpPath)"
            }
          }
        }
        """
    }

    @ViewBuilder
    private var configCard: some View {
        GroupedSettingsSection {
            ZStack {
                // Normal content
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("MCP Config")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    Text(mcpConfigJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTokens.border.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

                    Text(selectedApp.instruction)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .opacity(mcpConfigCopied ? 0 : 1)

                // Copied overlay
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(settings.accentUITint)
                    Text("Copied to clipboard")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                .opacity(mcpConfigCopied ? 1 : 0)
                .scaleEffect(mcpConfigCopied ? 1 : 0.8)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
            .onTapGesture { copyMCPConfig() }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: mcpConfigCopied)
        }
    }

    // MARK: - Prompts

    private static let prompts: [(icon: String, label: String, prompt: String)] = [
        (
            "text.magnifyingglass",
            "Search your transcription history",
            "Search my thinkur transcription history for anything related to deadlines or due dates. List each match with the date it was dictated and a short excerpt."
        ),
        (
            "doc.text",
            "Summarise what you dictated today",
            "Pull everything I dictated in thinkur today and give me a concise summary — key topics, decisions made, and any action items."
        ),
        (
            "chart.line.uptrend.xyaxis",
            "Find patterns in your meeting notes",
            "Look through my recent thinkur transcriptions and identify recurring themes, frequently mentioned people or projects, and any topics that came up in multiple sessions."
        ),
    ]

    @ViewBuilder
    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Prompts")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            GroupedSettingsSection {
                VStack(spacing: 0) {
                    ForEach(Array(Self.prompts.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider() }
                        promptRow(index: index, icon: item.icon, label: item.label, prompt: item.prompt)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func promptRow(index: Int, icon: String, label: String, prompt: String) -> some View {
        let isCopied = copiedPromptIndex == index
        Button {
            copyPrompt(prompt, index: index)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 20)
                Text(label)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(isCopied ? ColorTokens.textTertiary : ColorTokens.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func copyPrompt(_ prompt: String, index: Int) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        copiedPromptIndex = index
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedPromptIndex == index { copiedPromptIndex = nil }
        }
    }

    private func copyMCPConfig() {
        guard !mcpConfigCopied else { return }
        let mcpPath = Bundle.main.bundlePath + "/Contents/MacOS/thinkur-mcp"

        guard FileManager.default.fileExists(atPath: mcpPath) else {
            viewModel.errorMessage = "MCP binary not found. Please build and run thinkur from Xcode first."
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mcpConfigJSON, forType: .string)
        mcpConfigCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            mcpConfigCopied = false
        }
    }
}
