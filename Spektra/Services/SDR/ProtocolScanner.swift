import Foundation

@Observable
final class ProtocolScanner {

    // MARK: - Types

    enum Phase: Equatable {
        case idle
        case scanning
        case dwelling(SignalType)
    }

    struct ProtocolActivity: Identifiable {
        let id = UUID()
        let timestamp: Date
        let frequencyMHz: Double
        let signalType: SignalType
        let dwellSeconds: Double
        let adsbAircraftCount: Int
        let adsbMessageCount: Int
        let pocsagMessages: [POCSAGDecoder.PagerMessage]
    }

    // MARK: - State

    private(set) var phase: Phase = .idle
    private(set) var activityLog: [ProtocolActivity] = []
    private(set) var currentBand: RTLSDRDevice.ScanBand?
    private(set) var sweepProgress: Double = 0
    private(set) var scanPassCount: Int = 0

    var isActive: Bool { phase != .idle }

    // MARK: - Internals

    private weak var sdr: RTLSDRDevice?
    private var sweepTimer: Timer?
    private var dwellTimer: Timer?
    private var sweepStepIndex: Int = 0
    private var dwellStartTime: Date?
    private var dwellFrequencyMHz: Double = 0
    private var dwellSignalType: SignalType = .unknown

    // Snapshot decoder state at dwell start to compute deltas
    private var adsbCountAtDwellStart: Int = 0
    private var pocsagCountAtDwellStart: Int = 0

    // Avoid re-dwelling on the same frequency within cooldown
    private var dwellCooldown: [String: Date] = [:]
    private let cooldownInterval: TimeInterval = 120
    private let dwellDuration: TimeInterval = 15

    private static let maxActivities = 200

    // MARK: - Public

    func startScan(band: RTLSDRDevice.ScanBand, sdr: RTLSDRDevice) {
        stopScan()

        self.sdr = sdr
        sdr.stopSweep()
        sdr.stopListening()
        sdr.isProtocolScanActive = true

        currentBand = band
        sweepStepIndex = 0
        sweepProgress = 0

        let steps = band.stepFrequencies
        guard !steps.isEmpty else { return }

        sdr.centerFrequency = steps[0]
        if !sdr.isStreaming { sdr.startStreaming() }

        phase = .scanning

        sweepTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.advanceScan()
        }
        sweepTimer?.tolerance = 0.05
    }

    func stopScan() {
        sweepTimer?.invalidate()
        sweepTimer = nil
        dwellTimer?.invalidate()
        dwellTimer = nil

        if let sdr {
            sdr.adsbDecoder.isActive = false
            sdr.pocsagDecoder.isActive = false
            sdr.isProtocolScanActive = false
        }

        phase = .idle
        currentBand = nil
    }

    func clearLog() {
        activityLog = []
    }

    // MARK: - Scan Engine

    private func advanceScan() {
        guard let sdr, let band = currentBand else { return }
        guard phase == .scanning else { return }
        guard sdr.connectionState == .connected else {
            stopScan()
            return
        }

        let steps = band.stepFrequencies
        guard !steps.isEmpty else { return }

        // Wait for enough FFT frames to get a stable spectrum
        guard sdr.spectrumFrameCount >= 8 else { return }

        // Check detected signals for decodable protocols
        if let target = findDecodableSignal(in: sdr.detectedSignals) {
            beginDwell(signal: target, sdr: sdr)
            return
        }

        // Advance to next step
        sweepStepIndex += 1
        if sweepStepIndex >= steps.count {
            sweepStepIndex = 0
            scanPassCount += 1
        }

        sweepProgress = Double(sweepStepIndex) / Double(steps.count)
        sdr.centerFrequency = steps[sweepStepIndex]
    }

    private func findDecodableSignal(in signals: [DetectedSignal]) -> DetectedSignal? {
        let now = Date()

        // Prune expired cooldowns
        dwellCooldown = dwellCooldown.filter { now.timeIntervalSince($0.value) < cooldownInterval }

        let candidates = signals.filter { signal in
            let type = signal.fingerprint.type
            guard type == .adsb || type == .pager else { return false }
            let key = String(format: "%.2f", signal.frequencyMHz)
            if let lastDwell = dwellCooldown[key], now.timeIntervalSince(lastDwell) < cooldownInterval {
                return false
            }
            return true
        }

        return candidates.max(by: { $0.powerDB < $1.powerDB })
    }

    // MARK: - Dwell

    private func beginDwell(signal: DetectedSignal, sdr: RTLSDRDevice) {
        let signalType = signal.fingerprint.type
        dwellFrequencyMHz = signal.frequencyMHz
        dwellSignalType = signalType
        dwellStartTime = Date()

        let key = String(format: "%.2f", signal.frequencyMHz)
        dwellCooldown[key] = Date()

        // Tune and activate the appropriate decoder
        if signalType == .adsb {
            sdr.centerFrequency = 1_090_000_000
            adsbCountAtDwellStart = sdr.adsbDecoder.messageCount
            sdr.adsbDecoder.isActive = true
        } else if signalType == .pager {
            sdr.centerFrequency = UInt32(signal.frequencyMHz * 1_000_000)
            pocsagCountAtDwellStart = sdr.pocsagDecoder.messages.count
            sdr.pocsagDecoder.isActive = true
        }

        phase = .dwelling(signalType)

        dwellTimer = Timer.scheduledTimer(withTimeInterval: dwellDuration, repeats: false) { [weak self] _ in
            self?.endDwell()
        }
        dwellTimer?.tolerance = 0.5
    }

    private func endDwell() {
        guard let sdr else {
            phase = .idle
            return
        }

        let elapsed = dwellStartTime.map { Date().timeIntervalSince($0) } ?? dwellDuration

        // Snapshot results
        var adsbCount = 0
        var adsbMsgCount = 0
        var pocsagMsgs: [POCSAGDecoder.PagerMessage] = []

        if dwellSignalType == .adsb {
            adsbCount = sdr.adsbDecoder.aircraft.count
            adsbMsgCount = sdr.adsbDecoder.messageCount - adsbCountAtDwellStart
            sdr.adsbDecoder.isActive = false
        } else if dwellSignalType == .pager {
            let newCount = sdr.pocsagDecoder.messages.count
            let delta = newCount - pocsagCountAtDwellStart
            if delta > 0 {
                pocsagMsgs = Array(sdr.pocsagDecoder.messages.prefix(delta))
            }
            sdr.pocsagDecoder.isActive = false
        }

        let activity = ProtocolActivity(
            timestamp: Date(),
            frequencyMHz: dwellFrequencyMHz,
            signalType: dwellSignalType,
            dwellSeconds: elapsed,
            adsbAircraftCount: adsbCount,
            adsbMessageCount: adsbMsgCount,
            pocsagMessages: pocsagMsgs
        )

        activityLog.insert(activity, at: 0)
        if activityLog.count > Self.maxActivities {
            activityLog.removeLast(activityLog.count - Self.maxActivities)
        }

        // Resume scanning
        guard let band = currentBand else {
            phase = .idle
            return
        }

        let steps = band.stepFrequencies
        sweepStepIndex += 1
        if sweepStepIndex >= steps.count {
            sweepStepIndex = 0
            scanPassCount += 1
        }

        if !steps.isEmpty {
            sweepProgress = Double(sweepStepIndex) / Double(steps.count)
            sdr.centerFrequency = steps[sweepStepIndex]
        }

        phase = .scanning
    }
}
