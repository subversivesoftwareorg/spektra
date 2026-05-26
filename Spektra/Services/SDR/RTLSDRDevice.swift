import Foundation
import CRtlSdr
import Accelerate

// MARK: - Async callback (must be a free function for C interop)
private func sdrAsyncCallback(buf: UnsafeMutablePointer<UInt8>?, len: UInt32, ctx: UnsafeMutableRawPointer?) {
    guard let ctx = ctx, let buf = buf, len > 0 else { return }
    let device = Unmanaged<RTLSDRDevice>.fromOpaque(ctx).takeUnretainedValue()
    device.processBuffer(buf, length: Int(len))
}

@Observable
final class RTLSDRDevice: NSObject {

    // MARK: - Types

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)

        var label: String {
            switch self {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting..."
            case .connected: "Connected"
            case .error(let msg): "Error: \(msg)"
            }
        }
    }

    struct DeviceInfo {
        var name: String = ""
        var manufacturer: String = ""
        var product: String = ""
        var serial: String = ""
        var tunerType: String = ""
    }

    struct FrequencyPreset: Identifiable {
        let id = UUID()
        let name: String
        let frequency: UInt32
        let icon: String

        var label: String {
            let mhz = Double(frequency) / 1_000_000.0
            if mhz >= 1000 {
                return String(format: "%.1f GHz", mhz / 1000)
            }
            return String(format: "%.3f MHz", mhz)
        }
    }

    enum TuningStep: Double, CaseIterable, Identifiable {
        case khz1   = 1000
        case khz10  = 10000
        case khz25  = 25000
        case khz100 = 100000
        case mhz1   = 1000000

        var id: Double { rawValue }
        var label: String {
            switch self {
            case .khz1:   "1 kHz"
            case .khz10:  "10 kHz"
            case .khz25:  "25 kHz"
            case .khz100: "100 kHz"
            case .mhz1:   "1 MHz"
            }
        }
    }

    // MARK: - Published State

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var deviceCount: UInt32 = 0
    private(set) var deviceInfo = DeviceInfo()
    private(set) var isStreaming = false
    private(set) var spectrumData: [Float] = []
    private(set) var detectedSignals: [DetectedSignal] = []

    var centerFrequency: UInt32 = 100_000_000 {
        didSet {
            applyCenterFrequency()
            spectrumFrameCount = 0
        }
    }
    var sampleRate: UInt32 = 2_048_000 {
        didSet { applySampleRate() }
    }
    var isAutoGain: Bool = true {
        didSet { applyGainMode() }
    }
    var manualGainIndex: Int = 0 {
        didSet { applyGain() }
    }
    private(set) var availableGains: [Int32] = []

    // Tuning
    var tuningStep: TuningStep = .khz100

    // Zoom (1x, 2x, 4x, 8x)
    var zoomLevel: Double = 1.0

    // Audio
    let audioEngine = SDRAudioEngine()
    var listeningFrequencyMHz: Double?

    // Signal classifier
    private let signalClassifier = SignalClassifier()

    // MARK: - Presets

    static let presets: [FrequencyPreset] = [
        FrequencyPreset(name: "FM Radio", frequency: 100_000_000, icon: "radio"),
        FrequencyPreset(name: "Air Traffic Control", frequency: 121_500_000, icon: "tower.broadcast"),
        FrequencyPreset(name: "Amateur 2m", frequency: 146_000_000, icon: "person.wave.2"),
        FrequencyPreset(name: "MURS", frequency: 151_940_000, icon: "building.2.fill"),
        FrequencyPreset(name: "Public Safety VHF", frequency: 155_475_000, icon: "staroflife"),
        FrequencyPreset(name: "Marine VHF", frequency: 156_800_000, icon: "ferry"),
        FrequencyPreset(name: "Railroad", frequency: 160_500_000, icon: "tram"),
        FrequencyPreset(name: "NOAA Weather", frequency: 162_475_000, icon: "cloud.sun"),
        FrequencyPreset(name: "ISM 433 MHz", frequency: 433_920_000, icon: "sensor.fill"),
        FrequencyPreset(name: "Amateur 70cm", frequency: 440_000_000, icon: "person.wave.2"),
        FrequencyPreset(name: "FRS/GMRS", frequency: 462_562_500, icon: "walkie.talkie.radio"),
        FrequencyPreset(name: "Trunked 800 MHz", frequency: 860_000_000, icon: "antenna.radiowaves.left.and.right.circle"),
        FrequencyPreset(name: "ISM 915 MHz", frequency: 915_000_000, icon: "sensor.fill"),
        FrequencyPreset(name: "Surveillance 900", frequency: 910_000_000, icon: "video.fill"),
        FrequencyPreset(name: "Aircraft (ADS-B)", frequency: 1_090_000_000, icon: "airplane"),
        FrequencyPreset(name: "GPS L1", frequency: 1_575_420_000, icon: "location.circle"),
    ]

    // MARK: - Internals

    private var device: OpaquePointer?
    private var pollTimer: Timer?
    private var streamQueue = DispatchQueue(label: "com.spektra.sdr.stream", qos: .userInitiated)
    private var retainedSelf: Unmanaged<RTLSDRDevice>?

    private let fftSize = 2048
    private var fftSetup: FFTSetup?
    private var window: [Float] = []

    private var spectrumAccumulator: [Float] = []
    private var spectrumFrameCount: Int = 0

    // Track max power for squelch reference
    private var currentMaxPower: Float = -100

    // MARK: - Lifecycle

    override init() {
        super.init()
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        spectrumAccumulator = [Float](repeating: -100, count: fftSize)
    }

    deinit {
        stopPolling()
        stopStreaming()
        audioEngine.stop()
        // Close the device directly — don't call disconnect() which tries
        // to form [weak self] for a UI update, crashing during dealloc.
        if let dev = device {
            rtlsdr_close(dev)
        }
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Device Polling

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForDevices()
        }
        pollTimer?.tolerance = 0.5
        checkForDevices()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkForDevices() {
        let count = rtlsdr_get_device_count()
        let wasDisconnected = connectionState == .disconnected

        DispatchQueue.main.async { [weak self] in
            self?.deviceCount = count
        }

        if count > 0 && wasDisconnected {
            connect(deviceIndex: 0)
        } else if count == 0 && connectionState != .disconnected {
            handleDeviceRemoved()
        }
    }

    // MARK: - Connect / Disconnect

    func connect(deviceIndex: UInt32 = 0) {
        guard device == nil else { return }

        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .connecting
        }

        let name = String(cString: rtlsdr_get_device_name(deviceIndex))
        var manufBuf = [CChar](repeating: 0, count: 256)
        var prodBuf = [CChar](repeating: 0, count: 256)
        var serialBuf = [CChar](repeating: 0, count: 256)
        rtlsdr_get_device_usb_strings(deviceIndex, &manufBuf, &prodBuf, &serialBuf)

        var dev: OpaquePointer?
        let result = rtlsdr_open(&dev, deviceIndex)

        guard result == 0, let dev = dev else {
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("Failed to open device (code \(result))")
            }
            return
        }

        device = dev

        let tuner = rtlsdr_get_tuner_type(dev)
        let tunerName: String
        switch tuner.rawValue {
        case 1: tunerName = "E4000"
        case 2: tunerName = "FC0012"
        case 3: tunerName = "FC0013"
        case 4: tunerName = "FC2580"
        case 5: tunerName = "R820T"
        case 6: tunerName = "R828D"
        default: tunerName = "Unknown"
        }

        let gainCount = rtlsdr_get_tuner_gains(dev, nil)
        var gains = [Int32](repeating: 0, count: Int(gainCount))
        rtlsdr_get_tuner_gains(dev, &gains)

        rtlsdr_set_sample_rate(dev, sampleRate)
        rtlsdr_set_center_freq(dev, centerFrequency)
        rtlsdr_set_agc_mode(dev, 0)
        rtlsdr_set_tuner_gain_mode(dev, isAutoGain ? 0 : 1)
        if !isAutoGain && !gains.isEmpty {
            rtlsdr_set_tuner_gain(dev, gains[min(manualGainIndex, gains.count - 1)])
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.deviceInfo = DeviceInfo(
                name: name,
                manufacturer: String(cString: manufBuf),
                product: String(cString: prodBuf),
                serial: String(cString: serialBuf),
                tunerType: tunerName
            )
            self.availableGains = gains
            self.connectionState = .connected
        }
    }

    func disconnect() {
        stopStreaming()
        audioEngine.stop()
        if let dev = device {
            rtlsdr_close(dev)
            device = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
            self?.deviceInfo = DeviceInfo()
            self?.availableGains = []
            self?.spectrumData = []
            self?.detectedSignals = []
            self?.listeningFrequencyMHz = nil
        }
    }

    private func handleDeviceRemoved() {
        audioEngine.stop()
        if isStreaming {
            rtlsdr_cancel_async(device)
        }
        device = nil
        DispatchQueue.main.async { [weak self] in
            self?.isStreaming = false
            self?.connectionState = .disconnected
            self?.deviceInfo = DeviceInfo()
            self?.availableGains = []
            self?.spectrumData = []
            self?.detectedSignals = []
            self?.listeningFrequencyMHz = nil
        }
    }

    // MARK: - Apply Settings

    private func applyCenterFrequency() {
        guard let dev = device else { return }
        rtlsdr_set_center_freq(dev, centerFrequency)
    }

    private func applySampleRate() {
        guard let dev = device else { return }
        let wasStreaming = isStreaming
        if wasStreaming { stopStreaming() }
        rtlsdr_set_sample_rate(dev, sampleRate)
        if wasStreaming { startStreaming() }
    }

    private func applyGainMode() {
        guard let dev = device else { return }
        rtlsdr_set_tuner_gain_mode(dev, isAutoGain ? 0 : 1)
        if !isAutoGain { applyGain() }
    }

    private func applyGain() {
        guard let dev = device, !isAutoGain, !availableGains.isEmpty else { return }
        let index = min(manualGainIndex, availableGains.count - 1)
        rtlsdr_set_tuner_gain(dev, availableGains[index])
    }

    var currentGainDB: Double {
        guard !availableGains.isEmpty else { return 0 }
        let index = min(manualGainIndex, availableGains.count - 1)
        return Double(availableGains[index]) / 10.0
    }

    // MARK: - Tuning Helpers

    func tuneUp() {
        let step = UInt32(tuningStep.rawValue)
        if centerFrequency <= 1_766_000_000 - step {
            centerFrequency += step
        }
    }

    func tuneDown() {
        let step = UInt32(tuningStep.rawValue)
        if centerFrequency >= 24_000_000 + step {
            centerFrequency -= step
        }
    }

    func tuneToSignal(_ signal: DetectedSignal, mode: SDRAudioEngine.DemodMode? = nil) {
        centerFrequency = UInt32(signal.frequencyMHz * 1_000_000.0)
        if let mode {
            audioEngine.mode = mode
        }
    }

    func listenToSignal(_ signal: DetectedSignal) {
        tuneToSignal(signal, mode: signal.fingerprint.suggestedDemod)
        listeningFrequencyMHz = signal.frequencyMHz
        if !audioEngine.isPlaying {
            audioEngine.start()
        }
    }

    func stopListening() {
        audioEngine.stop()
        listeningFrequencyMHz = nil
    }

    // MARK: - Zoom Helpers

    var visibleSpectrum: [Float] {
        guard !spectrumData.isEmpty else { return [] }
        let total = spectrumData.count
        let visible = max(Int(Double(total) / zoomLevel), 4)
        let start = (total - visible) / 2
        return Array(spectrumData[start..<(start + visible)])
    }

    var visibleFrequencyRange: (low: Double, high: Double) {
        let center = centerFrequencyMHz
        let halfBW = sampleRateMHz / (2.0 * zoomLevel)
        return (center - halfBW, center + halfBW)
    }

    // MARK: - Streaming

    func startStreaming() {
        guard let dev = device, !isStreaming else { return }

        rtlsdr_reset_buffer(dev)
        spectrumAccumulator = [Float](repeating: -100, count: fftSize)
        spectrumFrameCount = 0

        DispatchQueue.main.async { [weak self] in
            self?.isStreaming = true
        }

        retainedSelf = Unmanaged.passRetained(self)
        let ctx = retainedSelf!.toOpaque()

        streamQueue.async {
            // Use 64KB buffers for good balance of FFT update rate and audio continuity
            rtlsdr_read_async(dev, sdrAsyncCallback, ctx, 0, 65536)
            self.retainedSelf?.release()
            self.retainedSelf = nil
            DispatchQueue.main.async { [weak self] in
                self?.isStreaming = false
            }
        }
    }

    func stopStreaming() {
        audioEngine.stop()
        listeningFrequencyMHz = nil
        guard isStreaming, let dev = device else { return }
        rtlsdr_cancel_async(dev)
    }

    func toggleStreaming() {
        if isStreaming { stopStreaming() } else { startStreaming() }
    }

    // MARK: - Sample Processing (called from C callback on stream thread)

    fileprivate func processBuffer(_ buf: UnsafeMutablePointer<UInt8>, length: Int) {
        guard let fftSetup = fftSetup else { return }

        let samplePairs = length / 2
        guard samplePairs >= fftSize else { return }

        // --- Audio: forward ALL IQ data to audio engine ---
        if audioEngine.isPlaying {
            audioEngine.processIQ(buf, length: length, signalPowerDB: currentMaxPower)
        }

        // --- Spectrum FFT: use the LAST fftSize IQ pairs for freshest data ---
        let fftOffset = (samplePairs - fftSize) * 2
        let fftBuf = buf.advanced(by: fftOffset)

        var realPart = [Float](repeating: 0, count: fftSize)
        var imagPart = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            realPart[i] = (Float(fftBuf[i * 2]) - 127.5) / 128.0
            imagPart[i] = (Float(fftBuf[i * 2 + 1]) - 127.5) / 128.0
        }

        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(fftSize))
        vDSP_vmul(imagPart, 1, window, 1, &imagPart, 1, vDSP_Length(fftSize))

        let log2n = vDSP_Length(log2(Float(fftSize)))
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        var magnitudes = [Float](repeating: 0, count: fftSize)
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftSize))
            }
        }

        var one: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &one, &magnitudes, 1, vDSP_Length(fftSize), 0)

        var floor: Float = -100
        vDSP_vthr(magnitudes, 1, &floor, &magnitudes, 1, vDSP_Length(fftSize))

        // FFT shift: DC to center
        var shifted = [Float](repeating: 0, count: fftSize)
        let half = fftSize / 2
        shifted[0..<half] = magnitudes[half..<fftSize]
        shifted[half..<fftSize] = magnitudes[0..<half]

        // Exponential moving average
        if spectrumFrameCount == 0 {
            spectrumAccumulator = shifted
        } else {
            var alpha: Float = 0.3
            var oneMinusAlpha: Float = 0.7
            var scaled = [Float](repeating: 0, count: fftSize)
            vDSP_vsmul(shifted, 1, &alpha, &scaled, 1, vDSP_Length(fftSize))
            var accScaled = [Float](repeating: 0, count: fftSize)
            vDSP_vsmul(spectrumAccumulator, 1, &oneMinusAlpha, &accScaled, 1, vDSP_Length(fftSize))
            vDSP_vadd(scaled, 1, accScaled, 1, &spectrumAccumulator, 1, vDSP_Length(fftSize))
        }
        spectrumFrameCount += 1

        // Track max power for squelch
        var maxPower: Float = -100
        vDSP_maxv(spectrumAccumulator, 1, &maxPower, vDSP_Length(fftSize))
        currentMaxPower = maxPower

        // --- Detect and classify peaks ---
        let sr = Double(sampleRate)
        let bwMHz = sr / 1_000_000.0
        let centerMHz = Double(centerFrequency) / 1_000_000.0
        var peaks: [(freqMHz: Double, powerDB: Float)] = []
        let threshold: Float = -30

        for i in 2..<(fftSize - 2) {
            let val = spectrumAccumulator[i]
            if val > threshold &&
               val > spectrumAccumulator[i-1] && val > spectrumAccumulator[i+1] &&
               val > spectrumAccumulator[i-2] && val > spectrumAccumulator[i+2] {
                let freqOffset = (Double(i) - Double(half)) / Double(fftSize) * sr
                let freqMHz = centerMHz + freqOffset / 1_000_000.0
                peaks.append((freqMHz: freqMHz, powerDB: val))
            }
        }
        peaks.sort { $0.powerDB > $1.powerDB }
        let topPeaks = Array(peaks.prefix(8))

        // Classify each peak
        let spectrum = spectrumAccumulator
        let signals = topPeaks.map { peak in
            let fp = signalClassifier.classify(
                peakFreqMHz: peak.freqMHz,
                spectrum: spectrum,
                centerFreqMHz: centerMHz,
                bandwidthMHz: bwMHz
            )
            return DetectedSignal(
                id: String(format: "%.4f", peak.freqMHz),
                frequencyMHz: peak.freqMHz,
                powerDB: peak.powerDB,
                fingerprint: fp
            )
        }

        let result = spectrumAccumulator
        DispatchQueue.main.async { [weak self] in
            self?.spectrumData = result
            self?.detectedSignals = signals
        }
    }

    // MARK: - Frequency Helpers

    var centerFrequencyMHz: Double {
        get { Double(centerFrequency) / 1_000_000.0 }
        set { centerFrequency = UInt32(newValue * 1_000_000.0) }
    }

    var sampleRateMHz: Double {
        Double(sampleRate) / 1_000_000.0
    }

    var frequencyRangeMHz: (low: Double, high: Double) {
        let center = centerFrequencyMHz
        let halfBW = sampleRateMHz / 2.0
        return (center - halfBW, center + halfBW)
    }
}
