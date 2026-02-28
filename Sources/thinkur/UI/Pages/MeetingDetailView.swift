import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    let meeting: MeetingRecord

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Button {
                    viewModel.selectedMeeting = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Meetings")
                            .font(Typography.body)
                    }
                    .foregroundStyle(settings.accentUITint)
                }
                .buttonStyle(.plain)

                if let error = viewModel.editError {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(.white)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTokens.danger.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.button))
                }

                MeetingHeaderSection(meeting: meeting)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 0), value: appeared)

                MeetingStatsSection(meeting: meeting)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 1), value: appeared)

                Divider()

                MeetingTranscriptSection(meeting: meeting)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 2), value: appeared)
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Meeting")
        .onAppear { appeared = true }
    }
}
