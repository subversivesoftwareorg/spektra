import SwiftUI
import Sparkle

@main
struct SpektraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

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

            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
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
