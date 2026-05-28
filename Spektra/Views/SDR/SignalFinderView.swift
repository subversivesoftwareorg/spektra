import SwiftUI

struct SignalFinderView: View {
    @Environment(RTLSDRDevice.self) private var sdr

    var body: some View {
        NavigationStack {
            Group {
                switch sdr.connectionState {
                case .disconnected where sdr.deviceCount == 0:
                    noDeviceView
                default:
                    scanContentView
                }
            }
            .navigationTitle("Signal Finder")
        }
    }

    // MARK: - No Device

    private var noDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No SDR Device Detected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Plug in your RTL-SDR dongle to start finding signals.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scan Content

    private var scanContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                bandPickerSection
                if sdr.audioEngine.isPlaying {
                    listeningSection
                }
                if sdr.isSweeping {
                    scanProgressSection
                }
                if !sdr.sweepSignals.isEmpty || sdr.isSweeping {
                    signalListSection
                }
                if !sdr.isSweeping && sdr.sweepSignals.isEmpty && !sdr.audioEngine.isPlaying {
                    promptSection
                }
            }
            .padding()
        }
    }

    // MARK: - Band Picker

    private var bandPickerSection: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(RTLSDRDevice.scanBands) { band in
                    BandCard(band: band, isActive: sdr.sweepBand?.id == band.id && sdr.isSweeping) {
                        if sdr.isProtocolScanActive { return }
                        if sdr.isSweeping && sdr.sweepBand?.id == band.id {
                            sdr.stopSweep()
                        } else {
                            sdr.startSweep(band: band)
                        }
                    }
                    .disabled(sdr.isProtocolScanActive)
                }
            }
        } label: {
            HStack {
                Text("Select Band")
                Spacer()
                if sdr.isSweeping {
                    Button("Stop Scan") {
                        sdr.stopSweep()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
    }

    // MARK: - Listening

    private var listeningSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse)

                    VStack(alignment: .leading) {
                        Text(String(format: "%.4f MHz", sdr.listeningFrequencyMHz ?? sdr.centerFrequencyMHz))
                            .font(.system(.body, design: .monospaced, weight: .medium))
                        Text("Listening \u{00B7} \(sdr.audioEngine.mode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        sdr.stopListening()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Button {
                        sdr.audioEngine.isMuted.toggle()
                    } label: {
                        Image(systemName: sdr.audioEngine.isMuted ? "speaker.slash" : "speaker.wave.1")
                    }
                    .buttonStyle(.borderless)

                    Slider(
                        value: Binding(
                            get: { sdr.audioEngine.volume },
                            set: { sdr.audioEngine.volume = $0 }
                        ),
                        in: 0...1
                    )
                    .frame(maxWidth: 200)

                    AudioLevelView(level: sdr.audioEngine.audioLevel)
                        .frame(width: 60, height: 10)

                    Spacer()

                    if !sdr.isSweeping, let band = sdr.sweepBand {
                        Button {
                            sdr.stopListening()
                            sdr.startSweep(band: band)
                        } label: {
                            Label("Resume Scan", systemImage: "play.fill")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Now Playing")
        }
    }

    // MARK: - Scan Progress

    private var scanProgressSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse)
                    Text("Scanning \(sdr.sweepBand?.name ?? "")...")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.3f MHz", sdr.centerFrequencyMHz))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: sdr.sweepProgress)
                    .tint(.blue)

                if let band = sdr.sweepBand {
                    Text(band.rangeMHz)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Scan Progress")
        }
    }

    // MARK: - Signal List

    private var signalListSection: some View {
        let sorted = sdr.sweepSignals.sorted { $0.powerDB > $1.powerDB }
        return GroupBox {
            if sdr.sweepSignals.isEmpty && sdr.isSweeping {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for signals...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(sorted) { signal in
                        FoundSignalRow(signal: signal) {
                            sdr.stopSweep()
                            sdr.listenToSignal(signal)
                        }
                        if signal.id != sorted.last?.id {
                            Divider().padding(.vertical, 2)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Found Signals")
                if !sdr.sweepSignals.isEmpty {
                    Text("(\(sdr.sweepSignals.count))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Prompt

    private var promptSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Select a band above to start scanning")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("The Signal Finder will sweep across the band and show you where active signals are.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Band Card

struct BandCard: View {
    let band: RTLSDRDevice.ScanBand
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: band.icon)
                        .font(.title3)
                        .foregroundStyle(isActive ? .white : .blue)
                    Spacer()
                    if isActive {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Text(band.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isActive ? .white : .primary)

                Text(band.rangeMHz)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Color.blue : Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Found Signal Row

private struct FoundSignalRow: View {
    let signal: DetectedSignal
    let onListen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: signal.fingerprint.type.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(signal.frequencyLabel)
                        .font(.system(.body, design: .monospaced, weight: .medium))

                    Text(signal.fingerprint.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(iconColor)

                    if signal.fingerprint.confidence >= 0.7 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                Text(signal.fingerprint.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f dB", signal.powerDB))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(powerColor)

            Button(action: onListen) {
                Label("Listen", systemImage: "speaker.wave.2.fill")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch signal.fingerprint.type {
        case .fmBroadcast:       .cyan
        case .narrowbandFM:      .blue
        case .amSignal:          .orange
        case .digital:           .purple
        case .pager:             .pink
        case .adsb:              .green
        case .weatherRadio:      .teal
        case .airTrafficControl: .blue
        case .publicSafety:      .red
        case .railroad:          .orange
        case .trunkedRadio:      .red
        case .wirelessMic:       .indigo
        case .surveillance:      .red
        case .murs:              .mint
        case .gpsAnomaly:        .red
        case .unknown:           .secondary
        }
    }

    private var powerColor: Color {
        if signal.powerDB > -10 { return .red }
        if signal.powerDB > -25 { return .orange }
        return .secondary
    }
}
