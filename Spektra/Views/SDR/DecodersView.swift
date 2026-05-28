import SwiftUI
import AppKit

struct DecodersView: View {
    @Environment(RTLSDRDevice.self) private var sdr

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    decoderControlsSection
                    if sdr.adsbDecoder.isActive {
                        adsbSection
                    }
                    if sdr.pocsagDecoder.isActive {
                        pocsagSection
                    }
                    if !sdr.adsbDecoder.isActive && !sdr.pocsagDecoder.isActive {
                        emptySection
                    }
                }
                .padding()
            }
            .navigationTitle("Decoders")
        }
    }

    // MARK: - Decoder Controls

    private var decoderControlsSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                decoderToggle(
                    name: "ADS-B Aircraft",
                    icon: "airplane",
                    detail: "1090 MHz · Decodes aircraft position, callsign, altitude, velocity",
                    isActive: sdr.adsbDecoder.isActive,
                    color: .green
                ) {
                    toggleADSB()
                }

                Divider()

                decoderToggle(
                    name: "POCSAG Pager",
                    icon: "message.fill",
                    detail: "Tuned frequency · Decodes pager text and numeric messages",
                    isActive: sdr.pocsagDecoder.isActive,
                    color: .pink
                ) {
                    togglePOCSAG()
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Protocol Decoders")
        }
    }

    private func decoderToggle(name: String, icon: String, detail: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isActive ? color : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive && !sdr.isStreaming {
                Text("No stream")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Button {
                action()
            } label: {
                Text(isActive ? "Stop" : "Start")
                    .font(.caption.weight(.medium))
                    .frame(width: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .red : color)
            .controlSize(.small)
        }
    }

    private func toggleADSB() {
        if sdr.adsbDecoder.isActive {
            sdr.adsbDecoder.isActive = false
        } else {
            sdr.stopSweep()
            sdr.centerFrequency = 1_090_000_000
            if !sdr.isStreaming { sdr.startStreaming() }
            sdr.adsbDecoder.isActive = true
        }
    }

    private func togglePOCSAG() {
        if sdr.pocsagDecoder.isActive {
            sdr.pocsagDecoder.isActive = false
        } else {
            sdr.stopSweep()
            if !sdr.isStreaming { sdr.startStreaming() }
            sdr.pocsagDecoder.isActive = true
        }
    }

    // MARK: - Empty State

    private var emptySection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Decoders Active")
                .font(.callout.weight(.medium))
            Text("Start a decoder above to begin capturing protocol data from the radio spectrum.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - ADS-B Section

    private var adsbSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Label("\(sdr.adsbDecoder.aircraft.count) aircraft", systemImage: "airplane")
                        .font(.callout)

                    Spacer()

                    Text("\(sdr.adsbDecoder.messageCount) msgs")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if sdr.adsbDecoder.crcErrors > 0 {
                        Text("\(sdr.adsbDecoder.crcErrors) CRC err")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Button("Clear") {
                        sdr.adsbDecoder.clearAircraft()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                adsbCaptureControls

                if sdr.adsbDecoder.aircraft.isEmpty {
                    VStack(spacing: 4) {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Listening for aircraft on 1090 MHz...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        if sdr.adsbDecoder.preambleCount > 0 || sdr.adsbDecoder.crcErrors > 0 {
                            HStack(spacing: 12) {
                                Label("\(sdr.adsbDecoder.preambleCount) preambles", systemImage: "waveform.path")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if sdr.adsbDecoder.crcErrors > 0 {
                                    Label("\(sdr.adsbDecoder.crcErrors) CRC errors", systemImage: "exclamationmark.triangle")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    aircraftTable
                }
            }
        } label: {
            HStack {
                Text("ADS-B Aircraft")
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.green)
            }
        }
    }

    private var adsbCaptureControls: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: sdr.adsbDecoder.isCaptureActive ? "record.circle" : "circle.dashed")
                    .foregroundStyle(sdr.adsbDecoder.isCaptureActive ? .red : .secondary)
                    .symbolEffect(.pulse, isActive: sdr.adsbDecoder.isCaptureActive)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Raw IQ + Debug Capture")
                        .font(.caption.weight(.medium))
                    if sdr.adsbDecoder.isCaptureActive {
                        Text(String(format: "%.1f MB · %d candidate msgs", sdr.adsbDecoder.captureSizeMB, sdr.adsbDecoder.capturedMessages))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Save raw IQ and message-level debug log")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if sdr.adsbDecoder.isCaptureActive, let url = sdr.adsbDecoder.captureIQURL {
                    Button {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    } label: {
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Reveal in Finder")
                }

                Button {
                    if sdr.adsbDecoder.isCaptureActive {
                        sdr.adsbDecoder.stopCapture()
                    } else {
                        sdr.adsbDecoder.startCapture()
                    }
                } label: {
                    Text(sdr.adsbDecoder.isCaptureActive ? "Stop" : "Capture")
                        .font(.caption.weight(.medium))
                        .frame(width: 55)
                }
                .buttonStyle(.borderedProminent)
                .tint(sdr.adsbDecoder.isCaptureActive ? .red : .orange)
                .controlSize(.small)
            }
        }
    }

    private var aircraftTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("ICAO").frame(width: 65, alignment: .leading)
                Text("Callsign").frame(width: 80, alignment: .leading)
                Text("Altitude").frame(width: 85, alignment: .trailing)
                Text("Speed").frame(width: 60, alignment: .trailing)
                Text("Hdg").frame(width: 40, alignment: .trailing)
                Text("V/S").frame(width: 65, alignment: .trailing)
                Text("Position").frame(minWidth: 120, alignment: .leading).padding(.leading, 8)
                Spacer()
                Text("Msgs").frame(width: 40, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)

            Divider()

            ForEach(sdr.adsbDecoder.aircraft) { ac in
                HStack(spacing: 0) {
                    Text(ac.icaoHex)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 65, alignment: .leading)

                    Text(ac.callsign.isEmpty ? "---" : ac.callsign)
                        .font(.system(.caption, design: .monospaced, weight: ac.callsign.isEmpty ? .regular : .medium))
                        .foregroundStyle(ac.callsign.isEmpty ? .tertiary : .primary)
                        .frame(width: 80, alignment: .leading)

                    Text(ac.altitudeString)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 85, alignment: .trailing)

                    Text(ac.groundSpeed.map { "\($0) kt" } ?? "---")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 60, alignment: .trailing)

                    Text(ac.heading.map { "\($0)\u{00B0}" } ?? "---")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)

                    Text(ac.verticalRate.map { "\($0 > 0 ? "+" : "")\($0)" } ?? "---")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(verticalRateColor(ac.verticalRate))
                        .frame(width: 65, alignment: .trailing)

                    Text(ac.positionString)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 120, alignment: .leading)
                        .padding(.leading, 8)

                    Spacer()

                    Text("\(ac.messageCount)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 3)

                if ac.id != sdr.adsbDecoder.aircraft.last?.id {
                    Divider()
                }
            }
        }
    }

    private func verticalRateColor(_ vr: Int?) -> Color {
        guard let vr else { return .gray }
        if vr > 500 { return .green }
        if vr < -500 { return .orange }
        return .secondary
    }

    // MARK: - POCSAG Section

    private var pocsagSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Label("\(sdr.pocsagDecoder.messageCount) messages decoded", systemImage: "message.fill")
                        .font(.callout)

                    Spacer()

                    Text(String(format: "%.3f MHz", sdr.centerFrequencyMHz))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button("Clear") {
                        sdr.pocsagDecoder.clearMessages()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                if sdr.pocsagDecoder.messages.isEmpty {
                    VStack(spacing: 4) {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Listening for pager messages...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        if sdr.pocsagDecoder.syncCount > 0 {
                            HStack {
                                Label("\(sdr.pocsagDecoder.syncCount) sync words detected", systemImage: "waveform.path")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    pagerMessageList
                }
            }
        } label: {
            HStack {
                Text("POCSAG Pager Messages")
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.pink)
            }
        }
    }

    private var pagerMessageList: some View {
        VStack(spacing: 0) {
            ForEach(sdr.pocsagDecoder.messages) { msg in
                PagerMessageRow(message: msg)
                if msg.id != sdr.pocsagDecoder.messages.last?.id {
                    Divider().padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Pager Message Row

private struct PagerMessageRow: View {
    let message: POCSAGDecoder.PagerMessage

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.isNumeric ? "number" : "text.quote")
                .font(.caption)
                .foregroundStyle(message.isNumeric ? .orange : .pink)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(Self.timeFormatter.string(from: message.timestamp))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(String(format: "CAP%07d", message.address))
                        .font(.system(.caption, design: .monospaced, weight: .medium))

                    Text(message.isNumeric ? "Numeric" : "Alpha")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(message.isNumeric ? Color.orange.opacity(0.15) : Color.pink.opacity(0.15), in: Capsule())
                        .foregroundStyle(message.isNumeric ? .orange : .pink)
                }

                Text(message.content)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Compact Preview (for Expert Tuner)

struct DecoderPreviewSection: View {
    @Environment(RTLSDRDevice.self) private var sdr
    @Binding var selectedTab: Int

    var hasContent: Bool {
        (sdr.adsbDecoder.isActive && !sdr.adsbDecoder.aircraft.isEmpty) ||
        (sdr.pocsagDecoder.isActive && !sdr.pocsagDecoder.messages.isEmpty)
    }

    var body: some View {
        if sdr.adsbDecoder.isActive && !sdr.adsbDecoder.aircraft.isEmpty {
            adsbPreview
        }
        if sdr.pocsagDecoder.isActive && !sdr.pocsagDecoder.messages.isEmpty {
            pocsagPreview
        }
    }

    private var adsbPreview: some View {
        GroupBox {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundStyle(.green)
                    Text("\(sdr.adsbDecoder.aircraft.count) aircraft tracked")
                        .font(.callout)
                    Spacer()
                    Text("\(sdr.adsbDecoder.messageCount) msgs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    openDecodersButton
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

                if sdr.adsbDecoder.aircraft.count > 3 {
                    Text("+\(sdr.adsbDecoder.aircraft.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 2)
        } label: {
            HStack {
                Text("Decoded: ADS-B")
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.green)
            }
        }
    }

    private var pocsagPreview: some View {
        GroupBox {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.pink)
                    Text("\(sdr.pocsagDecoder.messageCount) pager messages")
                        .font(.callout)
                    Spacer()
                    openDecodersButton
                }

                ForEach(sdr.pocsagDecoder.messages.prefix(2)) { msg in
                    HStack(spacing: 6) {
                        Text(PagerTimeFormatter.string(from: msg.timestamp))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(msg.content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 2)
        } label: {
            HStack {
                Text("Decoded: POCSAG")
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.pink)
            }
        }
    }

    private var openDecodersButton: some View {
        Button {
            selectedTab = 4
        } label: {
            Label("Open", systemImage: "arrow.right.circle")
                .font(.caption2.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}

private let PagerTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()
