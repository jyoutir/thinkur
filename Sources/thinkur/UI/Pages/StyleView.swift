import SwiftUI

struct StyleView: View {
    @Environment(StyleViewModel.self) private var viewModel
    @State private var appeared = false
    @State private var showingAddMenu = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Adapt your voice typing style for each application.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Per-App Styles") {
                    VStack(spacing: 0) {
                        if viewModel.stylePreferences.isEmpty {
                            Text("No apps yet. Start dictating to see apps here.")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                        } else {
                            ForEach(viewModel.stylePreferences) { entry in
                                StyleAppRow(entry: entry) { newStyle in
                                    Task { await viewModel.updateStyle(for: entry.id, style: newStyle) }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.removeApp(bundleID: entry.id) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                if entry.id != viewModel.stylePreferences.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Menu {
                    let apps = viewModel.availableApps
                    if apps.isEmpty {
                        Text("No additional apps running")
                    } else {
                        ForEach(apps, id: \.bundleID) { app in
                            Button(app.appName) {
                                Task { await viewModel.addApp(bundleID: app.bundleID, appName: app.appName) }
                            }
                        }
                    }
                } label: {
                    Label("Add App", systemImage: "plus")
                        .font(Typography.body)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Style")
        .task { await viewModel.loadData() }
        .onAppear { appeared = true }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}
