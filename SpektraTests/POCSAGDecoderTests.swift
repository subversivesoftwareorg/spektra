import XCTest
@testable import Spektra

final class POCSAGDecoderTests: XCTestCase {

    private var decoder: POCSAGDecoder!

    override func setUp() {
        super.setUp()
        decoder = POCSAGDecoder()
    }

    override func tearDown() {
        decoder = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func charToBitsLSB(_ val: UInt8) -> [Bool] {
        (0..<7).map { (val >> $0) & 1 == 1 }
    }

    // MARK: - Numeric Decoding

    func testDecodeNumericDigits() {
        // BCD: 1=0001, 2=0010, 3=0011
        let bits: [Bool] = [
            false, false, false, true,
            false, false, true, false,
            false, false, true, true,
        ]
        XCTAssertEqual(decoder.decodeNumeric(bits), "123")
    }

    func testDecodeNumericAllDigits() {
        var bits: [Bool] = []
        for d in 0..<10 {
            for b in stride(from: 3, through: 0, by: -1) {
                bits.append((d >> b) & 1 == 1)
            }
        }
        XCTAssertEqual(decoder.decodeNumeric(bits), "0123456789")
    }

    func testDecodeNumericSpecialChars() {
        // 12='-', 13=')', 14='('
        let bits: [Bool] = [
            true, true, false, false,    // 12 = '-'
            true, true, false, true,     // 13 = ')'
            true, true, true, false,     // 14 = '('
        ]
        XCTAssertEqual(decoder.decodeNumeric(bits), "-)(")
    }

    func testDecodeNumericSpacesTrimmed() {
        // 10=space, 1=0001, 10=space
        let bits: [Bool] = [
            true, false, true, false,    // space
            false, false, false, true,   // 1
            true, false, true, false,    // space
        ]
        XCTAssertEqual(decoder.decodeNumeric(bits), "1")
    }

    func testDecodeNumericEmpty() {
        XCTAssertEqual(decoder.decodeNumeric([]), "")
    }

    func testDecodeNumericPartialNibbleIgnored() {
        // 3 bits = not enough for a nibble
        let bits: [Bool] = [true, false, true]
        XCTAssertEqual(decoder.decodeNumeric(bits), "")
    }

    // MARK: - Alpha Decoding

    func testDecodeAlphaHi() {
        // H=72, i=105 in 7-bit LSB-first
        let bits = charToBitsLSB(72) + charToBitsLSB(105)
        XCTAssertEqual(decoder.decodeAlpha(bits), "Hi")
    }

    func testDecodeAlphaSingleChar() {
        let bits = charToBitsLSB(65)  // 'A'
        XCTAssertEqual(decoder.decodeAlpha(bits), "A")
    }

    func testDecodeAlphaFullMessage() {
        let chars: [UInt8] = [70, 73, 82, 69, 32, 68, 69, 80, 84]  // "FIRE DEPT"
        let bits = chars.flatMap { charToBitsLSB($0) }
        XCTAssertEqual(decoder.decodeAlpha(bits), "FIRE DEPT")
    }

    func testDecodeAlphaNewlinesBecomSpaces() {
        // A + LF + B → "A B"
        let bits = charToBitsLSB(65) + charToBitsLSB(10) + charToBitsLSB(66)
        XCTAssertEqual(decoder.decodeAlpha(bits), "A B")
    }

    func testDecodeAlphaCRBecomesSpace() {
        let bits = charToBitsLSB(65) + charToBitsLSB(13) + charToBitsLSB(66)
        XCTAssertEqual(decoder.decodeAlpha(bits), "A B")
    }

    func testDecodeAlphaNonPrintableSkipped() {
        // SOH (1) is < 32 and not LF/CR, so skipped
        let bits = charToBitsLSB(65) + charToBitsLSB(1) + charToBitsLSB(66)
        XCTAssertEqual(decoder.decodeAlpha(bits), "AB")
    }

    func testDecodeAlphaLeadingTrailingSpacesTrimmed() {
        let bits = charToBitsLSB(32) + charToBitsLSB(65) + charToBitsLSB(32)
        XCTAssertEqual(decoder.decodeAlpha(bits), "A")
    }

    func testDecodeAlphaPartialCharIgnored() {
        // 6 bits is not enough for a 7-bit character
        let bits: [Bool] = [true, false, true, false, true, false]
        XCTAssertEqual(decoder.decodeAlpha(bits), "")
    }

    func testDecodeAlphaAllPrintableASCII() {
        for code: UInt8 in 32..<127 {
            let bits = charToBitsLSB(code)
            let result = decoder.decodeAlpha(bits)
            let expected = String(Character(UnicodeScalar(code)))
                .trimmingCharacters(in: .whitespaces)
            XCTAssertEqual(result, expected, "Failed for ASCII \(code)")
        }
    }

    // MARK: - State Management

    func testClearResetsCounters() {
        decoder.clearMessages()
        XCTAssertEqual(decoder.messageCount, 0)
        XCTAssertEqual(decoder.syncCount, 0)
        XCTAssertTrue(decoder.messages.isEmpty)
    }

    func testInactiveDecoderIgnoresData() {
        decoder.isActive = false

        var iqData = [UInt8](repeating: 127, count: 1024)
        for _ in 0..<10 {
            iqData.withUnsafeMutableBufferPointer { buffer in
                decoder.processIQ(buffer.baseAddress!, length: buffer.count)
            }
        }

        let exp = expectation(description: "main thread")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(decoder.syncCount, 0)
        XCTAssertEqual(decoder.messageCount, 0)
    }
}
