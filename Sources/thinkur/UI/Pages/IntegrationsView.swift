import AppKit
import SwiftUI

struct MCPView: View {
    @Environment(IntegrationsViewModel.self) private var viewModel
    @State private var mcpConfigCopied = false
    @State private var copiedPromptIndex: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Let AI assistants work with your transcription history.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                mcpSection

                useCasesSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.danger)
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - MCP Section

    @ViewBuilder
    private var mcpSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Setup")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            GroupedSettingsSection {
                VStack(spacing: 0) {
                    stepRow(number: "1", text: "Copy the config below")
                    Divider()
                    stepRow(number: "2", text: "Open your AI tool's MCP settings")
                    Divider()
                    stepRow(number: "3", text: "Paste and save — you're connected")
                }
            }

            GroupedSettingsSection {
                SettingsRowView(
                    icon: "doc.on.clipboard",
                    title: "MCP Config",
                    subtitle: "For Claude Desktop, Claude Code, Cursor, Windsurf, and others"
                ) {
                    Button {
                        copyMCPConfig()
                    } label: {
                        Text(mcpConfigCopied ? "Copied" : "Copy")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mcpConfigCopied ? ColorTokens.textTertiary : ColorTokens.textPrimary)
                }
            }

            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 1)

                Text("Read-only access to your local transcription history. Nothing leaves your device.")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    @ViewBuilder
    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(number)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 20, height: 20)
                .background(ColorTokens.border, in: Circle())
            Text(text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
    }

    // MARK: - Try It

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
    private var useCasesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Try it — copy a prompt")
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
        let mcpPath = Bundle.main.bundlePath + "/Contents/MacOS/thinkur-mcp"

        guard FileManager.default.fileExists(atPath: mcpPath) else {
            viewModel.errorMessage = "MCP binary not found. Please build and run thinkur from Xcode first."
            return
        }

        let config = """
        {
          "mcpServers": {
            "thinkur": {
              "command": "\(mcpPath)"
            }
          }
        }
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(config, forType: .string)
        mcpConfigCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            mcpConfigCopied = false
        }
    }
}
