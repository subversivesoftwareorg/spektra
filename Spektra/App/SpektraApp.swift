import SwiftUI
import SwiftData

@main
struct SpektraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var showSDRHelp = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .sheet(isPresented: $showSDRHelp) { SDRHelpView() }
        }
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Spektra") {
                    appDelegate.showAboutPanel(nil)
                }
            }

            CommandGroup(replacing: .help) {
                Button("SDR Guide") {
                    showSDRHelp = true
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
