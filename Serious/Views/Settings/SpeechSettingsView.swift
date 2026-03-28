import SwiftUI

struct SpeechSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var deviceManager = AudioDeviceManager()

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("Microphone") {
                Picker("Input Device", selection: $s.audioInputDeviceUID) {
                    Text("System Default").tag("")
                    ForEach(deviceManager.inputDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
            }

            Section("Recognition") {
                Picker("Language", selection: $s.speechLocale) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("English (AU)").tag("en-AU")
                    Text("Spanish").tag("es-ES")
                    Text("French").tag("fr-FR")
                    Text("German").tag("de-DE")
                }
            }

            Section("Matching") {
                Slider(value: $s.matchSensitivity, in: 0.4...0.95, step: 0.05) {
                    Text("Match Sensitivity: \(Int(settings.matchSensitivity * 100))%")
                }
                Text("Lower values are more forgiving of pronunciation differences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pause Detection") {
                Slider(value: $s.silenceTimeout, in: 0.5...5.0, step: 0.5) {
                    Text("Silence Timeout: \(String(format: "%.1fs", settings.silenceTimeout))")
                }
                Text("How long to wait before pausing the teleprompter when you stop speaking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
