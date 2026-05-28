import Foundation

@Observable
final class POCSAGDecoder {

    // MARK: - Types

    struct PagerMessage: Identifiable {
        let id = UUID()
        let timestamp: Date
        let address: UInt32
        let functionBits: UInt8
        let content: String
        let isNumeric: Bool
        let baud: Int
    }

    // MARK: - State

    var isActive = false { didSet { if !isActive { resetState() } } }
    private(set) var messages: [PagerMessage] = []
    private(set) var messageCount: Int = 0
    private(set) var syncCount: Int = 0

    // MARK: - Constants

    private static let syncWord: UInt32 = 0x7CD215D8
    private static let idleWord: UInt32 = 0x7A89C197
    private static let maxMessages = 500

    // MARK: - Demod State

    private var pendingSyncCount: Int = 0
    private var bufferCount: Int = 0

    private var prevI: Float = 0
    private var prevQ: Float = 0
    private var decimAccum: Float = 0
    private var decimCount: Int = 0
    private let decimFactor = 42 // 2.048 MHz → ~48.76 kHz

    // MARK: - Clock Recovery

    private var baudRate: Int = 1200
    private let outputSampleRate: Float = 48762 // 2_048_000 / 42
    private var samplesPerBit: Float = 0
    private var samplePhase: Float = 0
    private var prevDemod: Float = 0

    // MARK: - Bit / Frame State

    private var shiftReg: UInt32 = 0
    private var syncedBitCount: Int = 0
    private var inSync = false
    private var preambleRun: Int = 0
    private var batchSlot: Int = 0

    // Message assembly
    private var currentAddr: UInt32 = 0
    private var currentFunc: UInt8 = 0
    private var msgBits: [Bool] = []
    private var assembling = false

    // MARK: - Public

    func processIQ(_ buffer: UnsafeMutablePointer<UInt8>, length: Int) {
        guard isActive else { return }
        let pairs = length / 2
        samplesPerBit = outputSampleRate / Float(baudRate)

        for i in 0..<pairs {
            let iS = (Float(buffer[i * 2]) - 127.5) / 128.0
            let qS = (Float(buffer[i * 2 + 1]) - 127.5) / 128.0

            // FM discriminator: freq ∝ (I_prev·Q - Q_prev·I) / (I² + Q²)
            let cross = prevI * qS - prevQ * iS
            let mag = iS * iS + qS * qS
            let demod = mag > 1e-4 ? cross / mag : 0
            prevI = iS
            prevQ = qS

            // Accumulate for decimation
            decimAccum += demod
            decimCount += 1
            if decimCount >= decimFactor {
                let sample = decimAccum / Float(decimFactor)
                decimAccum = 0
                decimCount = 0
                processDemodSample(sample)
            }
        }

        // Periodically flush stats to UI
        bufferCount += 1
        if bufferCount % 10 == 0 {
            let syncs = pendingSyncCount
            DispatchQueue.main.async { [weak self] in
                self?.syncCount = syncs
            }
        }
    }

    func clearMessages() {
        messages = []
        messageCount = 0
        syncCount = 0
        pendingSyncCount = 0
    }

    // MARK: - Demod Sample Processing

    private func processDemodSample(_ sample: Float) {
        // Zero-crossing clock recovery: nudge phase on transitions
        if (sample > 0) != (prevDemod > 0) {
            let error = samplePhase - samplesPerBit * 0.5
            samplePhase -= error * 0.15
        }
        prevDemod = sample

        samplePhase += 1
        if samplePhase >= samplesPerBit {
            samplePhase -= samplesPerBit
            processBit(sample > 0)
        }
    }

    // MARK: - Bit-Level State Machine

