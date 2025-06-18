import XCTest
@testable import HactoolSwift

final class PFS0Tests: XCTestCase {

    var testData: Data!

    override func setUpWithError() throws {
        var header = Data("PFS0".utf8)
        header.append(contentsOf: [0x02, 0x00, 0x00, 0x00] as [UInt8]) // fileCount = 2
        header.append(contentsOf: [0x12, 0x00, 0x00, 0x00] as [UInt8]) // stringTableSize = 18
        header.append(contentsOf: [0x00, 0x00, 0x00, 0x00] as [UInt8]) // reserved
        
        var entries = Data()
        // File 1: offset 0, size 12, name_offset 0, reserved 0
        entries.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8])
        entries.append(contentsOf: [0x0C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8])
        entries.append(contentsOf: [0x00, 0x00, 0x00, 0x00] as [UInt8])
        entries.append(contentsOf: [0x00, 0x00, 0x00, 0x00] as [UInt8])
        
        // File 2: offset 12, size 5, name_offset 10, reserved 0
        entries.append(contentsOf: [0x0C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8])
        entries.append(contentsOf: [0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8])
        entries.append(contentsOf: [0x0A, 0x00, 0x00, 0x00] as [UInt8])
        entries.append(contentsOf: [0x00, 0x00, 0x00, 0x00] as [UInt8])

        var stringTable = "file1.txt\0file2.bin\0".data(using: .utf8)!
        stringTable.append(Data(repeating: 0, count: 2)) // Padding to 18 bytes

        let data1 = "Hello World!".data(using: .utf8)!
        let data2 = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xFE])

        self.testData = header + entries + stringTable + data1 + data2
    }

    func testPFS0Parsing() throws {
        let partition = try PFS0Parser.parse(data: testData)

        XCTAssertEqual(partition.header.fileCount, 2)
        XCTAssertEqual(partition.files.count, 2)

        let file1 = partition.files[0]
        XCTAssertEqual(file1.name, "file1.txt")
        XCTAssertEqual(file1.size, 12)
        XCTAssertEqual(String(data: file1.data, encoding: .utf8), "Hello World!")

        let file2 = partition.files[1]
        XCTAssertEqual(file2.name, "file2.bin")
        XCTAssertEqual(file2.size, 5)
        XCTAssertEqual(file2.data.hexEncodedString(), "deadbeeffe")
    }
    
    func testInvalidMagic() {
        var badData = testData!
        badData.replaceSubrange(0..<4, with: "BAD0".utf8)
        
        XCTAssertThrowsError(try PFS0Parser.parse(data: badData)) { error in
            guard let parserError = error as? ParserError else {
                XCTFail("Unexpected error type")
                return
            }
            if case .invalidMagic(let expected, let found) = parserError {
                XCTAssertEqual(expected, "PFS0")
                XCTAssertEqual(found, "BAD0")
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
}
