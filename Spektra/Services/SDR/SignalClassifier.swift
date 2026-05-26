import Foundation
import Accelerate

// MARK: - Signal Types

enum SignalType: String, CaseIterable {
    case fmBroadcast = "FM Broadcast"
    case narrowbandFM = "Narrowband FM"
    case amSignal = "AM Signal"
    case digital = "Digital"
    case pager = "Pager"
    case adsb = "ADS-B"
    case weatherRadio = "Weather Radio"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .fmBroadcast:  "radio"
        case .narrowbandFM: "walkie.talkie.radio"
        case .amSignal:     "antenna.radiowaves.left.and.right"
        case .digital:      "waveform.badge.exclamationmark"
        case .pager:        "bell.badge"
        case .adsb:         "airplane"
        case .weatherRadio: "cloud.sun"
        case .unknown:      "questionmark.circle"
        }
    }

    var suggestedDemod: SDRAudioEngine.DemodMode {
        switch self {
        case .fmBroadcast, .narrowbandFM, .weatherRadio, .pager: .fm
        case .amSignal, .adsb: .am
        case .digital, .unknown: .fm
        }
    }
}

// MARK: - Fingerprint

struct SignalFingerprint: Identifiable {
    let id = UUID()
    let type: SignalType
    let confidence: Double
    let description: String
    let bandwidthKHz: Double
    let suggestedDemod: SDRAudioEngine.DemodMode
}

// MARK: - Detected Signal

struct DetectedSignal: Identifiable {
    let id: String // stable identity from frequency
    let frequencyMHz: Double
    let powerDB: Float
    let fingerprint: SignalFingerprint

    var frequencyLabel: String {
        String(format: "%.4f MHz", frequencyMHz)
    }
}

// MARK: - Classifier

struct SignalClassifier {

    /// Classify a signal peak by analyzing the spectrum around it.
    func classify(
        peakFreqMHz: Double,
        spectrum: [Float],
        centerFreqMHz: Double,
        bandwidthMHz: Double
    ) -> SignalFingerprint {
        let fftSize = spectrum.count
        guard fftSize > 0 else {
            return unknown(bwKHz: 0)
        }

        let half = Double(fftSize) / 2.0
        let binOffset = (peakFreqMHz - centerFreqMHz) / bandwidthMHz * Double(fftSize)
        let peakBin = Int(half + binOffset)

        guard peakBin >= 2 && peakBin < fftSize - 2 else {
            return unknown(bwKHz: 0)
        }

        // Measure -6 dB bandwidth
        let peakPower = spectrum[peakBin]
        let threshold = peakPower - 6.0

        var leftBin = peakBin
        while leftBin > 0 && spectrum[leftBin] > threshold { leftBin -= 1 }
        var rightBin = peakBin
        while rightBin < fftSize - 1 && spectrum[rightBin] > threshold { rightBin += 1 }

        let signalBins = max(rightBin - leftBin, 1)
        let binWidthMHz = bandwidthMHz / Double(fftSize)
        let signalBWkHz = Double(signalBins) * binWidthMHz * 1000.0

        // Spectral flatness within the signal bandwidth
        let lo = max(0, leftBin)
        let hi = min(fftSize - 1, rightBin)
        let signalSlice = Array(spectrum[lo...hi])
        let flatness = spectralFlatness(signalSlice)

        return classifyByHeuristics(
            freqMHz: peakFreqMHz,
            bwKHz: signalBWkHz,
            flatness: flatness
        )
    }

    // MARK: - Internals

    private func spectralFlatness(_ data: [Float]) -> Double {
        guard data.count > 1 else { return 0 }
        let linear = data.map { powf(10, $0 / 20.0) + 1e-10 }
        let n = Float(linear.count)
        let arithmeticMean = linear.reduce(0, +) / n
        guard arithmeticMean > 0 else { return 0 }
        let logSum = linear.map { log($0) }.reduce(0, +)
        let geometricMean = exp(logSum / n)
        return min(Double(geometricMean / arithmeticMean), 1.0)
    }

    private func classifyByHeuristics(
        freqMHz: Double,
        bwKHz: Double,
        flatness: Double
    ) -> SignalFingerprint {

        // ADS-B (1090 MHz)
        if freqMHz > 1088 && freqMHz < 1092 {
            return SignalFingerprint(
                type: .adsb, confidence: 0.9,
                description: "Aircraft transponder beacon at 1090 MHz",
                bandwidthKHz: bwKHz, suggestedDemod: .am
            )
        }

        // NOAA Weather Radio (162.4-162.55 MHz)
        if freqMHz > 162.3 && freqMHz < 162.6 {
            return SignalFingerprint(
                type: .weatherRadio, confidence: 0.85,
                description: "NOAA Weather Radio broadcast",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // FM Broadcast (88-108 MHz, wide bandwidth)
        if freqMHz > 87.5 && freqMHz < 108.5 && bwKHz > 60 {
            return SignalFingerprint(
                type: .fmBroadcast, confidence: 0.9,
                description: "Commercial FM radio station",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Pager (152-158 MHz, narrow)
        if freqMHz > 150 && freqMHz < 160 && bwKHz < 30 {
            return SignalFingerprint(
                type: .pager, confidence: 0.6,
                description: "Pager or narrowband data signal",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // FRS/GMRS (462-467 MHz, narrowband)
        if freqMHz > 461 && freqMHz < 468 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.75,
                description: "FRS/GMRS two-way radio",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Marine VHF (156-162 MHz)
        if freqMHz > 155 && freqMHz < 163 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.7,
                description: "Marine VHF radio",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Amateur 2m (144-148 MHz)
        if freqMHz > 143 && freqMHz < 149 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.65,
                description: "Amateur radio 2-meter band",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Amateur 70cm (420-450 MHz)
        if freqMHz > 419 && freqMHz < 451 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.65,
                description: "Amateur radio 70-cm band",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Digital signal (flat-topped spectrum)
        if flatness > 0.55 && bwKHz > 5 {
            let conf = min(0.5 + flatness * 0.3, 0.85)
            return SignalFingerprint(
                type: .digital, confidence: conf,
                description: "Digital modulation (flat spectral shape)",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Generic narrowband FM
        if bwKHz > 8 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.5,
                description: "Narrowband FM voice or data",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // AM-like (narrow, peaked)
        if bwKHz > 3 && bwKHz < 20 && flatness < 0.3 {
            return SignalFingerprint(
                type: .amSignal, confidence: 0.5,
                description: "Amplitude-modulated signal",
                bandwidthKHz: bwKHz, suggestedDemod: .am
            )
        }

        return unknown(bwKHz: bwKHz)
    }

    private func unknown(bwKHz: Double) -> SignalFingerprint {
        SignalFingerprint(
            type: .unknown, confidence: 0.3,
            description: "Unclassified signal",
            bandwidthKHz: bwKHz, suggestedDemod: .fm
        )
    }
}
