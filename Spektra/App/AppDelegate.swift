import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    @objc func showAboutPanel(_ sender: Any?) {
        let creditsText = """
        See the invisible signals all around you.

        Spektra turns your RTL-SDR dongle into a real-time spectrum analyzer \
        and radio receiver — explore FM broadcasts, weather stations, aircraft \
        transponders, amateur radio, and more. We believe in making radio \
        accessible and fun.

        Subversive Software builds tools that put power back in people's hands.

        \u{00A9} 2026 subversivesoftware.org
        """

        let credits = NSAttributedString(
            string: creditsText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Spektra",
            .applicationVersion: version,
            .version: build,
            .credits: credits
        ])
    }
}
