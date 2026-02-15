import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Transcription") {
                HStack {
                    Text("Whisper Model")
                    Spacer()
                    Text(Constants.whisperModel)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("VAD Threshold")
                        Spacer()
                        Text(String(format: "%.2f", settings.vadThreshold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.vadThreshold, in: 0.1...0.9, step: 0.05)
                }
            }

            Section("Hotkey") {
                HStack {
                    Text("Current Key")
                    Spacer()
                    Text(hotkeyDisplayName)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Section("Post-Processing") {
                Toggle("Enable text post-processing", isOn: $settings.postProcessingEnabled)

                if settings.postProcessingEnabled {
                    Text("Cleans up transcriptions: removes fillers, converts spoken punctuation, capitalizes sentences, and adapts style per app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 340)
        .navigationTitle("Settings")
    }

    private var hotkeyDisplayName: String {
        switch settings.hotkeyCode {
        case 48: return "Tab"
        default: return "Key \(settings.hotkeyCode)"
        }
    }
}
