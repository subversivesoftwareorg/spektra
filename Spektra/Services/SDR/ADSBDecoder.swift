import Foundation

@Observable
final class ADSBDecoder {

    // MARK: - Types

    struct Aircraft: Identifiable, Hashable {
        let icao: UInt32
        var id: UInt32 { icao }
        var callsign: String = ""
        var altitude: Int?
        var groundSpeed: Int?
        var heading: Int?
        var verticalRate: Int?
        var latitude: Double?
        var longitude: Double?
        var lastSeen: Date = Date()
        var messageCount: Int = 0

        var icaoHex: String {
            String(format: "%06X", icao)
        }

        var altitudeString: String {
            guard let alt = altitude else { return "---" }
            return "\(alt) ft"
        }

        var positionString: String {
            guard let lat = latitude, let lon = longitude else { return "---" }
            return String(format: "%.4f, %.4f", lat, lon)
        }
    }

    // MARK: - State

    var isActive = false { didSet { if !isActive { resetState() } } }
    private(set) var aircraft: [Aircraft] = []
    private(set) var messageCount: Int = 0
    private(set) var crcErrors: Int = 0
    private(set) var preambleCount: Int = 0

    // MARK: - Capture

    private(set) var isCaptureActive = false
    private(set) var captureIQURL: URL?
    private(set) var captureLogURL: URL?
    private(set) var capturedBytes: Int = 0
    private(set) var capturedMessages: Int = 0

    private var iqFileHandle: FileHandle?
    private var logFileHandle: FileHandle?
    private var captureStartDate: Date?
    private let captureLock = NSLock()
    private var pendingCapturedBytes: Int = 0
    private var pendingCapturedMessages: Int = 0

    // MARK: - Internals

    private var aircraftMap: [UInt32: Aircraft] = [:]
    private var magnitudeBuffer: [UInt32] = []
    private var pendingMessageCount: Int = 0
    private var pendingCrcErrors: Int = 0
    private var pendingPreambleCount: Int = 0
    private var bufferCount: Int = 0

    // CPR state for position decoding
    private var cprEven: [UInt32: CPRFrame] = [:]
    private var cprOdd: [UInt32: CPRFrame] = [:]

    private struct CPRFrame {
        let lat: UInt32
        let lon: UInt32
        let timestamp: Date
    }

    // MARK: - Constants

    // Preamble at 2 Msps: 1,0,1,0,0,0,0,1,0,1,0,0,0,0,0,0 (16 samples for 8µs)
    private static let preamble: [Bool] = [
        true, false, true, false, false, false, false, true,
        false, true, false, false, false, false, false, false
    ]
    private static let preambleLen = 16
    private static let bitsPerMessage = 112
    private static let samplesPerBit = 2 // at ~2 Msps
    private static let messageSamples = bitsPerMessage * samplesPerBit // 224
    private static let frameSamples = preambleLen + messageSamples // 240

    // CRC-24 generator polynomial
    private static let crcGenerator: UInt32 = 0xFFF409

    private static let pruneInterval: TimeInterval = 60

    // MARK: - Capture Control

    func startCapture() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let stamp = formatter.string(from: Date())

        let iqURL = dir.appendingPathComponent("adsb_capture_\(stamp).iq")
        let logURL = dir.appendingPathComponent("adsb_capture_\(stamp).csv")

        FileManager.default.createFile(atPath: iqURL.path, contents: nil)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        captureLock.lock()
        iqFileHandle = try? FileHandle(forWritingTo: iqURL)
        logFileHandle = try? FileHandle(forWritingTo: logURL)
        let header = "timestamp,preamble_idx,df,msg_hex,crc_remainder,crc_ok,preamble_ratio\n"
        logFileHandle?.write(header.data(using: .utf8)!)
        captureLock.unlock()

