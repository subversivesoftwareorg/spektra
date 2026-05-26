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
    case airTrafficControl = "Air Traffic Control"
    case publicSafety = "Public Safety"
    case railroad = "Railroad"
    case trunkedRadio = "Trunked Radio"
    case wirelessMic = "Wireless Mic"
    case surveillance = "Surveillance"
    case murs = "MURS"
    case gpsAnomaly = "GPS Anomaly"
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
        case .airTrafficControl: "tower.broadcast"
        case .publicSafety: "staroflife"
        case .railroad:     "tram"
        case .trunkedRadio: "antenna.radiowaves.left.and.right.circle"
        case .wirelessMic:  "mic.fill"
        case .surveillance: "video.fill"
        case .murs:         "building.2.fill"
        case .gpsAnomaly:   "exclamationmark.triangle.fill"
        case .unknown:      "questionmark.circle"
        }
    }

    var suggestedDemod: SDRAudioEngine.DemodMode {
        switch self {
        case .fmBroadcast, .narrowbandFM, .weatherRadio, .pager,
             .publicSafety, .railroad, .trunkedRadio, .wirelessMic,
             .murs, .surveillance: .fm
        case .amSignal, .adsb, .airTrafficControl: .am
        case .digital, .gpsAnomaly, .unknown: .fm
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
    let id: String
    let frequencyMHz: Double
    let powerDB: Float
    let fingerprint: SignalFingerprint

    var frequencyLabel: String {
        String(format: "%.4f MHz", frequencyMHz)
    }
}

// MARK: - Classifier

struct SignalClassifier {

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

        let peakPower = spectrum[peakBin]
        let threshold = peakPower - 6.0

        var leftBin = peakBin
        while leftBin > 0 && spectrum[leftBin] > threshold { leftBin -= 1 }
        var rightBin = peakBin
        while rightBin < fftSize - 1 && spectrum[rightBin] > threshold { rightBin += 1 }

        let signalBins = max(rightBin - leftBin, 1)
        let binWidthMHz = bandwidthMHz / Double(fftSize)
        let signalBWkHz = Double(signalBins) * binWidthMHz * 1000.0

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

        // === Pinpoint frequency matches (most specific first) ===

        // ADS-B (1090 MHz)
        if freqMHz > 1088 && freqMHz < 1092 {
            return SignalFingerprint(
                type: .adsb, confidence: 0.9,
                description: "Aircraft transponder beacon at 1090 MHz",
                bandwidthKHz: bwKHz, suggestedDemod: .am
            )
        }

        // GPS band anomaly — wideband energy near L1 suggests jamming or interference
        if freqMHz > 1573 && freqMHz < 1578 && bwKHz > 100 {
            return SignalFingerprint(
                type: .gpsAnomaly, confidence: 0.7,
                description: "Wideband energy in GPS L1 band — possible jammer or interference",
                bandwidthKHz: bwKHz, suggestedDemod: .am
            )
        }

        // NOAA Weather Radio (162.4–162.55 MHz)
        if freqMHz > 162.3 && freqMHz < 162.6 {
            return SignalFingerprint(
                type: .weatherRadio, confidence: 0.85,
                description: "NOAA Weather Radio broadcast",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // FM Broadcast (88–108 MHz, wide bandwidth)
        if freqMHz > 87.5 && freqMHz < 108.5 && bwKHz > 60 {
            return SignalFingerprint(
                type: .fmBroadcast, confidence: 0.9,
                description: "Commercial FM radio station",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // === Band-specific classifications ===

        // Air Traffic Control (118–137 MHz) — aviation uses AM
        if freqMHz > 117.5 && freqMHz < 137.5 {
            let desc: String
            if freqMHz > 121.4 && freqMHz < 121.6 {
                desc = "Aviation guard/emergency frequency (121.5 MHz)"
            } else if freqMHz > 118 && freqMHz < 124 {
                desc = "ATC tower or ground control"
            } else if freqMHz > 124 && freqMHz < 132 {
                desc = "ATC approach/departure or en-route center"
            } else {
                desc = "Aviation VHF communication"
            }
            return SignalFingerprint(
                type: .airTrafficControl, confidence: 0.85,
                description: desc,
                bandwidthKHz: bwKHz, suggestedDemod: .am
            )
        }

        // Amateur 2m (144–148 MHz)
        if freqMHz > 143.5 && freqMHz < 148.5 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.65,
                description: "Amateur radio 2-meter band",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // MURS (151.820–154.600 MHz) — 5 specific channels
        if freqMHz > 151.7 && freqMHz < 154.7 && bwKHz < 30 {
            return SignalFingerprint(
                type: .murs, confidence: 0.7,
                description: "Multi-Use Radio Service — business, farm, or security",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Railroad (160.1–161.6 MHz) — check before marine VHF
        if freqMHz > 160.0 && freqMHz < 161.7 && bwKHz < 30 {
            return SignalFingerprint(
                type: .railroad, confidence: 0.75,
                description: "Railroad crew or dispatch communication",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Marine VHF (156–162 MHz, excluding railroad overlap)
        if freqMHz > 155.5 && freqMHz < 163 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.7,
                description: "Marine VHF radio",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Pager VHF (152–158 MHz, narrow)
        if freqMHz > 150 && freqMHz < 160 && bwKHz < 30 {
            return SignalFingerprint(
                type: .pager, confidence: 0.6,
                description: "Pager or narrowband data signal",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Public Safety VHF catch-all (150–174 MHz)
        if freqMHz > 149.5 && freqMHz < 174.5 && bwKHz < 30 {
            return SignalFingerprint(
                type: .publicSafety, confidence: 0.6,
                description: "VHF land mobile — likely police, fire, EMS, or government",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // FRS/GMRS (462–467 MHz, narrowband)
        if freqMHz > 461.5 && freqMHz < 467.5 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.75,
                description: "FRS/GMRS two-way radio",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Amateur 70cm (420–450 MHz)
        if freqMHz > 419 && freqMHz < 451 && bwKHz < 30 {
            return SignalFingerprint(
                type: .narrowbandFM, confidence: 0.65,
                description: "Amateur radio 70-cm band",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Public Safety UHF catch-all (450–470 MHz)
        if freqMHz > 449.5 && freqMHz < 470.5 && bwKHz < 30 {
            return SignalFingerprint(
                type: .publicSafety, confidence: 0.6,
                description: "UHF land mobile — likely police, fire, EMS, or business",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Wireless microphones / TV band (470–698 MHz)
        if freqMHz > 469 && freqMHz < 699 && bwKHz < 200 {
            return SignalFingerprint(
                type: .wirelessMic, confidence: 0.55,
                description: "Wireless microphone or TV band signal",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Trunked radio systems (851–869 MHz) — P25, EDACS, Motorola
        if freqMHz > 850 && freqMHz < 870 {
            let desc = flatness > 0.4
                ? "800 MHz trunked radio — digital (P25/DMR)"
                : "800 MHz trunked radio — analog or control channel"
            return SignalFingerprint(
                type: .trunkedRadio, confidence: 0.7,
                description: desc,
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Pager UHF (929–932 MHz)
        if freqMHz > 928 && freqMHz < 933 && bwKHz < 30 {
            return SignalFingerprint(
                type: .pager, confidence: 0.7,
                description: "POCSAG/FLEX pager — hospital or emergency services",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // Surveillance / wireless camera (895–930 MHz, wideband)
        if freqMHz > 895 && freqMHz < 930 && bwKHz > 50 {
            return SignalFingerprint(
                type: .surveillance, confidence: 0.6,
                description: "Wideband 900 MHz signal — possible wireless camera or analog video",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // 1.2 GHz surveillance cameras
        if freqMHz > 1200 && freqMHz < 1300 && bwKHz > 50 {
            return SignalFingerprint(
                type: .surveillance, confidence: 0.55,
                description: "Wideband 1.2 GHz signal — possible wireless camera",
                bandwidthKHz: bwKHz, suggestedDemod: .fm
            )
        }

        // === Generic classifications (bandwidth + spectral shape) ===

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
