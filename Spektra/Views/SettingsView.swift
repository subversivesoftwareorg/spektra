import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        Form {
            Section("About") {
                LabeledContent("App") { Text("Spektra") }
                LabeledContent("Version") {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
                    Text("\(version) (\(build))")
                }
            }

            Section("SDR") {
                LabeledContent("Library") { Text("librtlsdr via Homebrew") }
                LabeledContent("Install") { Text("brew install librtlsdr") }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