        captureIQURL = iqURL
        captureLogURL = logURL
        capturedBytes = 0
        capturedMessages = 0
        pendingCapturedBytes = 0
        pendingCapturedMessages = 0
        captureStartDate = Date()
        isCaptureActive = true
    }

    func stopCapture() {
        isCaptureActive = false
        captureLock.lock()
        try? iqFileHandle?.close()
        try? logFileHandle?.close()
        iqFileHandle = nil
        logFileHandle = nil
        captureLock.unlock()
    }

    var captureDuration: TimeInterval {
        guard let start = captureStartDate, isCaptureActive else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var captureSizeMB: Double {
        Double(capturedBytes) / (1024 * 1024)
    }

    // MARK: - Public

    func processIQ(_ buffer: UnsafeMutablePointer<UInt8>, length: Int) {
        guard isActive, length >= 2 else { return }

        if isCaptureActive {
            captureLock.lock()
            if let handle = iqFileHandle {
                let data = Data(bytes: buffer, count: length)
                handle.write(data)
                pendingCapturedBytes += length
            }
            captureLock.unlock()
        }

        let pairs = length / 2

        // Compute magnitude² (skip sqrt for speed)
        // At 2.048 Msps, each ADS-B bit ≈ 2.048 samples
        var mags = [UInt32](repeating: 0, count: pairs)
        for i in 0..<pairs {
            let iVal = Int32(buffer[i * 2]) - 127
            let qVal = Int32(buffer[i * 2 + 1]) - 127
            mags[i] = UInt32(iVal * iVal + qVal * qVal)
        }

        // Prepend any residual from previous buffer
        if !magnitudeBuffer.isEmpty {
            magnitudeBuffer.append(contentsOf: mags)
            searchForMessages(in: magnitudeBuffer)
            magnitudeBuffer = []
        } else {
            searchForMessages(in: mags)
        }

        // Keep tail for messages spanning buffer boundaries
        let tail = min(Self.frameSamples, mags.count)
        magnitudeBuffer = Array(mags.suffix(tail))

        // Periodically flush stats to UI even when no valid messages decoded
        bufferCount += 1
        if bufferCount % 10 == 0 {
            let count = pendingMessageCount
            let errors = pendingCrcErrors
            let preambles = pendingPreambleCount
            let capBytes = pendingCapturedBytes
            let capMsgs = pendingCapturedMessages
            DispatchQueue.main.async { [weak self] in
                self?.messageCount = count
                self?.crcErrors = errors
                self?.preambleCount = preambles
                self?.capturedBytes = capBytes
                self?.capturedMessages = capMsgs
            }
        }
    }

    func clearAircraft() {
        aircraftMap = [:]
        aircraft = []
        messageCount = 0
        crcErrors = 0
        preambleCount = 0
        pendingMessageCount = 0
        pendingCrcErrors = 0
        pendingPreambleCount = 0
        cprEven = [:]
        cprOdd = [:]
    }

    // MARK: - Preamble Detection

    private func searchForMessages(in mags: [UInt32]) {
        let limit = mags.count - Self.frameSamples
        guard limit > 0 else { return }

        var i = 0
        while i < limit {
            if detectPreamble(mags, at: i) {
                pendingPreambleCount += 1
                if let msg = extractMessage(mags, preambleStart: i) {
                    handleMessage(msg)
                    i += Self.frameSamples
                    continue
                }
            }
            i += 1
        }
    }

    func detectPreamble(_ mags: [UInt32], at offset: Int) -> Bool {
        // Check preamble pattern: high samples should exceed low samples
        let s0 = mags[offset]
        let s2 = mags[offset + 2]
        let s7 = mags[offset + 7]
        let s9 = mags[offset + 9]
        let highMin = min(min(s0, s2), min(s7, s9))

        let s1 = mags[offset + 1]
        let s3 = mags[offset + 3]
        let s4 = mags[offset + 4]
        let s5 = mags[offset + 5]
        let lowMax = max(max(s1, s3), max(s4, s5))

        guard highMin > lowMax else { return false }

        let s6 = mags[offset + 6]
        let s8 = mags[offset + 8]
        let s10 = mags[offset + 10]
        let s11 = mags[offset + 11]
        let lowMax2 = max(max(s6, s8), max(s10, s11))

        return highMin > lowMax2
    }

    // MARK: - Message Extraction

    private func extractMessage(_ mags: [UInt32], preambleStart: Int) -> [UInt8]? {
        let dataStart = preambleStart + Self.preambleLen
        var bits = [UInt8](repeating: 0, count: Self.bitsPerMessage / 8)

        for bit in 0..<Self.bitsPerMessage {
            let sampleIdx = dataStart + bit * Self.samplesPerBit
            guard sampleIdx + 1 < mags.count else { return nil }

            // PPM: bit=1 if first half > second half
            if mags[sampleIdx] > mags[sampleIdx + 1] {
                bits[bit / 8] |= UInt8(1 << (7 - (bit % 8)))
            }
        }

        // Check Downlink Format (first 5 bits)
        let df = Int(bits[0] >> 3)
        // Only process DF17 (ADS-B) and DF18 (non-transponder ADS-B)
        guard df == 17 || df == 18 else { return nil }

        let crcOk = crcCheck(bits)

        if isCaptureActive {
            logCandidateMessage(bits, df: df, crcOk: crcOk, mags: mags, preambleStart: preambleStart)
        }

        if !crcOk {
            pendingCrcErrors += 1
            return nil
        }

        return bits
    }

    private func logCandidateMessage(_ msg: [UInt8], df: Int, crcOk: Bool, mags: [UInt32], preambleStart: Int) {
        let hex = msg.map { String(format: "%02X", $0) }.joined()
        let crcRemainder = computeCRCRemainder(msg)

        let s0 = mags[preambleStart]
        let s2 = mags[preambleStart + 2]
        let s7 = mags[preambleStart + 7]
        let s9 = mags[preambleStart + 9]
        let highMin = min(min(s0, s2), min(s7, s9))
        let s1 = mags[preambleStart + 1]
        let s3 = mags[preambleStart + 3]
        let s4 = mags[preambleStart + 4]
        let s5 = mags[preambleStart + 5]
        let lowMax = max(max(s1, s3), max(s4, s5))
        let ratio = lowMax > 0 ? String(format: "%.2f", Double(highMin) / Double(lowMax)) : "inf"

        let timestamp = String(format: "%.3f", Date().timeIntervalSince(captureStartDate ?? Date()))
        let line = "\(timestamp),\(preambleStart),\(df),\(hex),\(String(format: "%06X", crcRemainder)),\(crcOk),\(ratio)\n"
        if let data = line.data(using: .utf8) {
            captureLock.lock()
            logFileHandle?.write(data)
            pendingCapturedMessages += 1
            captureLock.unlock()
        }
    }

    private func computeCRCRemainder(_ msg: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0
        for i in 0..<14 {
            let byte = UInt32(msg[i])
            for bit in stride(from: 7, through: 0, by: -1) {
                let inBit = (byte >> bit) & 1
                let fb = ((crc >> 23) ^ inBit) & 1
                crc = ((crc << 1) & 0xFFFFFF)
                if fb == 1 {
                    crc ^= Self.crcGenerator
                }
            }
        }
        return crc
    }

    // MARK: - CRC-24

    func crcCheck(_ msg: [UInt8]) -> Bool {
        // Message is 14 bytes (112 bits). Last 3 bytes are CRC XOR'd with ICAO address.
        // For DF17: CRC should be 0 when computed over all 112 bits.
        var crc: UInt32 = 0
        for i in 0..<14 {
            let byte = UInt32(msg[i])
            for bit in stride(from: 7, through: 0, by: -1) {
                let inBit = (byte >> bit) & 1
                let fb = ((crc >> 23) ^ inBit) & 1
                crc = ((crc << 1) & 0xFFFFFF)
                if fb == 1 {
                    crc ^= Self.crcGenerator
                }
            }
        }
        return crc == 0
    }

    // MARK: - Message Parsing

    private func handleMessage(_ msg: [UInt8]) {
        let icao = (UInt32(msg[1]) << 16) | (UInt32(msg[2]) << 8) | UInt32(msg[3])
        let tc = Int(msg[4] >> 3) // Type Code (bits 33-37)

        var ac = aircraftMap[icao] ?? Aircraft(icao: icao)
        ac.lastSeen = Date()
        ac.messageCount += 1

        switch tc {
        case 1...4:
            ac.callsign = decodeCallsign(msg)
        case 9...18:
            decodeAirbornePosition(msg, tc: tc, aircraft: &ac)
        case 19:
            decodeVelocity(msg, aircraft: &ac)
        default:
            break
        }

        aircraftMap[icao] = ac

        let now = Date()
        aircraftMap = aircraftMap.filter { now.timeIntervalSince($0.value.lastSeen) < Self.pruneInterval }

        let sorted = aircraftMap.values.sorted { $0.lastSeen > $1.lastSeen }
        pendingMessageCount += 1
        let count = pendingMessageCount
        let errors = pendingCrcErrors

        DispatchQueue.main.async { [weak self] in
            self?.aircraft = sorted
            self?.messageCount = count
            self?.crcErrors = errors
        }
    }

    // MARK: - DF17 Type Code Parsers

    func decodeCallsign(_ msg: [UInt8]) -> String {
        let charset = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ##### ###############0123456789######"
        var callsign = ""

        // 8 characters, 6 bits each, starting at bit 40 (byte 5, bit 0)
        let payload = extractBits(msg, from: 40, count: 48)
        for i in 0..<8 {
            let idx = Int((payload >> (42 - i * 6)) & 0x3F)
            let char = charset[charset.index(charset.startIndex, offsetBy: min(idx, charset.count - 1))]
            if char != "#" {
                callsign.append(char)
            }
        }
        return callsign.trimmingCharacters(in: .whitespaces)
    }

    private func decodeAirbornePosition(_ msg: [UInt8], tc: Int, aircraft: inout Aircraft) {
        // Altitude (bits 41-52, 12 bits)
        let altCode = Int(extractBits(msg, from: 40, count: 12))
        aircraft.altitude = decodeAltitude(altCode, tc: tc)

        // CPR format flag (bit 53)
        let cprFlag = Int(extractBits(msg, from: 53, count: 1))
        // CPR latitude (bits 54-70, 17 bits)
        let cprLat = UInt32(extractBits(msg, from: 54, count: 17))
        // CPR longitude (bits 71-87, 17 bits)
        let cprLon = UInt32(extractBits(msg, from: 71, count: 17))

        let frame = CPRFrame(lat: cprLat, lon: cprLon, timestamp: Date())
        let icao = aircraft.icao

        if cprFlag == 0 {
            cprEven[icao] = frame
        } else {
            cprOdd[icao] = frame
        }

        // Attempt global CPR decode if we have both frames
        if let even = cprEven[icao], let odd = cprOdd[icao] {
            let timeDiff = abs(even.timestamp.timeIntervalSince(odd.timestamp))
            if timeDiff < 10 {
                if let (lat, lon) = decodeCPRGlobal(even: even, odd: odd, mostRecent: cprFlag) {
                    if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                        aircraft.latitude = lat
                        aircraft.longitude = lon
                    }
                }
            }
        }
    }

    func decodeAltitude(_ code: Int, tc: Int) -> Int? {
        if tc >= 9 && tc <= 18 {
            // Barometric altitude, Gillham code
            // Bit layout: M (bit 6) and Q (bit 4) determine encoding
            let qBit = (code >> 4) & 1
            if qBit == 1 {
                // 25-ft increments
                let n = ((code >> 5) << 4) | (code & 0xF)
                return n * 25 - 1000
            } else {
                // 100-ft increments (Gillham) — simplified
                return nil
            }
        }
        return nil
    }

    private func decodeVelocity(_ msg: [UInt8], aircraft: inout Aircraft) {
        let subtype = Int(extractBits(msg, from: 37, count: 3))

        if subtype == 1 || subtype == 2 {
            // Ground speed
            let ewDir = Int(extractBits(msg, from: 45, count: 1))
            let ewVel = Int(extractBits(msg, from: 46, count: 10)) - 1
            let nsDir = Int(extractBits(msg, from: 56, count: 1))
            let nsVel = Int(extractBits(msg, from: 57, count: 10)) - 1

            if ewVel >= 0 && nsVel >= 0 {
                let vx = Double(ewDir == 1 ? -ewVel : ewVel)
                let vy = Double(nsDir == 1 ? -nsVel : nsVel)

                let speed = Int(sqrt(vx * vx + vy * vy))
                let hdg = Int(atan2(vx, vy) * 180.0 / .pi + 360) % 360

                aircraft.groundSpeed = subtype == 2 ? speed * 4 : speed
                aircraft.heading = hdg
            }

            // Vertical rate (bits 69-78)
            let vrSign = Int(extractBits(msg, from: 68, count: 1))
            let vrVal = Int(extractBits(msg, from: 69, count: 9)) - 1
            if vrVal >= 0 {
                aircraft.verticalRate = (vrSign == 1 ? -1 : 1) * vrVal * 64
            }
        }
    }

    // MARK: - CPR Position Decoding

    private func decodeCPRGlobal(even: CPRFrame, odd: CPRFrame, mostRecent: Int) -> (Double, Double)? {
        let airDLat0 = 360.0 / 60.0
        let airDLat1 = 360.0 / 59.0

        let lat0 = Double(even.lat) / 131072.0
        let lat1 = Double(odd.lat) / 131072.0
        let lon0 = Double(even.lon) / 131072.0
        let lon1 = Double(odd.lon) / 131072.0

        let j = Int(floor(59.0 * lat0 - 60.0 * lat1 + 0.5))

        var rLat0 = airDLat0 * (Double(j % 60) + lat0)
        var rLat1 = airDLat1 * (Double(j % 59) + lat1)

        if rLat0 >= 270 { rLat0 -= 360 }
        if rLat1 >= 270 { rLat1 -= 360 }

        let nl0 = cprNL(rLat0)
        let nl1 = cprNL(rLat1)
        guard nl0 == nl1 else { return nil }

        let lat: Double
        let lon: Double

        if mostRecent == 0 {
            lat = rLat0
            let nl = Double(max(nl0, 1))
            let ni = max(nl, 1)
            let m = Int(floor(lon0 * (nl - 1) - lon1 * nl + 0.5))
            lon = (360.0 / ni) * (Double(m % Int(ni)) + lon0)
        } else {
            lat = rLat1
            let nl = Double(max(nl1 - 1, 1))
            let ni = max(nl, 1)
            let m = Int(floor(lon0 * (nl - 1) - lon1 * nl + 0.5))
            lon = (360.0 / ni) * (Double(m % Int(ni)) + lon1)
        }

        let finalLon = lon > 180 ? lon - 360 : lon
        return (lat, finalLon)
    }

    private func cprNL(_ lat: Double) -> Int {
        if abs(lat) >= 87.0 { return 1 }
        let tmp = 1.0 - cos(.pi / (2.0 * 15.0))
        let nz = 2.0 * .pi / acos(1.0 - tmp / pow(cos(.pi / 180.0 * abs(lat)), 2))
        return Int(floor(nz))
    }

    // MARK: - Bit Extraction

    func extractBits(_ msg: [UInt8], from startBit: Int, count: Int) -> UInt64 {
        var result: UInt64 = 0
        for i in 0..<count {
            let bitPos = startBit + i
            let byteIdx = bitPos / 8
            let bitIdx = 7 - (bitPos % 8)
            guard byteIdx < msg.count else { break }
            let bit = (UInt64(msg[byteIdx]) >> bitIdx) & 1
            result = (result << 1) | bit
        }
        return result
    }

    // MARK: - Reset

    private func resetState() {
        if isCaptureActive { stopCapture() }
        magnitudeBuffer = []
        cprEven = [:]
        cprOdd = [:]
        pendingPreambleCount = 0
        bufferCount = 0
    }
}
