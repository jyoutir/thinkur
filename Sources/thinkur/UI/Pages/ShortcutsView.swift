import SwiftUI

struct ShortcutsView: View {
    @Environment(ShortcutsViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
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
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))

                            Text("No shortcuts yet")
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textSecondary)

                            Text("Create one above")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
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
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Shortcuts")
        .task {
            await viewModel.loadData()
        }
    }
}
