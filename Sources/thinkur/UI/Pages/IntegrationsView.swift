import AppKit
import SwiftUI

struct MCPView: View {
    @Environment(IntegrationsViewModel.self) private var viewModel
    @State private var mcpConfigCopied = false

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
            GroupedSettingsSection {
                SettingsRowView(
                    icon: "brain",
                    title: "Model Context Protocol",
                    subtitle: "Give AI tools read access to your dictation data"
                ) {
                    Button {
                        copyMCPConfig()
                    } label: {
                        Text(mcpConfigCopied ? "Copied" : "Copy Config")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mcpConfigCopied ? ColorTokens.textTertiary : ColorTokens.textPrimary)
                }
            }

            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 1)

                Text("Works with Claude Desktop, Claude Code, Cursor, and other MCP-compatible tools. Copy the config and paste it into your AI tool's MCP settings. Your data stays on your device.")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    // MARK: - Use Cases

    @ViewBuilder
    private var useCasesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("What you can do")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            GroupedSettingsSection {
                VStack(spacing: 0) {
                    useCaseRow(
                        icon: "text.magnifyingglass",
                        text: "Search your transcription history"
                    )
                    Divider()
                    useCaseRow(
                        icon: "doc.text",
                        text: "Ask AI to summarise what you dictated today"
                    )
                    Divider()
                    useCaseRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Find patterns in your meeting notes"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func useCaseRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 20)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
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
