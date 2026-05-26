import Foundation
import AVFoundation
import Accelerate

@Observable
final class SDRAudioEngine {

    // MARK: - Types

    enum DemodMode: String, CaseIterable, Identifiable {
        case fm = "FM"
        case am = "AM"
        case usb = "USB"
        case lsb = "LSB"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .fm: "Frequency Modulation"
            case .am: "Amplitude Modulation"
            case .usb: "Upper Sideband"
            case .lsb: "Lower Sideband"
            }
        }
    }

    // MARK: - State

    private(set) var isPlaying = false
    private(set) var audioLevel: Float = 0

    var mode: DemodMode = .fm
    var volume: Float = 0.5
    var squelchLevel: Float = -35
    var isMuted = false

    // MARK: - Internals

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // Ring buffer
    private let ringBufferSize = 65536
    private var ringBuffer: [Float]
    private var writeIndex = 0
    private var readIndex = 0
    private let bufferLock = NSLock()

    // Demod state
    private var prevI: Float = 0
    private var prevQ: Float = 0

    // Audio params
    let audioSampleRate: Double = 48000
    private let decimationFactor = 42 // 2048000 / 48000 ~ 42.67

    // Throttle audio level updates
    private var levelCounter = 0

    // MARK: - Lifecycle

    init() {
        ringBuffer = [Float](repeating: 0, count: ringBufferSize)
    }

    // MARK: - Start / Stop

    func start() {
        guard !isPlaying else { return }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: audioSampleRate, channels: 1) else { return }

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            self.bufferLock.lock()
            let available = (self.writeIndex - self.readIndex + self.ringBufferSize) % self.ringBufferSize
            for buffer in ablPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                if available >= frames {
                    let vol = self.isMuted ? Float(0) : self.volume
                    for i in 0..<frames {
                        data[i] = self.ringBuffer[(self.readIndex + i) % self.ringBufferSize] * vol
                    }
                    self.readIndex = (self.readIndex + frames) % self.ringBufferSize
                } else {
                    for i in 0..<frames { data[i] = 0 }
                }
            }
            self.bufferLock.unlock()
            return noErr
        }
        self.sourceNode = node

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            isPlaying = true
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }

    func stop() {
        audioEngine?.stop()
        if let node = sourceNode {
            audioEngine?.detach(node)
        }
        sourceNode = nil
        audioEngine = nil
        isPlaying = false
        prevI = 0
        prevQ = 0
        bufferLock.lock()
        writeIndex = 0
        readIndex = 0
        bufferLock.unlock()
        audioLevel = 0
    }

    // MARK: - IQ Processing (called from streaming thread)

    func processIQ(_ buf: UnsafeMutablePointer<UInt8>, length: Int, signalPowerDB: Float) {
        guard isPlaying else { return }

        // Squelch: output silence if signal is below threshold
        if signalPowerDB < squelchLevel {
            return
        }

        let samplePairs = length / 2

        // Convert to float IQ
        var iSamples = [Float](repeating: 0, count: samplePairs)
        var qSamples = [Float](repeating: 0, count: samplePairs)
        for n in 0..<samplePairs {
            iSamples[n] = (Float(buf[n * 2]) - 127.5) / 128.0
            qSamples[n] = (Float(buf[n * 2 + 1]) - 127.5) / 128.0
        }

        // Demodulate
        let demodded: [Float]
        switch mode {
        case .fm:  demodded = demodFM(i: iSamples, q: qSamples)
        case .am:  demodded = demodAM(i: iSamples, q: qSamples)
        case .usb: demodded = demodSSB(i: iSamples, q: qSamples, upper: true)
        case .lsb: demodded = demodSSB(i: iSamples, q: qSamples, upper: false)
        }

        // Decimate to audio rate
        let audioSamples = decimate(demodded, factor: decimationFactor)
        guard !audioSamples.isEmpty else { return }

        // Measure peak level (throttled dispatch to main)
        var maxVal: Float = 0
        vDSP_maxmgv(audioSamples, 1, &maxVal, vDSP_Length(audioSamples.count))
        levelCounter += 1
        if levelCounter % 8 == 0 {
            let level = min(maxVal * 3.0, 1.0) // Scale for visibility
            DispatchQueue.main.async { [weak self] in
                self?.audioLevel = level
            }
        }

        // Push to ring buffer
        bufferLock.lock()
        for sample in audioSamples {
            ringBuffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % ringBufferSize
            if writeIndex == readIndex {
                readIndex = (readIndex + 1) % ringBufferSize
            }
        }
        bufferLock.unlock()
    }

    // MARK: - Demodulation

    /// FM: phase discriminator (atan2 of cross/dot products)
    private func demodFM(i: [Float], q: [Float]) -> [Float] {
        var audio = [Float](repeating: 0, count: i.count)
        var pI = prevI, pQ = prevQ

        for n in 0..<i.count {
            let cross = q[n] * pI - i[n] * pQ
            let dot   = i[n] * pI + q[n] * pQ
            audio[n] = atan2f(cross, dot)
            pI = i[n]; pQ = q[n]
        }

        prevI = pI; prevQ = pQ
        return audio
    }

    /// AM: envelope detection via magnitude, DC-removed
    private func demodAM(i: [Float], q: [Float]) -> [Float] {
        var audio = [Float](repeating: 0, count: i.count)
        vDSP_vdist(i, 1, q, 1, &audio, 1, vDSP_Length(i.count))
        // Remove DC
        var mean: Float = 0
        vDSP_meanv(audio, 1, &mean, vDSP_Length(audio.count))
        var negMean = -mean
        vDSP_vsadd(audio, 1, &negMean, &audio, 1, vDSP_Length(audio.count))
        return audio
    }

    /// SSB: simplified I +/- Q (approximate without Hilbert filter)
    private func demodSSB(i: [Float], q: [Float], upper: Bool) -> [Float] {
        var audio = [Float](repeating: 0, count: i.count)
        if upper {
            for n in 0..<i.count { audio[n] = i[n] - q[n] }
        } else {
            for n in 0..<i.count { audio[n] = i[n] + q[n] }
        }
        return audio
    }

    // MARK: - Decimation

    /// Box-filter anti-alias + downsample
    private func decimate(_ input: [Float], factor: Int) -> [Float] {
        let count = input.count / factor
        guard count > 0 else { return [] }
        var output = [Float](repeating: 0, count: count)
        let fFactor = Float(factor)
        input.withUnsafeBufferPointer { ptr in
            for i in 0..<count {
                var sum: Float = 0
                vDSP_sve(ptr.baseAddress! + (i * factor), 1, &sum, vDSP_Length(factor))
                output[i] = sum / fFactor
            }
        }
        return output
    }
}
