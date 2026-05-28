import XCTest
@testable import Spektra

final class ADSBDecoderTests: XCTestCase {

    private var decoder: ADSBDecoder!

    override func setUp() {
        super.setUp()
        decoder = ADSBDecoder()
    }

    override func tearDown() {
        decoder = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func computeCRC24(_ msg: [UInt8], byteCount: Int) -> UInt32 {
        let generator: UInt32 = 0xFFF409
        var crc: UInt32 = 0
        for i in 0..<byteCount {
            let byte = UInt32(msg[i])
            for bit in stride(from: 7, through: 0, by: -1) {
                let inBit = (byte >> bit) & 1
                let fb = ((crc >> 23) ^ inBit) & 1
                crc = ((crc << 1) & 0xFFFFFF)
                if fb == 1 { crc ^= generator }
            }
        }
        return crc
    }

    private func buildDF17(icao: UInt32, me: [UInt8]) -> [UInt8] {
        var msg = [UInt8](repeating: 0, count: 14)
        msg[0] = 0x8D  // DF=17, CA=5
        msg[1] = UInt8((icao >> 16) & 0xFF)
        msg[2] = UInt8((icao >> 8) & 0xFF)
        msg[3] = UInt8(icao & 0xFF)
        for i in 0..<min(me.count, 7) {
            msg[4 + i] = me[i]
        }
        let crc = computeCRC24(msg, byteCount: 11)
        msg[11] = UInt8((crc >> 16) & 0xFF)
        msg[12] = UInt8((crc >> 8) & 0xFF)
        msg[13] = UInt8(crc & 0xFF)
        return msg
    }

    private func encodeADSBFrame(_ msg: [UInt8]) -> [UInt8] {
        let highI: UInt8 = 250
        let lowI: UInt8 = 127
        let centerQ: UInt8 = 127

        let preamblePattern: [Bool] = [
            true, false, true, false, false, false, false, true,
            false, true, false, false, false, false, false, false
        ]

        var iq: [UInt8] = []

        for high in preamblePattern {
            iq.append(high ? highI : lowI)
            iq.append(centerQ)
        }

        for byteIdx in 0..<14 {
            for bitIdx in stride(from: 7, through: 0, by: -1) {
                let bit = (msg[byteIdx] >> bitIdx) & 1
                if bit == 1 {
                    iq.append(highI); iq.append(centerQ)
                    iq.append(lowI); iq.append(centerQ)
                } else {
                    iq.append(lowI); iq.append(centerQ)
                    iq.append(highI); iq.append(centerQ)
                }
            }
        }

        return iq
    }

    // MARK: - Bit Extraction

    func testExtractBitsDF() {
        let msg: [UInt8] = [0x8D, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let df = decoder.extractBits(msg, from: 0, count: 5)
        XCTAssertEqual(df, 17, "DF field should be 17 for 0x8D")
    }

    func testExtractBitsICAO() {
        let msg: [UInt8] = [0x8D, 0x48, 0x40, 0xD6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let icao = decoder.extractBits(msg, from: 8, count: 24)
        XCTAssertEqual(icao, 0x4840D6)
    }

    func testExtractBitsCrossesByteBoundary() {
        let msg: [UInt8] = [0xFF, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let value = decoder.extractBits(msg, from: 4, count: 8)
        XCTAssertEqual(value, 0xF8)
    }

    func testExtractBitsSingleBit() {
        let msg: [UInt8] = [0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        XCTAssertEqual(decoder.extractBits(msg, from: 0, count: 1), 1)
        XCTAssertEqual(decoder.extractBits(msg, from: 1, count: 1), 0)
    }

    // MARK: - CRC-24

    func testCRCValidMessage() {
        let msg = buildDF17(icao: 0x4840D6, me: [0x20, 0x2C, 0xC3, 0x71, 0xC3, 0x2C, 0xE0])
        XCTAssertTrue(decoder.crcCheck(msg), "Valid DF17 message should pass CRC")
    }

    func testCRCCorruptedMessage() {
        var msg = buildDF17(icao: 0x4840D6, me: [0x20, 0x2C, 0xC3, 0x71, 0xC3, 0x2C, 0xE0])
        msg[5] ^= 0x01
        XCTAssertFalse(decoder.crcCheck(msg), "Corrupted message should fail CRC")
    }

    func testCRCAllZeroPayload() {
        let msg = buildDF17(icao: 0x000000, me: [0, 0, 0, 0, 0, 0, 0])
        XCTAssertTrue(decoder.crcCheck(msg))
    }

    func testCRCDifferentICAOsProduceDifferentCRCs() {
        let msg1 = buildDF17(icao: 0xABCDEF, me: [0x20, 0, 0, 0, 0, 0, 0])
        let msg2 = buildDF17(icao: 0x123456, me: [0x20, 0, 0, 0, 0, 0, 0])
        XCTAssertTrue(decoder.crcCheck(msg1))
        XCTAssertTrue(decoder.crcCheck(msg2))
        XCTAssertNotEqual(Array(msg1[11...13]), Array(msg2[11...13]))
    }

    // MARK: - Callsign Decoding

    func testDecodeCallsignTEST() {
        // T=20, E=5, S=19, T=20, sp=32 x4
        // Bits: 010100 000101 010011 010100 100000 100000 100000 100000
        let me: [UInt8] = [0x20, 0x50, 0x54, 0xD4, 0x82, 0x08, 0x20]
        let msg = buildDF17(icao: 0xABCDEF, me: me)
        XCTAssertEqual(decoder.decodeCallsign(msg), "TEST")
    }

    func testDecodeCallsignWithNumbers() {
        // U=21, A=1, L=12, 1=49, 2=50, 3=51, sp=32 x2
        // 010101 000001 001100 110001 110010 110011 100000 100000
        let me: [UInt8] = [0x20, 0x54, 0x13, 0x31, 0xCB, 0x38, 0x20]
        let msg = buildDF17(icao: 0xABCDEF, me: me)
        XCTAssertEqual(decoder.decodeCallsign(msg), "UAL123")
    }

    // MARK: - Altitude Decoding

    func testDecodeAltitude38000ft() {
        // Q=1, 25-ft increments. n=(38000+1000)/25=1560
        // upper=97, lower=8, code=(97<<5)|16|8=3128=0xC38
        XCTAssertEqual(decoder.decodeAltitude(0xC38, tc: 11), 38000)
    }

    func testDecodeAltitude1000ft() {
        // n=(1000+1000)/25=80, upper=5, lower=0, code=(5<<5)|16|0=176=0xB0
        XCTAssertEqual(decoder.decodeAltitude(0xB0, tc: 11), 1000)
    }

    func testDecodeAltitudeGillhamReturnsNil() {
        // Q-bit=0 → Gillham encoding (simplified returns nil)
        let code = 0xC38 & ~(1 << 4)  // Clear Q-bit
        XCTAssertNil(decoder.decodeAltitude(code, tc: 11))
    }

    func testDecodeAltitudeOutsideTCRangeReturnsNil() {
        XCTAssertNil(decoder.decodeAltitude(0xC38, tc: 5))
    }

    // MARK: - Preamble Detection

    func testDetectValidPreamble() {
        let high: UInt32 = 16000
        let low: UInt32 = 100
        let pattern: [Bool] = [
            true, false, true, false, false, false, false, true,
            false, true, false, false, false, false, false, false
        ]
        var mags: [UInt32] = pattern.map { $0 ? high : low }
        mags += [UInt32](repeating: low, count: 240)
        XCTAssertTrue(decoder.detectPreamble(mags, at: 0))
    }

    func testRejectFlatNoisePreamble() {
        let mags = [UInt32](repeating: 5000, count: 256)
        XCTAssertFalse(decoder.detectPreamble(mags, at: 0))
    }

    func testRejectInvertedPreamble() {
        let high: UInt32 = 16000
        let low: UInt32 = 100
        let pattern: [Bool] = [
            false, true, false, true, true, true, true, false,
            true, false, true, true, true, true, true, true
        ]
        var mags: [UInt32] = pattern.map { $0 ? high : low }
        mags += [UInt32](repeating: low, count: 240)
        XCTAssertFalse(decoder.detectPreamble(mags, at: 0))
    }

    func testDetectPreambleAtOffset() {
        let high: UInt32 = 16000
        let low: UInt32 = 100
        let pattern: [Bool] = [
            true, false, true, false, false, false, false, true,
            false, true, false, false, false, false, false, false
        ]
        var mags = [UInt32](repeating: low, count: 50)
        mags += pattern.map { $0 ? high : low }
        mags += [UInt32](repeating: low, count: 240)
        XCTAssertFalse(decoder.detectPreamble(mags, at: 0))
        XCTAssertTrue(decoder.detectPreamble(mags, at: 50))
    }

    // MARK: - End-to-End Integration

    func testProcessIQDecodesValidMessage() {
        decoder.isActive = true

        let msg = buildDF17(icao: 0xABCDEF, me: [0x20, 0x50, 0x54, 0xD4, 0x82, 0x08, 0x20])
        var iqData = encodeADSBFrame(msg)

        while iqData.count < 1024 {
            iqData.append(127)
            iqData.append(127)
        }

        iqData.withUnsafeMutableBufferPointer { buffer in
            decoder.processIQ(buffer.baseAddress!, length: buffer.count)
        }

        let exp = expectation(description: "main thread update")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(decoder.messageCount, 1)
        XCTAssertEqual(decoder.aircraft.count, 1)
        XCTAssertEqual(decoder.aircraft.first?.icaoHex, "ABCDEF")
        XCTAssertEqual(decoder.aircraft.first?.callsign, "TEST")
    }

    func testCRCErrorsReportedWithoutValidMessages() {
        decoder.isActive = true

        var msg = buildDF17(icao: 0xABCDEF, me: [0x20, 0x50, 0x54, 0xD4, 0x82, 0x08, 0x20])
        msg[5] ^= 0xFF
        var iqData = encodeADSBFrame(msg)

        while iqData.count < 1024 {
            iqData.append(127)
            iqData.append(127)
        }

        for _ in 0..<10 {
            iqData.withUnsafeMutableBufferPointer { buffer in
                decoder.processIQ(buffer.baseAddress!, length: buffer.count)
            }
        }

        let exp = expectation(description: "stats flush")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertGreaterThan(decoder.preambleCount, 0, "Should detect preambles even with bad CRC")
        XCTAssertGreaterThan(decoder.crcErrors, 0, "CRC errors must be reported without valid messages")
        XCTAssertEqual(decoder.messageCount, 0)
    }

    func testNoiseProducesNoDetections() {
        decoder.isActive = true

        var iqData = [UInt8](repeating: 127, count: 1024)

        for _ in 0..<10 {
            iqData.withUnsafeMutableBufferPointer { buffer in
                decoder.processIQ(buffer.baseAddress!, length: buffer.count)
            }
        }

        let exp = expectation(description: "stats flush")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(decoder.preambleCount, 0)
        XCTAssertEqual(decoder.crcErrors, 0)
        XCTAssertEqual(decoder.messageCount, 0)
    }

    func testInactiveDecoderIgnoresData() {
        decoder.isActive = false

        let msg = buildDF17(icao: 0xABCDEF, me: [0x20, 0x50, 0x54, 0xD4, 0x82, 0x08, 0x20])
        var iqData = encodeADSBFrame(msg)
        while iqData.count < 1024 {
            iqData.append(127)
            iqData.append(127)
        }

        for _ in 0..<10 {
            iqData.withUnsafeMutableBufferPointer { buffer in
                decoder.processIQ(buffer.baseAddress!, length: buffer.count)
            }
        }

        let exp = expectation(description: "main thread")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(decoder.messageCount, 0)
        XCTAssertEqual(decoder.aircraft.count, 0)
    }

    func testClearResetsAllCounters() {
        decoder.isActive = true

        let msg = buildDF17(icao: 0xABCDEF, me: [0x20, 0x50, 0x54, 0xD4, 0x82, 0x08, 0x20])
        var iqData = encodeADSBFrame(msg)
        while iqData.count < 1024 {
            iqData.append(127)
            iqData.append(127)
        }

        iqData.withUnsafeMutableBufferPointer { buffer in
            decoder.processIQ(buffer.baseAddress!, length: buffer.count)
        }

        let exp = expectation(description: "main thread")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        decoder.clearAircraft()

        XCTAssertEqual(decoder.messageCount, 0)
        XCTAssertEqual(decoder.crcErrors, 0)
        XCTAssertEqual(decoder.preambleCount, 0)
        XCTAssertEqual(decoder.aircraft.count, 0)
    }
}
