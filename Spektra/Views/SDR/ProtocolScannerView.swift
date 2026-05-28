import SwiftUI

struct ProtocolScannerView: View {
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
            .navigationTitle("Protocol Scanner")
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

            Text("Plug in your RTL-SDR dongle to scan for decodable protocols.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var scanContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                bandPickerSection
                if sdr.protocolScanner.isActive {
                    statusSection
                }
                if case .dwelling = sdr.protocolScanner.phase {
                    dwellPreviewSection
                }
                if !sdr.protocolScanner.activityLog.isEmpty {
                    activityLogSection
                }
                if !sdr.protocolScanner.isActive && sdr.protocolScanner.activityLog.isEmpty {
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
                    BandCard(
                        band: band,
                        isActive: sdr.protocolScanner.currentBand?.id == band.id && sdr.protocolScanner.isActive
                    ) {
                        if sdr.protocolScanner.isActive && sdr.protocolScanner.currentBand?.id == band.id {
                            sdr.protocolScanner.stopScan()
                        } else {
                            sdr.protocolScanner.startScan(band: band, sdr: sdr)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Select Band")
                Spacer()
                if sdr.protocolScanner.isActive {
                    Button("Stop") {
                        sdr.protocolScanner.stopScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    phaseIndicator
                    Spacer()
                    Text(String(format: "%.3f MHz", sdr.centerFrequencyMHz))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: sdr.protocolScanner.sweepProgress)
                    .tint(dwellTint)

                HStack {
                    if let band = sdr.protocolScanner.currentBand {
                        Text(band.rangeMHz)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("Pass \(sdr.protocolScanner.scanPassCount + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Scan Status")
        }
    }

    @ViewBuilder
    private var phaseIndicator: some View {
        switch sdr.protocolScanner.phase {
        case .scanning:
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                Text("Sweeping for protocols...")
                    .font(.headline)
            }
        case .dwelling(let type):
            HStack(spacing: 6) {
                Image(systemName: type == .adsb ? "airplane" : "message.fill")
                    .foregroundStyle(type == .adsb ? .green : .pink)
                    .symbolEffect(.pulse)
                Text("Decoding \(type.rawValue)...")
                    .font(.headline)
            }
        case .idle:
            EmptyView()
        }
    }

    private var dwellTint: Color {
        if case .dwelling(let type) = sdr.protocolScanner.phase {
            return type == .adsb ? .green : .pink
        }
        return .blue
    }

    // MARK: - Dwell Preview

    private var dwellPreviewSection: some View {
        GroupBox {
            VStack(spacing: 6) {
                if case .dwelling(let type) = sdr.protocolScanner.phase {
                    if type == .adsb {
                        HStack {
                            Image(systemName: "airplane")
                                .foregroundStyle(.green)
                            Text("\(sdr.adsbDecoder.aircraft.count) aircraft")
                                .font(.callout)
                            Spacer()
                            Text("\(sdr.adsbDecoder.messageCount) msgs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if sdr.adsbDecoder.preambleCount > 0 {
                                Text("\(sdr.adsbDecoder.preambleCount) preambles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sdr.adsbDecoder.aircraft.prefix(3)) { ac in
                            HStack(spacing: 8) {
                                Text(ac.icaoHex)
                                    .font(.system(.caption, design: .monospaced))
                                Text(ac.callsign.isEmpty ? "---" : ac.callsign)
                                    .font(.system(.caption, design: .monospaced, weight: .medium))
                                    .frame(width: 70, alignment: .leading)
                                Text(ac.altitudeString)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                        }
                    } else if type == .pager {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundStyle(.pink)
                            Text("\(sdr.pocsagDecoder.messageCount) pager messages")
                                .font(.callout)
                            Spacer()
                            if sdr.pocsagDecoder.syncCount > 0 {
                                Text("\(sdr.pocsagDecoder.syncCount) syncs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(sdr.pocsagDecoder.messages.prefix(2)) { msg in
                            HStack(spacing: 6) {
                                Text(msg.content)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        } label: {
            HStack {
                Text("Live Decode")
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(dwellTint)
            }
        }
    }

    // MARK: - Activity Log

    private var activityLogSection: some View {
        GroupBox {
            VStack(spacing: 0) {
                ForEach(sdr.protocolScanner.activityLog) { activity in
                    ActivityRow(activity: activity)
                    if activity.id != sdr.protocolScanner.activityLog.last?.id {
                        Divider().padding(.vertical, 2)
                    }
                }
            }
        } label: {
            HStack {
                Text("Decoded Activity (\(sdr.protocolScanner.activityLog.count))")
                Spacer()
                Button("Clear") {
                    sdr.protocolScanner.clearLog()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }

    // MARK: - Prompt

    private var promptSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Protocol Scanner")
                .font(.callout.weight(.medium))
            Text("Select a band to sweep. When a decodable signal is found (ADS-B or pager), the scanner will automatically dwell and decode it before resuming the sweep.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let activity: ProtocolScanner.ProtocolActivity

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: activity.signalType.icon)
                .font(.caption)
                .foregroundStyle(activity.signalType == .adsb ? .green : .pink)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(Self.timeFormatter.string(from: activity.timestamp))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.4f MHz", activity.frequencyMHz))
                        .font(.system(.caption, design: .monospaced, weight: .medium))

                    Text(activity.signalType.rawValue)
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            (activity.signalType == .adsb ? Color.green : Color.pink).opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(activity.signalType == .adsb ? .green : .pink)

                    Text(String(format: "%.0fs dwell", activity.dwellSeconds))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if activity.signalType == .adsb {
                    Text("\(activity.adsbAircraftCount) aircraft, \(activity.adsbMessageCount) messages decoded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !activity.pocsagMessages.isEmpty {
                    ForEach(activity.pocsagMessages.prefix(3)) { msg in
                        Text(msg.content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if activity.pocsagMessages.count > 3 {
                        Text("+\(activity.pocsagMessages.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("No messages decoded during dwell")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
