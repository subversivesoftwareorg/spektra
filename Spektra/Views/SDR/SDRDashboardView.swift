import SwiftUI

struct SDRDashboardView: View {
    @Environment(RTLSDRDevice.self) private var sdr
    @State private var showHelp = false

    var body: some View {
        @Bindable var sdr = sdr
        NavigationStack {
            Group {
                switch sdr.connectionState {
                case .disconnected where sdr.deviceCount == 0:
                    disconnectedView
                default:
                    connectedContentView
                }
            }
            .navigationTitle("Software Defined Radio")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showHelp = true
                    } label: {
                        Label("SDR Guide", systemImage: "questionmark.circle")
                    }
                }
            }
        }
        .onAppear { sdr.startPolling() }
        .onDisappear { sdr.stopPolling() }
        .sheet(isPresented: $showHelp) {
            SDRHelpView()
        }
    }

    // MARK: - Disconnected

    @State private var showGetSDR = false

    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No SDR Device Detected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Plug in your RTL-SDR dongle to get started.\nSupported chipsets: RTL2832U with R820T/R828D/E4000 tuners.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Divider().frame(maxWidth: 300).padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("NooElec NESDR Mini/Smart", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("Generic RTL-SDR V3/V4", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("Any RTL2832U-based dongle", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .font(.callout)

            Button {
                showGetSDR = true
            } label: {
                Label("How to Get an SDR", systemImage: "cart")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Text("Requires librtlsdr: `brew install librtlsdr`")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showGetSDR) {
            GetSDRView()
        }
    }

    // MARK: - Connected Content

    private var connectedContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                deviceStatusSection
                tuningSection
                if sdr.connectionState == .connected {
                    audioSection
                }
                if !sdr.spectrumData.isEmpty {
                    spectrumSection
                }
                if !sdr.detectedSignals.isEmpty {
                    signalsSection
                }
            }
            .padding()
        }
    }

    // MARK: - Device Status

    private var deviceStatusSection: some View {
        GroupBox {
            HStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(sdr.deviceInfo.name.isEmpty ? "RTL-SDR" : sdr.deviceInfo.name)
                            .font(.headline)
                        Spacer()
                        statusBadge
                    }
                    if sdr.connectionState == .connected {
                        HStack(spacing: 16) {
                            if !sdr.deviceInfo.tunerType.isEmpty {
                                Label(sdr.deviceInfo.tunerType, systemImage: "cpu")
                            }
                            if !sdr.deviceInfo.serial.isEmpty {
                                Label(sdr.deviceInfo.serial, systemImage: "number")
                            }
                            if !sdr.deviceInfo.manufacturer.isEmpty {
                                Label(sdr.deviceInfo.manufacturer, systemImage: "building.2")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Device")
        }
    }

    private var statusColor: Color {
        switch sdr.connectionState {
        case .connected: .green
        case .connecting: .orange
        case .error: .red
        case .disconnected: .secondary
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(sdr.connectionState.label)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.1), in: Capsule())
    }

    // MARK: - Tuning & Controls

    private var tuningSection: some View {
        @Bindable var sdr = sdr
        return GroupBox {
            VStack(spacing: 12) {
                // Frequency + presets
                HStack {
                    Label("Frequency", systemImage: "waveform")
                        .frame(width: 100, alignment: .leading)
                    TextField("MHz", value: $sdr.centerFrequencyMHz, format: .number.precision(.fractionLength(3)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("MHz")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(RTLSDRDevice.presets) { preset in
                            Button {
                                sdr.centerFrequency = preset.frequency
                            } label: {
                                Label("\(preset.name) (\(preset.label))", systemImage: preset.icon)
                            }
                        }
                    } label: {
                        Label("Presets", systemImage: "list.bullet")
                            .font(.callout)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 90)
                }

                // Step tuning
                HStack {
                    Label("Step", systemImage: "ruler")
                        .frame(width: 100, alignment: .leading)

                    Picker("", selection: $sdr.tuningStep) {
                        ForEach(RTLSDRDevice.TuningStep.allCases) { step in
                            Text(step.label).tag(step)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    Spacer()

                    HStack(spacing: 4) {
                        Button { sdr.tuneDown() } label: {
                            Image(systemName: "chevron.left")
                        }
                        .controlSize(.small)

                        Button { sdr.tuneUp() } label: {
                            Image(systemName: "chevron.right")
                        }
                        .controlSize(.small)
                    }
                }

                Divider()

                // Gain
                HStack {
                    Label("Gain", systemImage: "slider.horizontal.3")
                        .frame(width: 100, alignment: .leading)

                    Picker("", selection: $sdr.isAutoGain) {
                        Text("Auto").tag(true)
                        Text("Manual").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    if !sdr.isAutoGain && !sdr.availableGains.isEmpty {
                        Slider(
                            value: Binding(
                                get: { Double(sdr.manualGainIndex) },
                                set: { sdr.manualGainIndex = Int($0) }
                            ),
                            in: 0...Double(max(sdr.availableGains.count - 1, 1)),
                            step: 1
                        )
                        Text(String(format: "%.1f dB", sdr.currentGainDB))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                    Spacer()
                }

                Divider()

                // Stream controls
                HStack {
                    Label("Bandwidth", systemImage: "arrow.left.and.right")
                        .frame(width: 100, alignment: .leading)
                    Text(String(format: "%.3f MHz", sdr.sampleRateMHz))
                        .foregroundStyle(.secondary)
                    Spacer()

                    Button {
                        sdr.toggleStreaming()
                    } label: {
                        Label(
                            sdr.isStreaming ? "Stop" : "Start Scanning",
                            systemImage: sdr.isStreaming ? "stop.fill" : "play.fill"
                        )
                        .font(.callout.weight(.medium))
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(sdr.isStreaming ? .red : .blue)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Tuning")
        }
    }

    // MARK: - Audio Controls

    private var audioSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack {
                    Label("Demod", systemImage: "waveform.path")
                        .frame(width: 100, alignment: .leading)

                    Picker("", selection: Binding(
                        get: { sdr.audioEngine.mode },
                        set: { sdr.audioEngine.mode = $0 }
                    )) {
                        ForEach(SDRAudioEngine.DemodMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)

                    Spacer()

                    Button {
                        if sdr.audioEngine.isPlaying {
                            sdr.stopListening()
                        } else if sdr.isStreaming {
                            sdr.audioEngine.start()
                            sdr.listeningFrequencyMHz = sdr.centerFrequencyMHz
                        }
                    } label: {
                        Label(
                            sdr.audioEngine.isPlaying ? "Stop Audio" : "Listen",
                            systemImage: sdr.audioEngine.isPlaying ? "speaker.slash.fill" : "speaker.wave.2.fill"
                        )
                        .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sdr.audioEngine.isPlaying ? .orange : .green)
                    .disabled(!sdr.isStreaming)
                }

                HStack {
                    Label("Volume", systemImage: sdr.audioEngine.isMuted ? "speaker.slash" : "speaker.wave.2")
                        .frame(width: 100, alignment: .leading)

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

                    Text(String(format: "%d%%", Int(sdr.audioEngine.volume * 100)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)

                    Spacer()

                    // Audio level meter
                    if sdr.audioEngine.isPlaying {
                        AudioLevelView(level: sdr.audioEngine.audioLevel)
                            .frame(width: 80, height: 12)
                    }
                }

                HStack {
                    Label("Squelch", systemImage: "minus.circle")
                        .frame(width: 100, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { sdr.audioEngine.squelchLevel },
                            set: { sdr.audioEngine.squelchLevel = $0 }
                        ),
                        in: -80...0
                    )
                    .frame(maxWidth: 200)

                    Text(String(format: "%.0f dB", sdr.audioEngine.squelchLevel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .trailing)

                    Spacer()
                }

                if let freq = sdr.listeningFrequencyMHz, sdr.audioEngine.isPlaying {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundStyle(.green)
                        Text("Listening at \(String(format: "%.3f MHz", freq)) (\(sdr.audioEngine.mode.rawValue))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Audio")
        }
    }

    // MARK: - Spectrum

    private var spectrumSection: some View {
        @Bindable var sdr = sdr
        let range = sdr.visibleFrequencyRange
        return GroupBox {
            VStack(spacing: 8) {
                // Zoom controls
                HStack {
                    Text(String(format: "%.3f MHz", range.low))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.3f MHz", sdr.centerFrequencyMHz))
                        .font(.caption2.weight(.medium))
                    Spacer()
                    Text(String(format: "%.3f MHz", range.high))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                SpectrumView(data: sdr.visibleSpectrum)
                    .frame(height: 250)

                HStack {
                    Text("Zoom")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $sdr.zoomLevel) {
                        Text("1x").tag(1.0)
                        Text("2x").tag(2.0)
                        Text("4x").tag(4.0)
                        Text("8x").tag(8.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    Spacer()

                    Text(String(format: "Visible: %.0f kHz", sdr.sampleRateMHz * 1000.0 / sdr.zoomLevel))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Spectrum")
        }
    }

    // MARK: - Detected Signals

    private var signalsSection: some View {
        GroupBox {
            VStack(spacing: 0) {
                ForEach(sdr.detectedSignals) { signal in
                    SignalRow(signal: signal, sdr: sdr)
                    if signal.id != sdr.detectedSignals.last?.id {
                        Divider().padding(.vertical, 2)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Active Signals")
        }
    }
}

// MARK: - Signal Row

private struct SignalRow: View {
    let signal: DetectedSignal
    let sdr: RTLSDRDevice

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

                HStack(spacing: 12) {
                    Text(signal.fingerprint.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if signal.fingerprint.bandwidthKHz > 0 {
                        Text(String(format: "BW: %.0f kHz", signal.fingerprint.bandwidthKHz))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(String(format: "%.1f dB", signal.powerDB))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(powerColor)

            // Action menu
            Menu {
                Button {
                    sdr.tuneToSignal(signal)
                } label: {
                    Label("Tune to \(signal.frequencyLabel)", systemImage: "scope")
                }

                Divider()

                Button {
                    sdr.listenToSignal(signal)
                } label: {
                    Label("Listen (\(signal.fingerprint.suggestedDemod.rawValue))", systemImage: "speaker.wave.2")
                }

                ForEach(SDRAudioEngine.DemodMode.allCases.filter { $0 != signal.fingerprint.suggestedDemod }) { mode in
                    Button {
                        sdr.tuneToSignal(signal, mode: mode)
                        if !sdr.audioEngine.isPlaying { sdr.audioEngine.start() }
                        sdr.listeningFrequencyMHz = signal.frequencyMHz
                    } label: {
                        Label("Listen (\(mode.rawValue))", systemImage: "speaker.wave.1")
                    }
                }

                if sdr.audioEngine.isPlaying {
                    Divider()
                    Button {
                        sdr.stopListening()
                    } label: {
                        Label("Stop Audio", systemImage: "speaker.slash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch signal.fingerprint.type {
        case .fmBroadcast:        .cyan
        case .narrowbandFM:       .blue
        case .amSignal:           .orange
        case .digital:            .purple
        case .pager:              .pink
        case .adsb:               .green
        case .weatherRadio:       .teal
        case .airTrafficControl:  .blue
        case .publicSafety:       .red
        case .railroad:           .orange
        case .trunkedRadio:       .red
        case .wirelessMic:        .indigo
        case .surveillance:       .red
        case .murs:               .mint
        case .gpsAnomaly:         .red
        case .unknown:            .secondary
        }
    }

    private var powerColor: Color {
        if signal.powerDB > -10 { return .red }
        if signal.powerDB > -25 { return .orange }
        return .secondary
    }
}

// MARK: - Audio Level Meter

struct AudioLevelView: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 3)
                    .fill(levelGradient)
                    .frame(width: max(0, geo.size.width * CGFloat(level)))
            }
        }
    }

    private var levelGradient: some ShapeStyle {
        if level > 0.8 { return AnyShapeStyle(Color.red) }
        if level > 0.5 { return AnyShapeStyle(Color.orange) }
        return AnyShapeStyle(Color.green)
    }
}

// MARK: - Spectrum Canvas

struct SpectrumView: View {
    let data: [Float]

    var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }

            let height = size.height
            let dbMin: Float = -80
            let dbMax: Float = 10

            drawGrid(context: context, size: size, dbMin: dbMin, dbMax: dbMax)

            // Fill
            let fillPath = buildPath(in: size, dbMin: dbMin, dbMax: dbMax, closed: true)
            let gradient = Gradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.05)])
            context.fill(fillPath, with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))

            // Line
            let linePath = buildPath(in: size, dbMin: dbMin, dbMax: dbMax, closed: false)
            context.stroke(linePath, with: .color(.cyan), lineWidth: 1.5)
        }
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func buildPath(in size: CGSize, dbMin: Float, dbMax: Float, closed: Bool) -> Path {
        let width = size.width
        let height = size.height
        let count = data.count
        let step = width / CGFloat(count - 1)
        let dbRange = dbMax - dbMin

        var path = Path()
        if closed { path.move(to: CGPoint(x: 0, y: height)) }

        for i in 0..<count {
            let x = CGFloat(i) * step
            let clamped = max(dbMin, min(dbMax, data[i]))
            let normalized = CGFloat((clamped - dbMin) / dbRange)
            let y = height * (1.0 - normalized)

            if i == 0 && !closed {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        if closed {
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
        return path
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, dbMin: Float, dbMax: Float) {
        let dbRange = dbMax - dbMin

        let dbSteps: [Float] = [-60, -40, -20, 0]
        for db in dbSteps {
            let normalized = CGFloat((db - dbMin) / dbRange)
            let y = size.height * (1.0 - normalized)

            var linePath = Path()
            linePath.move(to: CGPoint(x: 0, y: y))
            linePath.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(linePath, with: .color(.white.opacity(0.1)), lineWidth: 0.5)

            context.draw(
                Text("\(Int(db)) dB").font(.system(size: 9)).foregroundColor(.white.opacity(0.3)),
                at: CGPoint(x: 30, y: y - 8),
                anchor: .leading
            )
        }

        // Center line
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: size.width / 2, y: 0))
        centerLine.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        context.stroke(centerLine, with: .color(.white.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

        // Quarter lines
        for frac in [0.25, 0.75] {
            var line = Path()
            line.move(to: CGPoint(x: size.width * frac, y: 0))
            line.addLine(to: CGPoint(x: size.width * frac, y: size.height))
            context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
        }
    }
}
