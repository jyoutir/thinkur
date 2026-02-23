import SwiftUI

struct ShortcutsView: View {
    @Environment(ShortcutsViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Say a phrase, and thinkur types something else.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                // Add shortcut form
                GroupedSettingsSection(title: "Add Shortcut") {
                    VStack(spacing: Spacing.sm) {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            TextField("When I say…", text: $vm.newTrigger)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)

                            Image(systemName: "arrow.right")
                                .foregroundStyle(ColorTokens.textTertiary)
                                .padding(.top, 6)

                            TextEditor(text: $vm.newExpansion)
                                .font(Typography.body)
                                .scrollContentBackground(.hidden)
                                .padding(4)
                                .frame(minHeight: 32, maxHeight: 120)
                                .fixedSize(horizontal: false, vertical: true)
                                .glassClear(cornerRadius: CornerRadius.field)
                                .overlay(alignment: .topLeading) {
                                    if vm.newExpansion.isEmpty {
                                        Text("thinkur types…")
                                            .font(Typography.body)
                                            .foregroundStyle(ColorTokens.textTertiary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .allowsHitTesting(false)
                                    }
                                }

                            Button("Add") {
                                Task { await viewModel.addShortcut() }
                            }
                            .tint(settings.accentUITint)
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
