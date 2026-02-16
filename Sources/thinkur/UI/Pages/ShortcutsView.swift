import SwiftUI

struct ShortcutsView: View {
    @Environment(ShortcutsViewModel.self) private var viewModel
    @State private var appeared = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Create text shortcuts that expand when you dictate them.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                // Add shortcut form
                GroupedSettingsSection(title: "New Shortcut") {
                    VStack(spacing: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            TextField("Trigger (e.g. //sig)", text: $vm.newTrigger)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)

                            Image(systemName: "arrow.right")
                                .foregroundStyle(ColorTokens.textTertiary)

                            TextField("Expansion (e.g. Best regards, ...)", text: $vm.newExpansion)
                                .textFieldStyle(.roundedBorder)

                            Button("Add") {
                                Task { await viewModel.addShortcut() }
                            }
                            .disabled(vm.newTrigger.isEmpty || vm.newExpansion.isEmpty)
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.danger)
                        }
                    }
                    .padding(Spacing.md)
                }

                // Shortcut list
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Your Shortcuts")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.shortcuts.isEmpty {
                        GlassEmptyState(
                            icon: "text.badge.plus",
                            title: "No shortcuts yet",
                            subtitle: "Create one above"
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.shortcuts, id: \.trigger) { shortcut in
                                ShortcutRowView(shortcut: shortcut) {
                                    Task { await viewModel.deleteShortcut(shortcut) }
                                }
                                if shortcut.trigger != viewModel.shortcuts.last?.trigger {
                                    Divider()
                                }
                            }
                        }
                        .glassCard()
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
        .navigationTitle("Shortcuts")
        .task { await viewModel.loadData() }
        .onAppear { appeared = true }
    }
}
