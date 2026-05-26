import SwiftUI

struct SDRHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                gettingStartedSection
                activitiesSection
                frequencyReferenceSection
                tipsSection
                legalSection
            }
            .navigationTitle("SDR Guide")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Getting Started

    private var gettingStartedSection: some View {
        Section("Getting Started") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your RTL-SDR dongle can receive signals from **24 MHz to 1766 MHz**, covering FM radio, aircraft, marine, amateur radio, weather satellites, and much more.")
                    .font(.callout)

                controlsGrid
            }
            .padding(.vertical, 4)
        }
    }

    private var controlsGrid: some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            controlRow("Frequency", "Center frequency in MHz. Type directly or use presets.")
            controlRow("Step", "Tuning increment for the arrow buttons (1 kHz–1 MHz).")
            controlRow("Gain", "Auto adjusts sensitivity. Manual lets you dial it in.")
            controlRow("Zoom", "1x = full 2 MHz bandwidth. 8x = 256 kHz detail view.")
            controlRow("Demod", "FM for most voice. AM for aviation. USB/LSB for sideband.")
            controlRow("Squelch", "Silences audio when signal drops below the threshold.")
        }
        .font(.caption)
    }

    private func controlRow(_ label: String, _ detail: String) -> some View {
        GridRow {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 70, alignment: .leading)
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Activities

    private var activitiesSection: some View {
        Section("What You Can Do") {
            ForEach(SDRActivity.all) { activity in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activity.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        if !activity.frequencies.isEmpty {
                            Text("Key Frequencies")
                                .font(.caption.weight(.semibold))
                                .padding(.top, 4)

                            ForEach(activity.frequencies, id: \.label) { freq in
                                HStack {
                                    Text(freq.label)
                                        .font(.caption)
                                    Spacer()
                                    Text(freq.value)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }

                        if !activity.howTo.isEmpty {
                            Text("How To")
                                .font(.caption.weight(.semibold))
                                .padding(.top, 4)

                            ForEach(Array(activity.howTo.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(i + 1).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text(step)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: activity.icon)
                            .font(.title3)
                            .foregroundStyle(activity.color)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.name)
                                .font(.body.weight(.medium))
                            HStack(spacing: 8) {
                                DifficultyBadge(level: activity.difficulty)
                                Text("Demod: \(activity.demod)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Frequency Reference

    private var frequencyReferenceSection: some View {
        Section("Quick Frequency Reference") {
            Grid(alignment: .leading, verticalSpacing: 4) {
                freqRefHeader
                Divider()
                freqRefRow("FM Radio", "88–108 MHz", "FM", "Always")
                freqRefRow("Air Traffic Control", "118–137 MHz", "AM", "Near airports")
                freqRefRow("NOAA Satellites", "137.1–137.9 MHz", "FM", "During passes")
                freqRefRow("APRS", "144.390 MHz", "FM", "Ham digital")
                freqRefRow("Amateur 2m", "144–148 MHz", "FM", "Varies")
                freqRefRow("MURS", "151.8–154.6 MHz", "FM", "Business/farm")
                freqRefRow("Public Safety VHF", "150–174 MHz", "FM", "Police/fire")
                freqRefRow("Marine VHF", "156–162 MHz", "FM", "Near water")
                freqRefRow("Railroad", "160.1–161.6 MHz", "FM", "Near tracks")
                freqRefRow("AIS Ships", "161.975 MHz", "FM", "Near water")
                freqRefRow("NOAA Weather", "162.4–162.55 MHz", "FM", "Always")
                freqRefRow("Radiosondes", "400–406 MHz", "FM", "Twice daily")
                freqRefRow("ISM 433", "433–435 MHz", "-", "IoT/key fobs")
                freqRefRow("Public Safety UHF", "450–470 MHz", "FM", "Police/fire")
                freqRefRow("FRS/GMRS", "462–467 MHz", "FM", "Events")
                freqRefRow("Wireless Mics", "470–698 MHz", "FM", "Events/venues")
                freqRefRow("Trunked 800", "851–869 MHz", "FM", "Police/fire")
                freqRefRow("Wireless Cameras", "900–930 MHz", "-", "Surveillance")
                freqRefRow("Pagers", "929–931 MHz", "-", "Hospitals")
                freqRefRow("ISM 915", "902–928 MHz", "-", "LoRa/meters")
                freqRefRow("ADS-B", "1090 MHz", "AM", "Flight paths")
                freqRefRow("1.2 GHz Cameras", "1240–1300 MHz", "-", "Surveillance")
                freqRefRow("Hydrogen Line", "1420.4 MHz", "-", "Astronomy")
                freqRefRow("GPS L1", "1575.42 MHz", "-", "Jammer check")
                freqRefRow("Inmarsat", "1537–1545 MHz", "-", "Geostationary")
                freqRefRow("GOES LRIT", "1694.1 MHz", "-", "Geostationary")
            }
            .font(.caption)
        }
    }

    private var freqRefHeader: some View {
        GridRow {
            Text("Signal").fontWeight(.semibold)
                .frame(width: 110, alignment: .leading)
            Text("Frequency").fontWeight(.semibold)
                .frame(width: 130, alignment: .leading)
            Text("Demod").fontWeight(.semibold)
                .frame(width: 50, alignment: .leading)
            Text("When/Where").fontWeight(.semibold)
        }
        .foregroundStyle(.secondary)
    }

    private func freqRefRow(_ signal: String, _ freq: String, _ demod: String, _ when: String) -> some View {
        GridRow {
            Text(signal)
                .frame(width: 110, alignment: .leading)
            Text(freq)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.cyan)
                .frame(width: 130, alignment: .leading)
            Text(demod)
                .frame(width: 50, alignment: .leading)
            Text(when)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        Section("Tips") {
            VStack(alignment: .leading, spacing: 10) {
                tipRow("antenna.radiowaves.left.and.right",
                       "Antenna matters",
                       "The stock whip works for strong signals. A simple dipole cut to your target frequency dramatically improves reception.")

                tipRow("slider.horizontal.3",
                       "Gain tuning",
                       "Start with Auto. If signals clip (flat tops), reduce gain. If you can't see weak signals, try manual gain at higher levels.")

                tipRow("building.2",
                       "Location",
                       "Near a window or outdoors is much better than inside. RF is attenuated by walls, especially metal structures.")

                tipRow("waveform",
                       "Signal width = signal type",
                       "FM broadcast: ~200 kHz wide. Voice channels: 12.5–25 kHz. Digital bursts: often very narrow. Width tells you what you're looking at.")

                tipRow("chart.bar",
                       "Reading the spectrum",
                       "Y-axis is power in dB. Noise floor is typically -40 to -60 dB. Strong signals peak at -10 to 0 dB.")
            }
            .padding(.vertical, 4)
        }
    }

    private func tipRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section("Legal Notes") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("**Receiving is legal.** In the United States, it is legal to receive any radio signal under the Communications Act.")
                        .font(.callout)
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("**RTL-SDR is receive-only.** These devices cannot transmit. Transmitting on most frequencies requires an FCC license.")
                        .font(.callout)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Difficulty Badge

private struct DifficultyBadge: View {
    let level: SDRActivity.Difficulty

    var body: some View {
        Text(level.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch level {
        case .beginner: .green
        case .intermediate: .orange
        case .advanced: .red
        }
    }
}

// MARK: - Activity Data

struct SDRActivity: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let difficulty: Difficulty
    let demod: String
    let description: String
    let frequencies: [(label: String, value: String)]
    let howTo: [String]

    enum Difficulty: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }

    static let all: [SDRActivity] = [
        SDRActivity(
            name: "FM Radio",
            icon: "radio", color: .cyan,
            difficulty: .beginner, demod: "FM",
            description: "Listen to local FM stations. The wide ~200 kHz signals are easy to spot and always present.",
            frequencies: [
                (label: "FM Band", value: "88–108 MHz"),
            ],
            howTo: [
                "Select the \"FM Radio\" preset (100.000 MHz)",
                "Look for wide humps on the spectrum",
                "Click a detected signal and choose \"Listen (FM)\"",
                "Use 100 kHz steps to scan across the dial",
            ]
        ),
        SDRActivity(
            name: "NOAA Weather Radio",
            icon: "cloud.sun", color: .teal,
            difficulty: .beginner, demod: "FM",
            description: "24/7 continuous weather broadcasts. Strong, always-on signals great for testing your setup.",
            frequencies: [
                (label: "WX1", value: "162.550 MHz"),
                (label: "WX2", value: "162.400 MHz"),
                (label: "WX3", value: "162.475 MHz"),
                (label: "WX4", value: "162.425 MHz"),
                (label: "WX5", value: "162.450 MHz"),
            ],
            howTo: [
                "Select the \"NOAA Weather\" preset",
                "Zoom to 4x to see individual channels",
                "Click the signal and choose \"Listen (FM)\"",
                "You'll hear a synthesized voice reading local forecasts",
            ]
        ),
        SDRActivity(
            name: "Aircraft Communications",
            icon: "airplane", color: .blue,
            difficulty: .beginner, demod: "AM",
            description: "Hear pilots talking to air traffic control. Aviation uses AM modulation on VHF. Best within 30 miles of an airport.",
            frequencies: [
                (label: "Emergency/Guard", value: "121.500 MHz"),
                (label: "Air-to-air", value: "122.750 MHz"),
                (label: "Tower/Approach", value: "Varies by airport"),
            ],
            howTo: [
                "Tune near 120 MHz and set demod to AM",
                "Search online for your local airport's tower frequency",
                "Use 25 kHz steps to scan the 118–137 MHz band",
                "ATIS frequencies give continuous weather broadcasts",
            ]
        ),
        SDRActivity(
            name: "Marine VHF",
            icon: "ferry", color: .blue,
            difficulty: .beginner, demod: "FM",
            description: "Boat-to-boat and boat-to-shore communications. Active near any coast, lake, or major river.",
            frequencies: [
                (label: "Ch 16 (Distress)", value: "156.800 MHz"),
                (label: "Ch 9 (Calling)", value: "156.450 MHz"),
                (label: "Ch 13 (Bridge)", value: "156.650 MHz"),
                (label: "Ch 22A (USCG)", value: "157.100 MHz"),
            ],
            howTo: [
                "Select the \"Marine VHF\" preset (Ch 16)",
                "Scan with 25 kHz steps between 156–162 MHz",
                "Channel 16 is always monitored for distress",
                "Channel 13 near ports has bridge-to-bridge traffic",
            ]
        ),
        SDRActivity(
            name: "AIS Ship Tracking",
            icon: "ferry.fill", color: .mint,
            difficulty: .intermediate, demod: "FM (data)",
            description: "The maritime equivalent of ADS-B — ships broadcast identity, position, speed, and heading on two VHF data channels. Mandated for all large commercial vessels.",
            frequencies: [
                (label: "AIS 1", value: "161.975 MHz"),
                (label: "AIS 2", value: "162.025 MHz"),
            ],
            howTo: [
                "Tune to 161.975 MHz or 162.025 MHz",
                "You'll see periodic narrow bursts every few seconds",
                "Near busy ports, both channels are very active",
                "Use rtl_ais or similar to decode ship names and positions",
            ]
        ),
        SDRActivity(
            name: "Amateur (Ham) Radio",
            icon: "person.wave.2", color: .purple,
            difficulty: .beginner, demod: "FM",
            description: "Ham operators use FM repeaters for local communications. The 2-meter and 70-cm bands are most active.",
            frequencies: [
                (label: "2m calling freq", value: "146.520 MHz"),
                (label: "2m repeaters", value: "145.1–147.4 MHz"),
                (label: "70cm repeaters", value: "440–450 MHz"),
            ],
            howTo: [
                "Select the \"Amateur 2m\" preset",
                "Scan 145.1–147.4 MHz with 10 kHz steps",
                "Repeaters are the most active — listen for conversations",
                "146.520 MHz is the national simplex calling frequency",
            ]
        ),
        SDRActivity(
            name: "APRS Packet Radio",
            icon: "mappin.and.ellipse", color: .indigo,
            difficulty: .intermediate, demod: "FM (data)",
            description: "A digital ham radio network where stations broadcast GPS position, weather data, and short messages. A decentralized IoT mesh that's been running since the 1980s.",
            frequencies: [
                (label: "North America", value: "144.390 MHz"),
                (label: "Europe", value: "144.800 MHz"),
                (label: "ISS Digipeater", value: "145.825 MHz"),
            ],
            howTo: [
                "Tune to 144.390 MHz and set demod to FM",
                "You'll hear short harsh buzzing bursts (1200-baud AFSK)",
                "Transmissions are brief (< 1 second) spikes on the spectrum",
                "Use direwolf or multimon-ng to decode into position reports",
                "The ISS relays APRS on 145.825 MHz during passes",
            ]
        ),
        SDRActivity(
            name: "Railroad Communications",
            icon: "tram", color: .orange,
            difficulty: .beginner, demod: "FM",
            description: "Hear train dispatchers and crews coordinating on 97 AAR channels between 160.1 and 161.6 MHz.",
            frequencies: [
                (label: "Amtrak NE Corridor", value: "160.920 MHz"),
                (label: "AAR Band", value: "160.1–161.6 MHz"),
                (label: "EOT Devices", value: "457.9375 MHz"),
            ],
            howTo: [
                "Tune to 160.500 MHz near any rail line",
                "Scan with 15 kHz steps (AAR channel spacing)",
                "Listen for dispatchers issuing track warrants",
                "Near yards, you'll hear switching crews",
            ]
        ),
        SDRActivity(
            name: "FRS/GMRS Walkie-Talkies",
            icon: "walkie.talkie.radio", color: .green,
            difficulty: .beginner, demod: "FM",
            description: "Consumer walkie-talkies from sporting goods stores. Active at outdoor events, construction sites, and parks.",
            frequencies: [
                (label: "Channels 1–7", value: "462.5625–462.7125 MHz"),
                (label: "Channels 15–22", value: "462.550–462.725 MHz"),
            ],
            howTo: [
                "Select the \"FRS/GMRS\" preset",
                "Scan with 12.5 kHz steps",
                "Best near outdoor events and construction sites",
            ]
        ),
        SDRActivity(
            name: "Police/Fire Scanner",
            icon: "staroflife", color: .red,
            difficulty: .beginner, demod: "FM",
            description: "Many police, fire, and EMS agencies still use analog FM on VHF (150–174 MHz) and UHF (450–470 MHz). Trunked digital systems on 800 MHz show activity even if you can't decode voice.",
            frequencies: [
                (label: "VHF Public Safety", value: "150–174 MHz"),
                (label: "UHF Public Safety", value: "450–470 MHz"),
                (label: "Federal agencies", value: "162–174 MHz"),
            ],
            howTo: [
                "Select the \"Public Safety VHF\" preset (155.475 MHz)",
                "Scan with 12.5 kHz steps — channels are closely spaced",
                "Search radioreference.com for your local frequencies",
                "UHF (450–470 MHz) often carries more active channels",
                "Digital P25 sounds like harsh static — you'll see it on the spectrum but can't demod in-app",
            ]
        ),
        SDRActivity(
            name: "Trunked Radio (800 MHz)",
            icon: "antenna.radiowaves.left.and.right.circle", color: .red,
            difficulty: .intermediate, demod: "FM (digital)",
            description: "Many large police and fire departments use trunked systems on 851–869 MHz. These multiplex many talk groups onto shared frequencies. You'll see bursts of activity hopping across channels.",
            frequencies: [
                (label: "Trunked band", value: "851–869 MHz"),
                (label: "Control channels", value: "Varies by system"),
            ],
            howTo: [
                "Select the \"Trunked 800 MHz\" preset (860 MHz)",
                "Zoom to 2x to see the full 800 MHz band",
                "You'll see brief digital bursts jumping across frequencies",
                "Control channels are always-on — look for a persistent signal",
                "Decoding requires trunk-recorder or SDR Trunk software",
            ]
        ),
        SDRActivity(
            name: "MURS (Multi-Use Radio)",
            icon: "building.2.fill", color: .mint,
            difficulty: .beginner, demod: "FM",
            description: "Five license-free channels used by farms, businesses, security guards, and parking lots. Low power (2W) so signals are local. Hearing MURS activity tells you about nearby commercial operations.",
            frequencies: [
                (label: "MURS 1", value: "151.820 MHz"),
                (label: "MURS 2", value: "151.880 MHz"),
                (label: "MURS 3", value: "151.940 MHz"),
                (label: "MURS 4", value: "154.570 MHz"),
                (label: "MURS 5", value: "154.600 MHz"),
            ],
            howTo: [
                "Select the \"MURS\" preset (151.940 MHz)",
                "Check all five channels — they're spread across two sub-bands",
                "Common near retail stores (Walmart uses MURS), farms, and events",
            ]
        ),
        SDRActivity(
            name: "ISM Band Devices",
            icon: "sensor.fill", color: .yellow,
            difficulty: .intermediate, demod: "Various",
            description: "See digital bursts from weather stations, key fobs, garage door openers, TPMS sensors, IoT devices, and smart meters.",
            frequencies: [
                (label: "ISM 433 MHz", value: "433.05–434.79 MHz"),
                (label: "TPMS", value: "315 MHz / 433 MHz"),
                (label: "ISM 915 MHz", value: "902–928 MHz"),
            ],
            howTo: [
                "Select the \"ISM 433 MHz\" preset",
                "Zoom to 4x or 8x for detail",
                "Watch for periodic digital bursts (every 30–60 sec)",
                "Press your car key fob near the antenna to see its signal",
            ]
        ),
        SDRActivity(
            name: "Radiosondes (Weather Balloons)",
            icon: "wind", color: .cyan,
            difficulty: .intermediate, demod: "FM (data)",
            description: "The NWS launches weather balloons twice daily from ~90 stations. Each radiosonde transmits temperature, humidity, pressure, and GPS as it ascends to ~30 km.",
            frequencies: [
                (label: "US radiosondes", value: "400–406 MHz"),
                (label: "Vaisala RS41 (typical)", value: "402–405 MHz"),
            ],
            howTo: [
                "Tune to 403 MHz around launch time (~5:15 AM/PM local)",
                "Search for your nearest NWS upper-air station",
                "You'll see a continuous narrowband signal that drifts slightly",
                "Signal is receivable for 1–2 hours during ascent",
                "Use radiosonde_auto_rx to decode and track the flight path",
            ]
        ),
        SDRActivity(
            name: "ADS-B Aircraft Tracking",
            icon: "airplane.departure", color: .green,
            difficulty: .intermediate, demod: "AM",
            description: "Every commercial aircraft broadcasts position, altitude, speed, and callsign at 1090 MHz. You'll see rapid digital bursts.",
            frequencies: [
                (label: "ADS-B", value: "1090 MHz"),
            ],
            howTo: [
                "Select the \"Aircraft (ADS-B)\" preset",
                "Set gain to manual, fairly high (~40 dB)",
                "You'll see short digital spikes — these are aircraft transponders",
                "For full decoding (map view), use dedicated tools like dump1090",
            ]
        ),
        SDRActivity(
            name: "Pager Traffic",
            icon: "bell.badge", color: .pink,
            difficulty: .intermediate, demod: "FM",
            description: "Pagers are still used in hospitals and emergency services. The 929–931 MHz band carries POCSAG and FLEX digital pager messages.",
            frequencies: [
                (label: "Main pager band", value: "929–931 MHz"),
                (label: "VHF pagers", value: "152–158 MHz"),
            ],
            howTo: [
                "Tune to 929.000 MHz and scan upward in 25 kHz steps",
                "You'll hear rapid beeping/chirping (digital data)",
                "Note: pager traffic is unencrypted — a known privacy issue",
            ]
        ),
        SDRActivity(
            name: "Surveillance Sweep",
            icon: "video.fill", color: .red,
            difficulty: .intermediate, demod: "FM",
            description: "Detect analog wireless cameras that transmit on 900 MHz or 1.2 GHz. A persistent wideband signal in these bands in a hotel room, AirBnB, or private space could indicate a hidden camera.",
            frequencies: [
                (label: "900 MHz cameras", value: "900–930 MHz"),
                (label: "1.2 GHz cameras", value: "1240–1300 MHz"),
                (label: "Baby monitors", value: "900 MHz band"),
            ],
            howTo: [
                "Select the \"Surveillance 900\" preset (910 MHz)",
                "Look for persistent wideband signals (wider than 50 kHz)",
                "A wireless camera appears as a constant, wide hump",
                "Walk around the space — signal gets stronger near the camera",
                "Also check 1240–1300 MHz for 1.2 GHz cameras",
                "Digital/IP cameras use WiFi and won't appear here",
            ]
        ),
        SDRActivity(
            name: "Wireless Microphones",
            icon: "mic.fill", color: .indigo,
            difficulty: .intermediate, demod: "FM",
            description: "Wireless microphones operate in the 470–698 MHz band (former TV channels). Normal at events and venues — unexpected in a private setting.",
            frequencies: [
                (label: "Wireless mic band", value: "470–698 MHz"),
                (label: "Common range", value: "500–600 MHz"),
            ],
            howTo: [
                "Tune to 550 MHz and scan with 100 kHz steps",
                "Wireless mics appear as narrow FM signals",
                "Active ones carry continuous audio when in use",
                "Listen with FM demod to hear what's being picked up",
            ]
        ),
        SDRActivity(
            name: "GPS Jammer Detection",
            icon: "exclamationmark.triangle.fill", color: .red,
            difficulty: .intermediate, demod: "None (spectrum only)",
            description: "GPS signals at 1575.42 MHz are extremely weak (below noise floor). Any strong wideband signal at this frequency is anomalous and could indicate a GPS jammer nearby — used by vehicle thieves and to defeat tracking.",
            frequencies: [
                (label: "GPS L1", value: "1575.42 MHz"),
            ],
            howTo: [
                "Select the \"GPS L1\" preset",
                "Normal: you should see flat noise (GPS signals are too weak to see)",
                "Anomalous: a wideband hump or spike means local interference",
                "GPS jammers produce a characteristic wide noise dome",
                "Check near parking lots or if your phone GPS is acting up",
            ]
        ),
        SDRActivity(
            name: "Drone Detection",
            icon: "arrow.triangle.swap", color: .orange,
            difficulty: .advanced, demod: "Various",
            description: "Most consumer drones (DJI) use 2.4/5.8 GHz — out of RTL-SDR range. But some long-range systems (Crossfire, ExpressLRS) use 900 MHz, and telemetry links may appear at 433 MHz. Bursty digital signals in these bands near you could indicate a drone.",
            frequencies: [
                (label: "900 MHz control", value: "868–915 MHz"),
                (label: "433 MHz telemetry", value: "433 MHz ISM"),
                (label: "FPV analog video", value: "1.2–1.3 GHz"),
            ],
            howTo: [
                "Check ISM 915 and ISM 433 presets",
                "Drone links appear as periodic digital bursts",
                "900 MHz links are typically wider bandwidth than IoT devices",
                "1.2 GHz analog FPV video looks like a wide continuous signal",
                "Consumer DJI drones are NOT detectable with RTL-SDR",
            ]
        ),
        SDRActivity(
            name: "Satellites",
            icon: "cloud.sun.bolt", color: .teal,
            difficulty: .advanced, demod: "FM",
            description: "NOAA and Meteor weather satellites transmit images during overhead passes. Inmarsat and GOES are geostationary — no tracking needed, just point south.",
            frequencies: [
                (label: "NOAA-15", value: "137.620 MHz"),
                (label: "NOAA-18", value: "137.9125 MHz"),
                (label: "NOAA-19", value: "137.100 MHz"),
                (label: "ISS Voice", value: "145.800 MHz"),
                (label: "Inmarsat STD-C", value: "1537–1545 MHz"),
                (label: "GOES LRIT", value: "1694.1 MHz"),
            ],
            howTo: [
                "Check satellite pass times at n2yo.com",
                "Tune to the satellite's frequency before the pass",
                "NOAA APT sounds like rhythmic ticking — very distinctive",
                "Inmarsat is geostationary — point south, no tracking needed",
                "GOES LRIT (1694 MHz) is near the R820T's limit — needs dish + LNA",
                "An outdoor antenna with clear sky view is important",
            ]
        ),
        SDRActivity(
            name: "Hydrogen Line (Radio Astronomy)",
            icon: "sparkles", color: .purple,
            difficulty: .advanced, demod: "None (spectrum only)",
            description: "Detect hydrogen atoms in the Milky Way at 1420.405 MHz. Real radio astronomy — used to map our galaxy's spiral structure.",
            frequencies: [
                (label: "Hydrogen Line", value: "1420.405 MHz"),
            ],
            howTo: [
                "Requires: directional antenna + LNA + bandpass filter",
                "Tune to 1420.405 MHz with manual gain at maximum",
                "Point antenna at the galactic plane (Milky Way)",
                "Look for a slight bump above the noise floor",
                "Doppler shifts reveal the galaxy's rotation",
            ]
        ),
    ]
}
