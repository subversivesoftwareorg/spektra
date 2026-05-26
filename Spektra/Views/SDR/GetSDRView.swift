import SwiftUI

struct GetSDRView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                introSection
                recommendedSection
                budgetSection
                whatYouNeedSection
                setupSection
            }
            .navigationTitle("Getting an SDR")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 450)
    }

    // MARK: - Intro

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("An RTL-SDR dongle turns your Mac into a radio receiver covering **24 MHz to 1.7 GHz** — FM radio, aircraft communications, weather satellites, ship tracking, and much more.")
                    .font(.callout)

                Text("These started as cheap DVB-T TV tuner sticks, but the open-source community discovered they could be repurposed as general-purpose software defined radios. A capable setup costs under $30.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Recommended

    private var recommendedSection: some View {
        Section("Recommended Dongles") {
            sdrRow(
                name: "RTL-SDR Blog V4",
                price: "~$30",
                icon: "star.fill",
                color: .yellow,
                details: "The current best all-around option. Includes a 1 PPM TCXO for accurate tuning, improved filtering, and a USB-C connector. Comes with dipole antenna kit.",
                searchTerm: "RTL-SDR Blog V4"
            )

            sdrRow(
                name: "NooElec NESDR Smart v5",
                price: "~$25",
                icon: "star.fill",
                color: .yellow,
                details: "Aluminum enclosure with excellent thermal performance. 0.5 PPM TCXO, SMA connector, R820T2 tuner. Great build quality.",
                searchTerm: "NooElec NESDR Smart v5"
            )

            sdrRow(
                name: "NooElec NESDR Mini",
                price: "~$20",
                icon: "checkmark.circle.fill",
                color: .green,
                details: "Compact and affordable. R820T tuner, MCX connector. The one Spektra was developed with. Good starter option.",
                searchTerm: "NooElec NESDR Mini"
            )
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        Section("Budget Option") {
            sdrRow(
                name: "Generic RTL2832U Dongle",
                price: "~$10-15",
                icon: "dollarsign.circle",
                color: .green,
                details: "Unbranded RTL2832U + R820T dongles work fine for getting started. Less stable oscillator means slight frequency drift, but perfectly usable. Search for \"RTL2832U R820T\" on Amazon or AliExpress.",
                searchTerm: "RTL2832U R820T SDR"
            )
        }
    }

    private func sdrRow(name: String, price: String, icon: String, color: Color, details: String, searchTerm: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(name)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(price)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Search: \"\(searchTerm)\"")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
    }

    // MARK: - What You Need

    private var whatYouNeedSection: some View {
        Section("What You Need") {
            needRow("cpu", "RTL-SDR Dongle", "Any RTL2832U-based device with an R820T, R820T2, R828D, or E4000 tuner. All of the above qualify.", essential: true)
            needRow("antenna.radiowaves.left.and.right", "Antenna", "Most dongles include a basic antenna. It works for strong signals (FM radio, NOAA weather). For weaker signals, a dipole antenna kit is a big upgrade.", essential: false)
            needRow("terminal", "librtlsdr", "The open-source driver library. Install with: brew install librtlsdr", essential: true)
            needRow("usb.connector.horizontal", "USB Port", "Dongles use USB-A or USB-C. If your Mac only has USB-C, you may need an adapter (though the RTL-SDR V4 is USB-C native).", essential: true)
        }
    }

    private func needRow(_ icon: String, _ title: String, _ detail: String, essential: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(essential ? .blue : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    if essential {
                        Text("Required")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    } else {
                        Text("Optional")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Setup

    private var setupSection: some View {
        Section("Quick Setup") {
            VStack(alignment: .leading, spacing: 10) {
                setupStep(1, "Install the driver library", "Open Terminal and run:\nbrew install librtlsdr")
                setupStep(2, "Plug in your dongle", "Use a direct USB port if possible. USB hubs can sometimes cause power issues.")
                setupStep(3, "Open the SDR tab", "Spektra will auto-detect the device within a few seconds.")
                setupStep(4, "Start scanning", "Click Start Scanning and select a frequency preset to begin exploring the radio spectrum.")
            }
            .padding(.vertical, 4)
        }
    }

    private func setupStep(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
