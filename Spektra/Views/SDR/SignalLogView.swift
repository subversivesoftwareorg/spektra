import SwiftUI

struct SignalLogView: View {
    @Environment(RTLSDRDevice.self) private var sdr
    @Binding var selectedTab: Int
    @State private var sortOrder: SortOrder = .frequency
    @State private var sortAscending = true

    enum SortOrder: String, CaseIterable {
        case frequency = "Frequency"
        case power = "Power"
        case type = "Type"
        case lastSeen = "Last Seen"
        case hitCount = "Detections"
    }

    private var sortedLog: [RTLSDRDevice.SignalLogEntry] {
        let log = sdr.sessionSignalLog
        let sorted: [RTLSDRDevice.SignalLogEntry]
        switch sortOrder {
        case .frequency:
            sorted = log.sorted { $0.frequencyMHz < $1.frequencyMHz }
        case .power:
            sorted = log.sorted { $0.bestPowerDB > $1.bestPowerDB }
        case .type:
            sorted = log.sorted { $0.fingerprint.type.rawValue < $1.fingerprint.type.rawValue }
        case .lastSeen:
            sorted = log.sorted { $0.lastSeen > $1.lastSeen }
        case .hitCount:
            sorted = log.sorted { $0.hitCount > $1.hitCount }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    var body: some View {
        NavigationStack {
            Group {
                if sdr.sessionSignalLog.isEmpty {
                    emptyView
                } else {
                    logContentView
                }
            }
            .navigationTitle("Signal Log")
            .toolbar {
                if !sdr.sessionSignalLog.isEmpty {
                    ToolbarItem {
                        Button(role: .destructive) {
                            sdr.clearSignalLog()
                        } label: {
                            Label("Clear Log", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Signals Logged Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Signals detected during scans will appear here, even after they fade from the live view.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Log Content

    private var logContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                sortControlsSection
                signalTableSection
            }
            .padding()
        }
    }

    // MARK: - Sort Controls

    private var sortControlsSection: some View {
        GroupBox {
            HStack {
                Text("\(sdr.sessionSignalLog.count) signal\(sdr.sessionSignalLog.count == 1 ? "" : "s") logged")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Sort by")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                Button {
                    sortAscending.toggle()
                } label: {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                }
                .buttonStyle(.borderless)
                .help(sortAscending ? "Ascending" : "Descending")
            }
        }
    }

    // MARK: - Signal Table

    private var signalTableSection: some View {
        GroupBox {
            VStack(spacing: 0) {
                ForEach(Array(sortedLog.enumerated()), id: \.element.id) { index, entry in
                    SignalLogRow(entry: entry) {
                        sdr.centerFrequencyMHz = entry.frequencyMHz
                        if !sdr.isStreaming {
                            sdr.startStreaming()
                        }
                        selectedTab = 3
                    } onListen: {
                        let signal = DetectedSignal(
                            id: String(format: "%.4f", entry.frequencyMHz),
                            frequencyMHz: entry.frequencyMHz,
                            powerDB: entry.latestPowerDB,
                            fingerprint: entry.fingerprint
                        )
                        sdr.listenToSignal(signal)
                    }
                    if index < sortedLog.count - 1 {
                        Divider().padding(.vertical, 2)
                    }
                }
            }
        } label: {
            Text("Session Signals")
        }
    }
}

// MARK: - Signal Log Row

private struct SignalLogRow: View {
    let entry: RTLSDRDevice.SignalLogEntry
    let onTune: () -> Void
    let onListen: () -> Void

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.fingerprint.type.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.frequencyLabel)
                        .font(.system(.body, design: .monospaced, weight: .medium))

                    Text(entry.fingerprint.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(iconColor)

                    if let band = entry.bandName {
                        Text(band)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                    }

                    if entry.fingerprint.confidence >= 0.7 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 12) {
                    Text(entry.fingerprint.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f dB", entry.bestPowerDB))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(powerColor)

                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 8))
                    Text("\(entry.hitCount)x")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.timeFormatter.localizedString(for: entry.lastSeen, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("last seen")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 65)

            Button(action: onListen) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.green)
            .controlSize(.small)
            .help("Listen to this signal")

            Button(action: onTune) {
                Label("Tune", systemImage: "scope")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Tune to this frequency in the Expert Tuner")
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch entry.fingerprint.type {
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
        if entry.bestPowerDB > -10 { return .red }
        if entry.bestPowerDB > -25 { return .orange }
        return .secondary
    }
}