    private func processBit(_ bit: Bool) {
        shiftReg = (shiftReg << 1) | (bit ? 1 : 0)

        if !inSync {
            // Count preamble-like alternating bits
            let lastTwo = shiftReg & 0x3
            if lastTwo == 0b10 || lastTwo == 0b01 {
                preambleRun += 1
            } else {
                preambleRun = 0
            }

            // Detect baud from preamble timing, then look for sync
            if preambleRun >= 40 && shiftReg == Self.syncWord {
                inSync = true
                batchSlot = 0
                syncedBitCount = 0
                preambleRun = 0
                pendingSyncCount += 1
            }
        } else {
            syncedBitCount += 1
            if syncedBitCount >= 32 {
                processCodeword(shiftReg)
                syncedBitCount = 0
                batchSlot += 1
                if batchSlot >= 17 {
                    batchSlot = 0
                }
            }
        }
    }

    // MARK: - Codeword Processing

    private func processCodeword(_ cw: UInt32) {
        if cw == Self.syncWord {
            batchSlot = 0
            return
        }
        if cw == Self.idleWord {
            finishMessage()
            return
        }

        // Simple parity check (even parity on all 32 bits)
        var parity = cw
        parity ^= parity >> 16
        parity ^= parity >> 8
        parity ^= parity >> 4
        parity ^= parity >> 2
        parity ^= parity >> 1
        if parity & 1 != 0 {
            // Parity error — skip
            return
        }

        let isMessage = (cw >> 31) & 1 == 1

        if !isMessage {
            // Address codeword
            finishMessage()
            let addrHigh = (cw >> 13) & 0x3FFFF
            let framePos = UInt32(max(0, batchSlot - 1) / 2)
            currentAddr = (addrHigh << 3) | framePos
            currentFunc = UInt8((cw >> 11) & 0x3)
            msgBits = []
            assembling = true
        } else if assembling {
            // Message codeword: 20 data bits (bits 30..11)
            for shift in stride(from: 30, through: 11, by: -1) {
                msgBits.append(((cw >> shift) & 1) == 1)
            }
        }
    }

    // MARK: - Message Assembly

    private func finishMessage() {
        guard assembling else { return }
        assembling = false
        guard !msgBits.isEmpty else { return }

        let isNumeric = currentFunc == 0 || currentFunc == 3
        let content = isNumeric ? decodeNumeric(msgBits) : decodeAlpha(msgBits)
        guard !content.isEmpty else { return }

        let msg = PagerMessage(
            timestamp: Date(),
            address: currentAddr,
            functionBits: currentFunc,
            content: content,
            isNumeric: isNumeric,
            baud: baudRate
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.messages.insert(msg, at: 0)
            if self.messages.count > Self.maxMessages {
                self.messages.removeLast(self.messages.count - Self.maxMessages)
            }
            self.messageCount += 1
        }
    }

    // MARK: - Character Decoding

    func decodeNumeric(_ bits: [Bool]) -> String {
        var result = ""
        for i in stride(from: 0, to: bits.count - 3, by: 4) {
            var val: UInt8 = 0
            for b in 0..<4 {
                if bits[i + b] { val |= 1 << UInt8(3 - b) }
            }
            switch val {
            case 0...9: result.append(String(val))
            case 10:    result.append(" ")
            case 11:    result.append("U")
            case 12:    result.append("-")
            case 13:    result.append(")")
            case 14:    result.append("(")
            default:    break
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    func decodeAlpha(_ bits: [Bool]) -> String {
        var result = ""
        for i in stride(from: 0, to: bits.count - 6, by: 7) {
            var val: UInt8 = 0
            // POCSAG alpha is LSB-first within each 7-bit character
            for b in 0..<7 {
                if bits[i + b] { val |= 1 << UInt8(b) }
            }
            if val >= 32 && val < 127 {
                result.append(Character(UnicodeScalar(val)))
            } else if val == 10 || val == 13 {
                result.append(" ")
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Reset

    private func resetState() {
        prevI = 0; prevQ = 0
        decimAccum = 0; decimCount = 0
        samplePhase = 0; prevDemod = 0
        shiftReg = 0; syncedBitCount = 0
        inSync = false; preambleRun = 0; batchSlot = 0
        msgBits = []; assembling = false
        pendingSyncCount = 0; bufferCount = 0
    }
}
